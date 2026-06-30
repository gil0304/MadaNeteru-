//
//  Enums.swift
//  MadaNeteru?
//
//  ドメイン全体で使う列挙型。SwiftData に保存できるよう String / Int の
//  RawRepresentable + Codable に統一している。
//

import Foundation

// MARK: - アラームルールの適用対象

/// アラームルールが「何に」紐づくか。優先順位は event > weekday > global。
enum AlarmTargetType: String, Codable, CaseIterable, Sendable {
    case global    // 全体デフォルト
    case weekday   // 曜日ごと
    case event     // 予定ごと（個別）

    /// 優先順位（数字が大きいほど優先）。要件 8章。
    var priority: Int {
        switch self {
        case .event:   return 3
        case .weekday: return 2
        case .global:  return 1
        }
    }
}

// MARK: - アラーム種別

/// 要件 9.2 / 14章 alarmType。
enum AlarmType: String, Codable, CaseIterable, Sendable {
    case wakeUp              = "wake_up"               // 起床アラーム
    case previousDayCheck    = "previous_day_check"    // 前日確認
    case chargeCheck         = "charge_check"          // 充電確認
    case departure           = "departure"             // 出発
    case eventReminder       = "event_reminder"        // 予定リマインド
    case missingAlarmWarning = "missing_alarm_warning" // アラーム未設定警告

    var title: String {
        switch self {
        case .wakeUp:              return "起床アラーム"
        case .previousDayCheck:    return "前日確認"
        case .chargeCheck:         return "充電確認"
        case .departure:           return "出発アラーム"
        case .eventReminder:       return "予定リマインド"
        case .missingAlarmWarning: return "アラーム未設定警告"
        }
    }

    var symbolName: String {
        switch self {
        case .wakeUp:              return "alarm.fill"
        case .previousDayCheck:    return "checklist"
        case .chargeCheck:         return "battery.100.bolt"
        case .departure:           return "figure.walk.departure"
        case .eventReminder:       return "bell.fill"
        case .missingAlarmWarning: return "exclamationmark.triangle.fill"
        }
    }

    /// 要件 12章: AlarmKit（強い鳴動）で鳴らすべき種別か。
    var prefersAlarmKit: Bool {
        switch self {
        case .wakeUp, .chargeCheck, .missingAlarmWarning, .departure:
            return true
        case .previousDayCheck, .eventReminder:
            return false
        }
    }
}

// MARK: - アラーム時刻の指定方法

/// 絶対時刻（7:00）か、予定からの相対（開始15分前）か。要件 14章 alarmTimeType。
enum AlarmTimeType: String, Codable, CaseIterable, Sendable {
    case absolute        // alarmTime（時:分）を使う
    case relativeToEvent // relativeMinutes（開始の何分前）を使う
}

// MARK: - スケジュール済みアラームの状態

/// 要件 14章 ScheduledAlarm.status。
enum ScheduledAlarmStatus: String, Codable, CaseIterable, Sendable {
    case scheduled
    case fired
    case dismissed
    case snoozed
    case cancelled
    case failed

    var label: String {
        switch self {
        case .scheduled: return "予定"
        case .fired:     return "鳴動"
        case .dismissed: return "停止"
        case .snoozed:   return "スヌーズ"
        case .cancelled: return "キャンセル"
        case .failed:    return "失敗"
        }
    }
}

// MARK: - バッテリー状態

/// 要件 11.3。`unknown` / 未確認 は安全側に倒して鳴らす。
enum BatteryStateKind: String, Codable, CaseIterable, Sendable {
    case charging    // 充電中 → 鳴らさない
    case full        // 満充電 → 鳴らさない
    case unplugged   // 未充電 → 鳴らす
    case unknown     // 判定不可 → 鳴らす
    case notChecked  = "not_checked" // 未確認 → 鳴らす

    /// 「充電済みと確認できた」場合だけ true（＝アラーム不要）。
    var isConfirmedCharged: Bool {
        self == .charging || self == .full
    }

    var label: String {
        switch self {
        case .charging:   return "充電中"
        case .full:       return "満充電"
        case .unplugged:  return "未充電"
        case .unknown:    return "判定不可"
        case .notChecked: return "未確認"
        }
    }
}

// MARK: - 充電確認アラームに対するユーザー操作

/// 要件 11.4 のボタン。
enum ChargeUserAction: String, Codable, CaseIterable, Sendable {
    case charged       // 充電した
    case snoozed       // 15分後に再通知
    case notNeeded     = "not_needed"     // 今日は不要
    case viewedSettings = "viewed_settings" // アラーム設定を見る
    case none

    var label: String {
        switch self {
        case .charged:        return "充電した"
        case .snoozed:        return "15分後に再通知"
        case .notNeeded:      return "今日は不要"
        case .viewedSettings: return "設定を確認"
        case .none:           return "—"
        }
    }
}

// MARK: - 曜日

/// Calendar.component(.weekday) と同じ採番（日曜=1 … 土曜=7）。
enum Weekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    /// 表示順を月曜始まりにしたい時に使う。
    static var mondayFirst: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    var shortLabel: String {
        switch self {
        case .sunday:    return "日"
        case .monday:    return "月"
        case .tuesday:   return "火"
        case .wednesday: return "水"
        case .thursday:  return "木"
        case .friday:    return "金"
        case .saturday:  return "土"
        }
    }

    var longLabel: String { shortLabel + "曜日" }

    /// AlarmKit の週次繰り返しに渡す `Locale.Weekday`。
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday:    return .sunday
        case .monday:    return .monday
        case .tuesday:   return .tuesday
        case .wednesday: return .wednesday
        case .thursday:  return .thursday
        case .friday:    return .friday
        case .saturday:  return .saturday
        }
    }

    /// 指定日の曜日を返す。
    static func of(_ date: Date, calendar: Calendar = .current) -> Weekday {
        let value = calendar.component(.weekday, from: date)
        return Weekday(rawValue: value) ?? .sunday
    }
}
