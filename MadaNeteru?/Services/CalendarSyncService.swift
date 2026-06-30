//
//  CalendarSyncService.swift
//  MadaNeteru?
//
//  要件 6章。Google ログイン + カレンダー同期の抽象。
//  実装は 2 つ:
//   - MockCalendarProvider     … 認証情報なしで全フローを動かすサンプル
//   - GoogleCalendarProvider   … 実 Google Sign-In + Calendar API（差し込み口）
//
//  上位はこのプロトコルだけに依存するので、実 Google 実装に差し替えても
//  画面・ロジックは変更不要。
//

import Foundation

// MARK: - DTO（SwiftData モデルとは別の、取得用の値型）

struct GoogleAccount: Sendable, Equatable, Codable {
    var id: String
    var email: String
    var name: String
}

struct RemoteCalendar: Sendable, Equatable, Identifiable {
    var id: String          // googleCalendarId
    var title: String
    var isPrimary: Bool
}

struct RemoteEvent: Sendable, Equatable, Identifiable {
    var id: String          // googleEventId
    var calendarId: String
    var title: String
    var description: String?
    var location: String?
    var start: Date
    var end: Date
    var isAllDay: Bool
    var recurrenceRule: String?
    var status: String
}

struct EventSyncResult: Sendable {
    var events: [RemoteEvent]
    /// 削除されたイベントの googleEventId（差分同期で status=cancelled の分）。
    var deletedEventIds: [String]
    /// 次回の差分同期に使う syncToken（要件 6.4）。
    var nextSyncToken: String?
}

enum CalendarSyncError: LocalizedError {
    case notSignedIn
    case notImplemented(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Google アカウントにログインしていません。"
        case .notImplemented(let what): return "未実装: \(what)"
        case .network(let msg): return "通信エラー: \(msg)"
        }
    }
}

// MARK: - 抽象

protocol CalendarSyncService: AnyObject, Sendable {
    var currentAccount: GoogleAccount? { get async }

    /// Google ログイン（OAuth）。成功でアカウントを返す。
    @discardableResult
    func signIn() async throws -> GoogleAccount
    func signOut() async

    /// ユーザーのカレンダー一覧。
    func calendars() async throws -> [RemoteCalendar]

    /// 期間内のイベントを取得。syncToken があれば差分のみ（要件 6.4）。
    func fetchEvents(
        calendarId: String,
        syncToken: String?,
        timeMin: Date,
        timeMax: Date
    ) async throws -> EventSyncResult
}
