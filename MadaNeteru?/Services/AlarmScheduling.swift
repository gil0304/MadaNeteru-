//
//  AlarmScheduling.swift
//  MadaNeteru?
//
//  アラーム発火層の抽象化。要件 9・12章。
//  - 実機/実SDK: AlarmKitScheduler（AlarmManager を使用）
//  - 通常通知:    NotificationScheduler（UNUserNotificationCenter）
//  - 開発/Preview/未認可フォールバック: MockAlarmScheduler
//
//  上位（AlarmPlanner / AppModel）は PlannedAlarm を渡すだけで、どの経路で
//  鳴らすかを意識しなくてよい。
//

import Foundation

// MARK: - アラーム記述子

/// ルール解決後の「これを鳴らす」という具体的な指示。
struct PlannedAlarm: Identifiable, Sendable, Equatable {
    enum When: Sendable, Equatable {
        /// 特定日時に 1 回（明日の起床、前日夜の充電確認など）。
        case fixed(Date)
        /// 毎週この曜日のこの時刻（曜日デフォルトの繰り返し）。
        case weekly(hour: Int, minute: Int, weekdays: [Weekday])
    }

    var id: UUID
    var alarmType: AlarmType
    var title: String          // アラート見出し
    var body: String           // 補足文（通知本文 / 履歴用）
    var when: When
    var snoozeEnabled: Bool
    var snoozeIntervalMinutes: Int
    var tintHex: String        // Live Activity の tintColor 用
    /// 停止ボタンの文言（充電確認なら「充電した」等）。
    var stopButtonText: String
    /// AlarmKit（強い鳴動）を使うか、通常通知で済ませるか。要件 12章。
    var useAlarmKit: Bool

    // 永続化（ScheduledAlarm）用の出自情報
    var eventId: String? = nil
    var ruleId: String? = nil
    var eventTitle: String? = nil

    /// fixed の発火時刻（weekly は nil）。
    var fireDate: Date? {
        if case .fixed(let d) = when { return d }
        return nil
    }
}

// MARK: - スケジューラ抽象

protocol AlarmScheduling: AnyObject, Sendable {
    var authorizationState: AuthStatus { get async }
    @discardableResult
    func requestAuthorization() async -> AuthStatus
    /// 失敗時は throw（要件 17.1: 呼び出し側が警告表示する）。
    func schedule(_ alarm: PlannedAlarm) async throws
    func cancel(id: UUID) async
    func stop(id: UUID) async
    /// 現在この層が把握している有効アラーム ID。
    func activeAlarmIDs() async -> Set<UUID>
}

// MARK: - モック（シミュレータ / Preview / 未認可フォールバック）

/// 実 SDK が使えない場面でも、アプリの全フロー（予定→ルール→スケジュール→
/// 履歴）を破綻なく動かすためのインメモリ実装。
final class MockAlarmScheduler: AlarmScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var scheduled: [UUID: PlannedAlarm] = [:]
    private var _auth: AuthStatus = .authorized

    init(authorized: Bool = true) {
        _auth = authorized ? .authorized : .notDetermined
    }

    var authorizationState: AuthStatus {
        get async { lock.withLock { _auth } }
    }

    func requestAuthorization() async -> AuthStatus {
        lock.withLock { _auth = .authorized }
        return .authorized
    }

    func schedule(_ alarm: PlannedAlarm) async throws {
        lock.withLock { scheduled[alarm.id] = alarm }
        #if DEBUG
        print("🔔 [Mock] schedule \(alarm.alarmType.rawValue) '\(alarm.title)' at \(alarm.fireDate.map(AppDate.dateTimeString) ?? "weekly")")
        #endif
    }

    func cancel(id: UUID) async {
        lock.withLock { _ = scheduled.removeValue(forKey: id) }
    }

    func stop(id: UUID) async {
        lock.withLock { _ = scheduled.removeValue(forKey: id) }
    }

    func activeAlarmIDs() async -> Set<UUID> {
        lock.withLock { Set(scheduled.keys) }
    }
}
