//
//  DefaultSettingsView.swift
//  MadaNeteru?
//
//  全体デフォルト設定（ルールタブ配下）。iOS標準の Form を使う。
//  「設定」タブを置かないため、アカウント／権限もここにまとめる。
//

import SwiftUI

struct DefaultSettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var settings = app.settings

        Form {
            Section {
                cameoRow(text: "ここで全体の基本ルールを決めるよ！")
            }
            .listRowBackground(Color.clear)

            Section("アラーム") {
                timeRow(.wakeUp, title: "デフォルト起床",
                        date: dateBinding($settings.defaultWakeHour, $settings.defaultWakeMinute))
                timeRow(.previousDayCheck, title: "前日の確認",
                        date: dateBinding($settings.defaultPrevCheckHour, $settings.defaultPrevCheckMinute))
                timeRow(.chargeCheck, title: "充電確認",
                        date: dateBinding($settings.defaultChargeHour, $settings.defaultChargeMinute))
                DatePicker(selection: dateBinding($settings.missingCheckHour, $settings.missingCheckMinute),
                           displayedComponents: .hourAndMinute) {
                    Label { Text("未設定チェック") } icon: { EmojiIcon(emoji: "🔔", color: Theme.yellow, size: 26) }
                }
            }

            Section("音・スヌーズ") {
                Picker("スヌーズ間隔", selection: $settings.snoozeIntervalMinutes) {
                    ForEach([5, 9, 10, 15], id: \.self) { Text("\($0)分").tag($0) }
                }
                Picker("アラーム音", selection: $settings.alarmSoundName) {
                    ForEach(["あさひ", "しずく", "ベル"], id: \.self) { Text($0).tag($0) }
                }
                Picker("通知音", selection: $settings.notificationSoundName) {
                    ForEach(["ぽん", "ピコ", "チャイム"], id: \.self) { Text($0).tag($0) }
                }
            }

            Section("アカウント") {
                if app.isSignedIn {
                    LabeledContent("Google", value: app.user?.email ?? "—")
                }
                permRow(title: "アラーム（AlarmKit）", status: app.alarmAuth) { Task { await app.requestAlarmAuthorization() } }
                permRow(title: "通知", status: app.notifAuth) { Task { await app.requestNotificationAuthorization() } }
                Button(role: .destructive) {
                    Task { await app.signOut() }
                } label: {
                    Text(app.isSignedIn ? "ログアウト" : "Googleでログイン")
                }
            }
        }
        .navigationTitle("デフォルト設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { normalizeSounds(settings) }
        .onDisappear { app.refreshAfterSettingsChange() }
    }

    // MARK: 行

    private func timeRow(_ type: AlarmType, title: String, date: Binding<Date>) -> some View {
        DatePicker(selection: date, displayedComponents: .hourAndMinute) {
            Label { Text(title) } icon: { AlarmTypeIcon(type: type, size: 26) }
        }
    }

    @ViewBuilder
    private func permRow(title: String, status: AuthStatus, request: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch status {
            case .authorized:
                Label("許可済み", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon).foregroundStyle(Theme.green)
            case .denied:
                Text("拒否").foregroundStyle(Theme.red)
            case .notDetermined:
                Button("許可する", action: request)
            }
        }
    }

    private func cameoRow(text: String) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            CharacterView(character: .yucha, height: 110)
            SpeechBubble(tail: .leading, radius: 14) {
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.label)
            }
            .padding(.bottom, 16)
            Spacer(minLength: 0)
        }
    }

    // MARK: ヘルパ

    private func dateBinding(_ h: Binding<Int>, _ m: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { AppDate.at(hour: h.wrappedValue, minute: m.wrappedValue, on: .now) },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                h.wrappedValue = c.hour ?? 0
                m.wrappedValue = c.minute ?? 0
            }
        )
    }

    private func normalizeSounds(_ s: SettingsStore) {
        if s.alarmSoundName == "default" { s.alarmSoundName = "あさひ" }
        if s.notificationSoundName == "default" { s.notificationSoundName = "ぽん" }
    }
}

#Preview {
    NavigationStack {
        DefaultSettingsView().environment(PreviewSupport.appModel())
    }
}
