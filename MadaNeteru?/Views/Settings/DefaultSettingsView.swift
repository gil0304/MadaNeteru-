//
//  DefaultSettingsView.swift
//  MadaNeteru?
//
//  要件 13.6。全てに適用する全体デフォルト設定。
//

import SwiftUI

struct DefaultSettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var settings = app.settings

        Form {
            Section {
                Toggle("起床アラーム", isOn: $settings.defaultWakeEnabled).tint(Theme.accent)
                if settings.defaultWakeEnabled {
                    TimePickerRow(title: "起床時刻", hour: $settings.defaultWakeHour, minute: $settings.defaultWakeMinute)
                }
            } header: { Text("起床") }

            Section {
                Toggle("前日確認アラーム", isOn: $settings.defaultPrevCheckEnabled).tint(Theme.night)
                if settings.defaultPrevCheckEnabled {
                    TimePickerRow(title: "前日の時刻", hour: $settings.defaultPrevCheckHour, minute: $settings.defaultPrevCheckMinute)
                }
            } header: { Text("前日確認") }

            Section {
                Toggle("充電確認アラーム", isOn: $settings.chargeCheckEnabled).tint(Theme.charge)
                if settings.chargeCheckEnabled {
                    TimePickerRow(title: "充電確認の時刻", hour: $settings.defaultChargeHour, minute: $settings.defaultChargeMinute)
                }
            } header: { Text("充電確認") } footer: {
                Text("翌日に予定がある夜、充電を確認できていなければ鳴らします。")
            }

            Section {
                Toggle("予定リマインド", isOn: $settings.defaultReminderEnabled)
                if settings.defaultReminderEnabled {
                    Picker("予定の何分前", selection: $settings.defaultReminderMinutesBefore) {
                        ForEach([15, 30, 60, 90, 120], id: \.self) { Text(minuteLabel($0)).tag($0) }
                    }
                }
            } header: { Text("予定リマインド（通常通知）") }

            Section {
                TimePickerRow(title: "未設定チェック時刻", hour: $settings.missingCheckHour, minute: $settings.missingCheckMinute)
            } header: { Text("アラーム未設定チェック") } footer: {
                Text("毎日この時刻に翌日の予定を点検し、起床アラーム未設定があれば前夜に警告します。")
            }

            Section {
                Picker("スヌーズ間隔", selection: $settings.snoozeIntervalMinutes) {
                    ForEach([5, 9, 10, 15], id: \.self) { Text("\($0)分").tag($0) }
                }
                Picker("アラーム音", selection: $settings.alarmSoundName) {
                    Text("標準").tag("default")
                }
                Picker("通知音", selection: $settings.notificationSoundName) {
                    Text("標準").tag("default")
                }
            } header: { Text("音・スヌーズ") }
        }
        .navigationTitle("全体デフォルト")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Task { await app.refreshAfterSettingsChange() } }
    }

    private func minuteLabel(_ m: Int) -> String {
        m % 60 == 0 ? "\(m / 60)時間前" : "\(m)分前"
    }
}

#Preview {
    NavigationStack {
        DefaultSettingsView()
            .environment(PreviewSupport.appModel())
    }
}
