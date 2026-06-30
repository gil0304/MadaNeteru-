//
//  AlarmRule.swift
//  MadaNeteru?
//
//  要件 7・8・14章。アラームの「ルール」。3 階層（全体 / 曜日 / 予定）を
//  targetType + targetId で表現する。実際に鳴る 1 件は ScheduledAlarm。
//

import Foundation
import SwiftData

@Model
final class AlarmRule {
    @Attribute(.unique) var id: String
    var userId: String

    /// global / weekday / event
    var targetTypeRaw: String
    /// weekday の場合は Weekday.rawValue("1"〜"7")、event の場合は CalendarEvent.id、global は nil
    var targetId: String?

    var alarmTypeRaw: String
    var alarmTimeTypeRaw: String

    /// 絶対時刻指定（alarmTimeType == .absolute）
    var alarmHour: Int?
    var alarmMinute: Int?

    /// 相対指定（alarmTimeType == .relativeToEvent）: 予定開始の何分前か
    var relativeMinutes: Int?

    /// 曜日繰り返し（weekday ルールや「平日だけ」等）。Weekday.rawValue の配列。
    var repeatWeekdays: [Int]

    var soundName: String
    var snoozeEnabled: Bool
    var snoozeIntervalMinutes: Int
    var isEnabled: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        targetType: AlarmTargetType,
        targetId: String? = nil,
        alarmType: AlarmType,
        alarmTimeType: AlarmTimeType,
        alarmHour: Int? = nil,
        alarmMinute: Int? = nil,
        relativeMinutes: Int? = nil,
        repeatWeekdays: [Int] = [],
        soundName: String = "default",
        snoozeEnabled: Bool = true,
        snoozeIntervalMinutes: Int = 9,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.targetTypeRaw = targetType.rawValue
        self.targetId = targetId
        self.alarmTypeRaw = alarmType.rawValue
        self.alarmTimeTypeRaw = alarmTimeType.rawValue
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.relativeMinutes = relativeMinutes
        self.repeatWeekdays = repeatWeekdays
        self.soundName = soundName
        self.snoozeEnabled = snoozeEnabled
        self.snoozeIntervalMinutes = snoozeIntervalMinutes
        self.isEnabled = isEnabled
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - 型付きアクセサ

    var targetType: AlarmTargetType {
        get { AlarmTargetType(rawValue: targetTypeRaw) ?? .global }
        set { targetTypeRaw = newValue.rawValue }
    }

    var alarmType: AlarmType {
        get { AlarmType(rawValue: alarmTypeRaw) ?? .wakeUp }
        set { alarmTypeRaw = newValue.rawValue }
    }

    var alarmTimeType: AlarmTimeType {
        get { AlarmTimeType(rawValue: alarmTimeTypeRaw) ?? .absolute }
        set { alarmTimeTypeRaw = newValue.rawValue }
    }

    var weekday: Weekday? {
        guard targetType == .weekday, let targetId, let raw = Int(targetId) else { return nil }
        return Weekday(rawValue: raw)
    }

    /// 表示用の時刻文字列。
    var timeDescription: String {
        switch alarmTimeType {
        case .absolute:
            let h = alarmHour ?? 0, m = alarmMinute ?? 0
            return String(format: "%02d:%02d", h, m)
        case .relativeToEvent:
            let mins = relativeMinutes ?? 0
            if mins % 60 == 0 { return "開始\(mins / 60)時間前" }
            return "開始\(mins)分前"
        }
    }
}
