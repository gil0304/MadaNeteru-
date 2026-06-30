//
//  ScheduledAlarm.swift
//  MadaNeteru?
//
//  要件 14章。ルールから具体的な日時へ展開された「実際に鳴る 1 件」。
//  AlarmKit にスケジュールした alarm の UUID を alarmKitAlarmId に保持する。
//  履歴画面（13.7）の表示元にもなるため、種別やタイトルを非正規化して持つ。
//

import Foundation
import SwiftData

@Model
final class ScheduledAlarm {
    @Attribute(.unique) var id: String
    var userId: String

    var eventId: String?
    var alarmRuleId: String?
    /// AlarmKit / 通知側の識別子（UUID）。停止・キャンセル時に使う。
    var alarmKitAlarmId: String?

    /// 履歴表示用の非正規化フィールド
    var alarmTypeRaw: String
    var title: String
    var eventTitle: String?

    var scheduledAt: Date
    var statusRaw: String

    var firedAt: Date?
    var dismissedAt: Date?
    var snoozedAt: Date?
    var snoozeCount: Int
    var chargeConfirmed: Bool

    /// AlarmKit ではなく通常通知で鳴らしたものか（要件 12章の使い分け記録）。
    var usedAlarmKit: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        eventId: String? = nil,
        alarmRuleId: String? = nil,
        alarmKitAlarmId: String? = nil,
        alarmType: AlarmType,
        title: String,
        eventTitle: String? = nil,
        scheduledAt: Date,
        status: ScheduledAlarmStatus = .scheduled,
        usedAlarmKit: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.eventId = eventId
        self.alarmRuleId = alarmRuleId
        self.alarmKitAlarmId = alarmKitAlarmId
        self.alarmTypeRaw = alarmType.rawValue
        self.title = title
        self.eventTitle = eventTitle
        self.scheduledAt = scheduledAt
        self.statusRaw = status.rawValue
        self.firedAt = nil
        self.dismissedAt = nil
        self.snoozedAt = nil
        self.snoozeCount = 0
        self.chargeConfirmed = false
        self.usedAlarmKit = usedAlarmKit
        self.createdAt = .now
        self.updatedAt = .now
    }

    var alarmType: AlarmType {
        get { AlarmType(rawValue: alarmTypeRaw) ?? .wakeUp }
        set { alarmTypeRaw = newValue.rawValue }
    }

    var status: ScheduledAlarmStatus {
        get { ScheduledAlarmStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    var isActive: Bool {
        status == .scheduled || status == .snoozed
    }
}
