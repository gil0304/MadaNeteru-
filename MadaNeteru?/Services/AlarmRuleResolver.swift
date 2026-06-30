//
//  AlarmRuleResolver.swift
//  MadaNeteru?
//
//  要件 8章（優先順位）・10章（未設定チェック）の中核ロジック。純粋関数群。
//
//  3 階層を 1 か所で解決する:
//    予定ごと(event, SwiftData) > 曜日ごと(weekday, SwiftData) > 全体(global, 設定値)
//  全体デフォルトは AlarmRule 行ではなく GlobalDefaults（SettingsStore 由来）で渡す。
//  予定/曜日ティアに「無効化ルール(isEnabled=false)」があれば、その種別は下位を
//  上書きして "鳴らさない"（＝この予定だけ不要、要件 13.4）。
//

import Foundation

struct TimeOfDay: Equatable, Sendable {
    var hour: Int
    var minute: Int
}

/// 全体デフォルト（要件 7.1 / 13.6）。nil は「その種別は無効」。
struct GlobalDefaults: Sendable {
    var wake: TimeOfDay?
    var previousDayCheck: TimeOfDay?
    var charge: TimeOfDay?
    var departure: TimeOfDay?        // 既定では nil（出発はデフォルト無効）
    var reminderMinutesBefore: Int?  // 予定リマインド（相対）
    var snoozeIntervalMinutes: Int
    var snoozeEnabled: Bool
    var chargeEnabled: Bool
}

/// ルール適用の結果、具体的な日時まで決まった 1 件。
struct EffectiveAlarm: Identifiable, Equatable {
    var id: String { "\(ruleId)|\(eventId ?? "none")|\(Int(fireDate.timeIntervalSince1970))" }
    var ruleId: String
    var eventId: String?
    var eventTitle: String?
    var alarmType: AlarmType
    var fireDate: Date
    var snoozeEnabled: Bool
    var snoozeIntervalMinutes: Int
    var useAlarmKit: Bool
}

enum AlarmRuleResolver {

    /// 種別ごとのティア解決結果。
    enum TierResolution {
        case suppressed          // 予定/曜日で明示的に無効化 → 鳴らさない
        case rules([AlarmRule])  // このティアの有効ルールが勝つ
        case fallThrough         // 下位（最終的に global）に委ねる
    }

    private static let typesToPlan: [AlarmType] =
        [.wakeUp, .previousDayCheck, .chargeCheck, .departure, .eventReminder]

    // MARK: - 単一予定の有効アラーム

    static func effectiveAlarms(
        for event: CalendarEvent,
        rules: [AlarmRule],
        globals: GlobalDefaults,
        now: Date = .now
    ) -> [EffectiveAlarm] {
        guard event.isAlarmEligible else { return [] }
        let weekday = event.startWeekday

        var results: [EffectiveAlarm] = []
        for type in typesToPlan {
            switch resolveTier(for: type, event: event, weekday: weekday, rules: rules) {
            case .suppressed:
                continue
            case .rules(let rs):
                for rule in rs {
                    guard let fire = fireDate(for: rule, event: event) else { continue }
                    results.append(EffectiveAlarm(
                        ruleId: rule.id,
                        eventId: event.id,
                        eventTitle: event.title,
                        alarmType: type,
                        fireDate: fire,
                        snoozeEnabled: rule.snoozeEnabled,
                        snoozeIntervalMinutes: rule.snoozeIntervalMinutes,
                        useAlarmKit: type.prefersAlarmKit
                    ))
                }
            case .fallThrough:
                if let ga = globalAlarm(type: type, event: event, globals: globals) {
                    results.append(ga)
                }
            }
        }
        return results.filter { $0.fireDate > now }
    }

    /// event → weekday の順にティアを判定（global は呼び出し側で fallThrough を処理）。
    static func resolveTier(
        for type: AlarmType,
        event: CalendarEvent,
        weekday: Weekday,
        rules: [AlarmRule]
    ) -> TierResolution {
        let ofType = rules.filter { $0.alarmType == type }

        let eventTier = ofType.filter { $0.targetType == .event && $0.targetId == event.id }
        if eventTier.contains(where: { !$0.isEnabled }) { return .suppressed }
        let enabledEvent = eventTier.filter { $0.isEnabled }
        if !enabledEvent.isEmpty { return .rules(enabledEvent) }

        let weekdayTier = ofType.filter {
            $0.targetType == .weekday && $0.targetId == String(weekday.rawValue)
        }
        if weekdayTier.contains(where: { !$0.isEnabled }) { return .suppressed }
        let enabledWeekday = weekdayTier.filter { $0.isEnabled }
        if !enabledWeekday.isEmpty { return .rules(enabledWeekday) }

        return .fallThrough
    }

