//
//  MockCalendarProvider.swift
//  MadaNeteru?
//
//  認証情報なしでアプリ全体（予定→ルール→アラーム→履歴）を動かすための
//  サンプル実装。実 Google 連携は GoogleCalendarProvider に差し替える。
//  要件の例（「明日 10:00 面接」など）を再現する。
//

import Foundation

final class MockCalendarProvider: CalendarSyncService, @unchecked Sendable {
    private let lock = NSLock()
    private var account: GoogleAccount?

    var currentAccount: GoogleAccount? {
        get async { lock.withLock { account } }
    }

    @discardableResult
    func signIn() async throws -> GoogleAccount {
        // 実際の OAuth 同意画面の代わりに、サンプルアカウントでログイン状態にする。
        try await Task.sleep(for: .milliseconds(400))
        let acc = GoogleAccount(
            id: "mock-google-uid-001",
            email: "you@example.com",
            name: "サンプルユーザー"
        )
        lock.withLock { account = acc }
        return acc
    }

    func signOut() async {
        lock.withLock { account = nil }
    }

    func calendars() async throws -> [RemoteCalendar] {
        guard await currentAccount != nil else { throw CalendarSyncError.notSignedIn }
        return [
            RemoteCalendar(id: "primary", title: "予定", isPrimary: true),
            RemoteCalendar(id: "work", title: "仕事", isPrimary: false)
        ]
    }

    func fetchEvents(
        calendarId: String,
        syncToken: String?,
        timeMin: Date,
        timeMax: Date
    ) async throws -> EventSyncResult {
        guard await currentAccount != nil else { throw CalendarSyncError.notSignedIn }
        try await Task.sleep(for: .milliseconds(300))

        let all = Self.sampleEvents(calendarId: calendarId)
        let filtered = all.filter { $0.start >= timeMin && $0.start < timeMax }
        return EventSyncResult(
            events: filtered,
            deletedEventIds: [],
            nextSyncToken: "mock-sync-token-\(Int(Date.now.timeIntervalSince1970))"
        )
    }

    // MARK: - サンプル生成

    private static func sampleEvents(calendarId: String) -> [RemoteEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }
        func at(_ dayOffset: Int, _ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: day(dayOffset))!
        }

        guard calendarId == "primary" else {
            // 「仕事」カレンダーには明後日の打ち合わせだけ。
            return [
                RemoteEvent(id: "work-1", calendarId: "work", title: "定例ミーティング",
                            description: "週次の進捗共有", location: "オンライン",
                            start: at(2, 11, 0), end: at(2, 12, 0),
                            isAllDay: false, recurrenceRule: "FREQ=WEEKLY;BYDAY=MO", status: "confirmed")
            ]
        }

        return [
            // 今日
            RemoteEvent(id: "today-1", calendarId: "primary", title: "歯医者",
                        description: nil, location: "渋谷デンタルクリニック",
                        start: at(0, 18, 30), end: at(0, 19, 0),
                        isAllDay: false, recurrenceRule: nil, status: "confirmed"),

            // 明日（要件の例: 10:00 面接）
            RemoteEvent(id: "tomorrow-interview", calendarId: "primary", title: "面接",
                        description: "履歴書・筆記用具を持参", location: "品川オフィス 12F",
                        start: at(1, 10, 0), end: at(1, 11, 30),
                        isAllDay: false, recurrenceRule: nil, status: "confirmed"),
            RemoteEvent(id: "tomorrow-lunch", calendarId: "primary", title: "ランチ（友人）",
                        description: nil, location: "表参道",
                        start: at(1, 13, 0), end: at(1, 14, 30),
                        isAllDay: false, recurrenceRule: nil, status: "confirmed"),
            RemoteEvent(id: "tomorrow-online", calendarId: "primary", title: "オンライン勉強会",
                        description: "Zoom", location: "オンライン",
                        start: at(1, 20, 0), end: at(1, 21, 30),
                        isAllDay: false, recurrenceRule: nil, status: "confirmed"),
            RemoteEvent(id: "tomorrow-allday", calendarId: "primary", title: "資源ごみの日",
                        description: nil, location: nil,
                        start: day(1), end: day(2),
                        isAllDay: true, recurrenceRule: nil, status: "confirmed"),

            // 今後 7 日
            RemoteEvent(id: "d2-gym", calendarId: "primary", title: "ジム",
                        description: nil, location: "近所のジム",
                        start: at(2, 7, 0), end: at(2, 8, 0),
                        isAllDay: false, recurrenceRule: "FREQ=WEEKLY", status: "confirmed"),
            RemoteEvent(id: "d3-trip", calendarId: "primary", title: "日帰り出張",
                        description: "新幹線 8:12 発", location: "名古屋",
                        start: at(3, 8, 0), end: at(3, 19, 0),
                        isAllDay: false, recurrenceRule: nil, status: "confirmed"),
            RemoteEvent(id: "d5-movie", calendarId: "primary", title: "映画",
                        description: nil, location: "新宿",
                        start: at(5, 19, 30), end: at(5, 22, 0),
                        isAllDay: false, recurrenceRule: nil, status: "confirmed")
        ]
    }
}
