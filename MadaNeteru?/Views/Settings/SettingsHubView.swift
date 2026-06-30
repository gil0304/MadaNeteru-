//
//  SettingsHubView.swift
//  MadaNeteru?
//
//  設定のハブ。全体デフォルト（13.6）・曜日ルール（13.5）への入口、
//  アカウント、権限状態、AlarmKit 使用可否をまとめる。
//

import SwiftUI

struct SettingsHubView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var settings = app.settings

        NavigationStack {
            List {
                Section("アラーム設定") {
                    NavigationLink {
                        DefaultSettingsView()
                    } label: {
                        Label("全体デフォルト設定", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        WeekdayRulesView()
                    } label: {
                        Label("曜日ごとのルール", systemImage: "calendar.day.timeline.left")
                    }
                }

                Section("アカウント") {
                    if app.isSignedIn {
                        LabeledContent("Google", value: app.user?.email ?? "—")
                        Button("ログアウト", role: .destructive) {
                            Task { await app.signOut() }
                        }
                    } else {
                        Button("Googleでログイン") {
                            Task { await app.signInWithGoogle() }
                        }
                    }
                }

                Section {
                    permissionRow(title: "AlarmKit", status: app.alarmAuth) {
                        Task { await app.requestAlarmAuthorization() }
                    }
                    permissionRow(title: "通知", status: app.notifAuth) {
                        Task { await app.requestNotificationAuthorization() }
                    }
                    Toggle(isOn: $settings.useAlarmKit) {
                        Label("AlarmKitで強く鳴らす", systemImage: "alarm.waves.left.and.right.fill")
                    }
                } header: {
                    Text("権限")
                } footer: {
                    Text("AlarmKitが使えない場合は通常通知で代替します（要件 12・17.1）。")
                }

                Section("このアプリについて") {
                    Text("Googleカレンダーの予定に合わせて、前日の夜に起床アラームと充電を自動で整える「寝坊・充電忘れ防止アラーム」です。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .onChange(of: settings.useAlarmKit) { _, _ in
                Task { await app.refreshAfterSettingsChange() }
            }
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, status: AuthStatus, request: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch status {
            case .authorized:
                Label("許可済み", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.charge)
                    .labelStyle(.titleAndIcon)
            case .denied:
                Text("拒否").foregroundStyle(Theme.warning)
            case .notDetermined:
                Button("許可する", action: request)
            }
        }
    }
}

#Preview {
    SettingsHubView()
        .environment(PreviewSupport.appModel())
}