    // MARK: - 発火日時

    static func fireDate(for rule: AlarmRule, event: CalendarEvent) -> Date? {
        switch rule.alarmTimeType {
        case .absolute:
            guard let h = rule.alarmHour, let m = rule.alarmMinute else { return nil }
            return absoluteFire(type: rule.alarmType, hour: h, minute: m, event: event)
        case .relativeToEvent:
            guard let mins = rule.relativeMinutes else { return nil }
            return event.startDateTime.addingTimeInterval(TimeInterval(-mins * 60))
        }
    }

    /// 種別に応じて「当日」か「前日」かを決めて絶対時刻を作る。
    private static func absoluteFire(type: AlarmType, hour: Int, minute: Int, event: CalendarEvent) -> Date {
        switch type {
        case .chargeCheck, .previousDayCheck:
            return AppDate.previousDay(at: hour, minute: minute, of: event.startDateTime)
        default:
            return AppDate.at(hour: hour, minute: minute, on: AppDate.startOfDay(event.startDateTime))
        }
    }

    private static func globalAlarm(type: AlarmType, event: CalendarEvent, globals: GlobalDefaults) -> EffectiveAlarm? {
        func make(_ fire: Date) -> EffectiveAlarm {
            EffectiveAlarm(
                ruleId: "global-\(type.rawValue)",
                eventId: event.id,
                eventTitle: event.title,
                alarmType: type,
                fireDate: fire,
                snoozeEnabled: globals.snoozeEnabled,
                snoozeIntervalMinutes: globals.snoozeIntervalMinutes,
                useAlarmKit: type.prefersAlarmKit
            )
        }

        switch type {
        case .wakeUp:
            guard let t = globals.wake else { return nil }
            return make(absoluteFire(type: .wakeUp, hour: t.hour, minute: t.minute, event: event))
        case .previousDayCheck:
            guard let t = globals.previousDayCheck else { return nil }
            return make(absoluteFire(type: .previousDayCheck, hour: t.hour, minute: t.minute, event: event))
        case .chargeCheck:
            guard globals.chargeEnabled, let t = globals.charge else { return nil }
            return make(absoluteFire(type: .chargeCheck, hour: t.hour, minute: t.minute, event: event))
        case .departure:
            guard let t = globals.departure else { return nil }
            return make(absoluteFire(type: .departure, hour: t.hour, minute: t.minute, event: event))
        case .eventReminder:
            guard let m = globals.reminderMinutesBefore else { return nil }
            return make(event.startDateTime.addingTimeInterval(TimeInterval(-m * 60)))
        case .missingAlarmWarning:
            return nil
        }
    }

    // MARK: - 未設定チェック（要件 10）

    /// 「起床アラーム未設定」か。明示オプトアウトや global 既定があれば未設定ではない。
    static func isMissingWakeAlarm(
        event: CalendarEvent,
        rules: [AlarmRule],
        globals: GlobalDefaults
    ) -> Bool {
        guard event.isAlarmEligible else { return false }
        switch resolveTier(for: .wakeUp, event: event, weekday: event.startWeekday, rules: rules) {
        case .suppressed: return false      // 意図的に不要 → 警告しない
        case .rules:      return false      // カバー済み
        case .fallThrough: return globals.wake == nil  // 全体既定も無ければ未設定
        }
    }

    static func missingAlarmEvents(
        on day: Date,
        events: [CalendarEvent],
        rules: [AlarmRule],
        globals: GlobalDefaults
    ) -> [CalendarEvent] {
        events
            .filter { AppDate.isSameDay($0.startDateTime, day) && $0.isAlarmEligible }
            .filter { isMissingWakeAlarm(event: $0, rules: rules, globals: globals) }
            .sorted { $0.startDateTime < $1.startDateTime }
    }
}
