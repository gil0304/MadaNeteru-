//
//  ChargeCheck.swift
//  MadaNeteru?
//
//  要件 11章。翌日に予定がある日の夜の「充電確認」1 回分の記録。
//  「充電済みと確認できた時だけ鳴らさない」という安全側ロジックを保持する。
//

import Foundation
import SwiftData

@Model
final class ChargeCheck {
    @Attribute(.unique) var id: String
    var userId: String

    /// この充電確認が対象とする「予定がある日」（＝翌朝）。日付の正規化済み。
    var eventDate: Date
    /// 夜の確認予定時刻。
    var checkTime: Date

    var batteryStateRaw: String
    var batteryLevel: Double      // 0.0〜1.0、取得不可は -1
    var confirmedCharging: Bool   // 充電済みと確認できたか
    var alarmScheduled: Bool
    var alarmDismissed: Bool
    var userActionRaw: String

    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        eventDate: Date,
        checkTime: Date,
        batteryState: BatteryStateKind = .notChecked,
        batteryLevel: Double = -1,
        confirmedCharging: Bool = false,
        alarmScheduled: Bool = false,
        alarmDismissed: Bool = false,
        userAction: ChargeUserAction = .none
    ) {
        self.id = id
        self.userId = userId
        self.eventDate = eventDate
        self.checkTime = checkTime
        self.batteryStateRaw = batteryState.rawValue
        self.batteryLevel = batteryLevel
        self.confirmedCharging = confirmedCharging
        self.alarmScheduled = alarmScheduled
        self.alarmDismissed = alarmDismissed
        self.userActionRaw = userAction.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    var batteryState: BatteryStateKind {
        get { BatteryStateKind(rawValue: batteryStateRaw) ?? .notChecked }
        set { batteryStateRaw = newValue.rawValue }
    }

    var userAction: ChargeUserAction {
        get { ChargeUserAction(rawValue: userActionRaw) ?? .none }
        set { userActionRaw = newValue.rawValue }
    }

    /// 要件 11.3: 充電済みと確認できた場合「だけ」鳴らさない。
    var shouldRingAlarm: Bool {
        !batteryState.isConfirmedCharged
    }
}
