//
//  GoogleCalendarProvider.swift
//  MadaNeteru?
//
//  実 Google 連携（要件 6・17.3）。GoogleAuthService（OAuth2/PKCE）でトークンを得て、
//  Google Calendar REST を URLSession + Codable で叩く。
//   - calendarList.list … カレンダー一覧
//   - events.list       … 初回は timeMin/Max、2回目以降は syncToken で差分（要件 6.4）
//   - 410 GONE          … syncToken 失効 → full sync でやり直す
//

import Foundation

final class GoogleCalendarProvider: CalendarSyncService, @unchecked Sendable {
    private let auth: GoogleAuthService

    init(auth: GoogleAuthService) {
        self.auth = auth
    }

    var currentAccount: GoogleAccount? {
        get async { auth.account }
    }

    @discardableResult
    func signIn() async throws -> GoogleAccount {
        try await auth.signIn()
    }

    func signOut() async {
        auth.signOut()
    }

    // MARK: calendarList

    func calendars() async throws -> [RemoteCalendar] {
        let token = try await auth.validAccessToken()
        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        let (data, response) = try await get(url, token: token)
        try ensureOK(response, data: data)
        let decoded = try JSONDecoder().decode(GCalListResponse.self, from: data)
        // ログインしたアカウントが「所有する」カレンダーのみ（primary + 自作）。
        // 祝日・他人共有・購読カレンダー（accessRole != owner）は除外する。
        return decoded.items
            .filter { ($0.accessRole == "owner") || ($0.primary == true) }
            .map { RemoteCalendar(id: $0.id, title: $0.summary ?? $0.id, isPrimary: $0.primary ?? false) }
    }

    // MARK: events.list

    func fetchEvents(
        calendarId: String,
        syncToken: String?,
        timeMin: Date,
        timeMax: Date
    ) async throws -> EventSyncResult {
        let token = try await auth.validAccessToken()

        var events: [RemoteEvent] = []
        var deleted: [String] = []
        var nextSync: String?
        var pageToken: String?

        repeat {
            var comps = URLComponents(
                string: "https://www.googleapis.com/calendar/v3/calendars/\(percentPath(calendarId))/events"
            )!
            var items: [URLQueryItem] = [.init(name: "singleEvents", value: "true"),
                                         .init(name: "maxResults", value: "2500")]
            if let syncToken {
                items.append(.init(name: "syncToken", value: syncToken))
            } else {
                let iso = ISO8601DateFormatter()
                items.append(.init(name: "timeMin", value: iso.string(from: timeMin)))
                items.append(.init(name: "timeMax", value: iso.string(from: timeMax)))
                items.append(.init(name: "orderBy", value: "startTime"))
                items.append(.init(name: "showDeleted", value: "true"))
            }
            if let pageToken { items.append(.init(name: "pageToken", value: pageToken)) }
            comps.queryItems = items

            let (data, response) = try await get(comps.url!, token: token)

            // syncToken 失効 → full sync でやり直す（要件 17.1 相当の自己回復）。
            if let http = response as? HTTPURLResponse, http.statusCode == 410, syncToken != nil {
                return try await fetchEvents(calendarId: calendarId, syncToken: nil,
                                             timeMin: timeMin, timeMax: timeMax)
            }
            try ensureOK(response, data: data)

            let decoded = try JSONDecoder().decode(GEventsResponse.self, from: data)
            for item in decoded.items {
                if item.status == "cancelled" {
                    deleted.append(item.id)
                } else if let event = Self.mapEvent(item, calendarId: calendarId) {
                    events.append(event)
                }
            }
            pageToken = decoded.nextPageToken
            nextSync = decoded.nextSyncToken ?? nextSync
        } while pageToken != nil

        return EventSyncResult(events: events, deletedEventIds: deleted, nextSyncToken: nextSync)
    }

    // MARK: HTTP

    private func get(_ url: URL, token: String) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await URLSession.shared.data(for: request)
    }

    private func ensureOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CalendarSyncError.network("不正なレスポンス")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CalendarSyncError.network("HTTP \(http.statusCode)")
        }
    }

    private func percentPath(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    // MARK: マッピング

    private static func mapEvent(_ g: GEvent, calendarId: String) -> RemoteEvent? {
        guard let start = g.start, let end = g.end else { return nil }
        let isAllDay = start.date != nil
        guard let startDate = start.resolvedStart, let endDate = end.resolvedEnd else { return nil }
        return RemoteEvent(
            id: g.id,
            calendarId: calendarId,
            title: g.summary ?? "(無題)",
            description: g.description,
            location: g.location,
            start: startDate,
            end: endDate,
            isAllDay: isAllDay,
            recurrenceRule: g.recurrence?.first,
            status: g.status ?? "confirmed"
        )
    }
}

// MARK: - Google JSON モデル

private struct GCalListResponse: Decodable { let items: [GCalEntry] }
private struct GCalEntry: Decodable {
    let id: String
    let summary: String?
    let primary: Bool?
    let accessRole: String?   // owner / writer / reader / freeBusyReader
}

private struct GEventsResponse: Decodable {
    let items: [GEvent]
    let nextPageToken: String?
    let nextSyncToken: String?
}

private struct GEvent: Decodable {
    let id: String
    let status: String?
    let summary: String?
    let description: String?
    let location: String?
    let start: GDateTime?
    let end: GDateTime?
    let recurrence: [String]?
}

private struct GDateTime: Decodable {
    let date: String?       // 終日: "yyyy-MM-dd"
    let dateTime: String?   // 時刻あり: RFC3339

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parsedDateTime() -> Date? {
        guard let dateTime else { return nil }
        return Self.isoFractional.date(from: dateTime) ?? Self.iso.date(from: dateTime)
    }
    private func parsedDay() -> Date? {
        guard let date else { return nil }
        return Self.dayFormatter.date(from: date)
    }

    var resolvedStart: Date? { parsedDateTime() ?? parsedDay() }
    /// 終日予定の end.date は排他的（翌日 0:00）。そのまま終了として扱う。
    var resolvedEnd: Date? { parsedDateTime() ?? parsedDay() }
}
