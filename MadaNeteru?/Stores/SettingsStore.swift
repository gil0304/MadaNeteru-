//
//  SettingsStore.swift
//  MadaNeteru?
//
//  要件 13.6（全体デフォルト設定）とオンボーディング状態など、スカラー設定を
//  UserDefaults に保持する。リッチなデータ（予定・ルール・履歴）は SwiftData。
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsStore {
    private let d = UserDefaults.standard

    // 起床・前日確認・充電確認のデフォルト時刻、未設定チェック時刻
    var defaultWakeHour: Int { didSet { d.set(defaultWakeHour, forKey: "defaultWakeHour") } }
    var defaultWakeMinute: Int { didSet { d.set(defaultWakeMinute, forKey: "defaultWakeMinute") } }
    var defaultPrevCheckHour: Int { didSet { d.set(defaultPrevCheckHour, forKey: "defaultPrevCheckHour") } }
    var defaultPrevCheckMinute: Int { didSet { d.set(defaultPrevCheckMinute, forKey: "defaultPrevCheckMinute") } }
    var defaultChargeHour: Int { didSet { d.set(defaultChargeHour, forKey: "defaultChargeHour") } }
    var defaultChargeMinute: Int { didSet { d.set(defaultChargeMinute, forKey: "defaultChargeMinute") } }
    var defaultReminderMinutesBefore: Int { didSet { d.set(defaultReminderMinutesBefore, forKey: "defaultReminderMinutesBefore") } }
    var missingCheckHour: Int { didSet { d.set(missingCheckHour, forKey: "missingCheckHour") } }
    var missingCheckMinute: Int { didSet { d.set(missingCheckMinute, forKey: "missingCheckMinute") } }

    var snoozeIntervalMinutes: Int { didSet { d.set(snoozeIntervalMinutes, forKey: "snoozeIntervalMinutes") } }
    var alarmSoundName: String { didSet { d.set(alarmSoundName, forKey: "alarmSoundName") } }
    var notificationSoundName: String { didSet { d.set(notificationSoundName, forKey: "notificationSoundName") } }

    var chargeCheckEnabled: Bool { didSet { d.set(chargeCheckEnabled, forKey: "chargeCheckEnabled") } }
    var defaultWakeEnabled: Bool { didSet { d.set(defaultWakeEnabled, forKey: "defaultWakeEnabled") } }
    var defaultPrevCheckEnabled: Bool { didSet { d.set(defaultPrevCheckEnabled, forKey: "defaultPrevCheckEnabled") } }
    var defaultReminderEnabled: Bool { didSet { d.set(defaultReminderEnabled, forKey: "defaultReminderEnabled") } }

    /// AlarmKit を使う（false の場合は通常通知のみ＝フォールバック）。
    var useAlarmKit: Bool { didSet { d.set(useAlarmKit, forKey: "useAlarmKit") } }
    var onboardingCompleted: Bool { didSet { d.set(onboardingCompleted, forKey: "onboardingCompleted") } }

    init() {
        let ud = UserDefaults.standard
        func int(_ key: String, _ def: Int) -> Int { ud.object(forKey: key) == nil ? def : ud.integer(forKey: key) }
        func bool(_ key: String, _ def: Bool) -> Bool { ud.object(forKey: key) == nil ? def : ud.bool(forKey: key) }
        func str(_ key: String, _ def: String) -> String { ud.string(forKey: key) ?? def }

        defaultWakeHour = int("defaultWakeHour", 7)
        defaultWakeMinute = int("defaultWakeMinute", 0)
        defaultPrevCheckHour = int("defaultPrevCheckHour", 22)
        defaultPrevCheckMinute = int("defaultPrevCheckMinute", 0)
        defaultChargeHour = int("defaultChargeHour", 22)
        defaultChargeMinute = int("defaultChargeMinute", 30)
        defaultReminderMinutesBefore = int("defaultReminderMinutesBefore", 60)
        missingCheckHour = int("missingCheckHour", 20)
        missingCheckMinute = int("missingCheckMinute", 0)
        snoozeIntervalMinutes = int("snoozeIntervalMinutes", 9)
        alarmSoundName = str("alarmSoundName", "default")
        notificationSoundName = str("notificationSoundName", "default")
        chargeCheckEnabled = bool("chargeCheckEnabled", true)
        defaultWakeEnabled = bool("defaultWakeEnabled", true)
        defaultPrevCheckEnabled = bool("defaultPrevCheckEnabled", true)
        defaultReminderEnabled = bool("defaultReminderEnabled", true)
        useAlarmKit = bool("useAlarmKit", true)
        onboardingCompleted = bool("onboardingCompleted", false)
    }
}
