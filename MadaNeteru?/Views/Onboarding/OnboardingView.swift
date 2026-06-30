//
//  OnboardingView.swift
//  MadaNeteru?
//
//  要件 13.1 / 15.1。初回起動の流れ: 説明 → Google ログイン → AlarmKit 許可 →
//  通知許可 → 充電確認の初期設定 → はじめる。
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var busy = false

    var body: some View {
        @Bindable var settings = app.settings

        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    stepCard(
                        index: 1, title: "Googleでログイン",
                        subtitle: app.isSignedIn ? app.user?.email ?? "ログイン済み"
                                                 : "カレンダーの予定を読み取ります（読み取り専用）",
                        done: app.isSignedIn
                    ) {
                        Button(app.isSignedIn ? "ログイン済み" : "Googleでログイン") {
                            Task { busy = true; await app.signInWithGoogle(); busy = false }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(app.isSignedIn || busy)
                    }

                    stepCard(
                        index: 2, title: "AlarmKit を許可",
                        subtitle: "起床・充電確認など重要なアラームを確実に鳴らすために使います",
                        done: app.alarmAuth == .authorized
                    ) {
                        Button(authLabel(app.alarmAuth)) {
                            Task { await app.requestAlarmAuthorization() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(app.alarmAuth == .authorized)
                    }

                    stepCard(
                        index: 3, title: "通知を許可",
                        subtitle: "予定リマインドや同期完了などの軽い通知に使います",
                        done: app.notifAuth == .authorized
                    ) {
                        Button(authLabel(app.notifAuth)) {
                            Task { await app.requestNotificationAuthorization() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(app.notifAuth == .authorized)
                    }

                    stepCard(
                        index: 4, title: "夜の充電確認アラーム",
                        subtitle: "翌日に予定がある夜、充電を確認できていなければ鳴らします",
                        done: settings.chargeCheckEnabled
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("充電確認アラームを使う", isOn: $settings.chargeCheckEnabled)
                            if settings.chargeCheckEnabled {
                                TimePickerRow(title: "確認する時刻",
                                              hour: $settings.defaultChargeHour,
                                              minute: $settings.defaultChargeMinute)
                            }
                        }
                    }

                    Button {
                        app.settings.onboardingCompleted = true
                        Task { if app.isSignedIn { await app.sync() } }
                    } label: {
                        Text("はじめる")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!app.isSignedIn)

                    if !app.isSignedIn {
                        Text("※ まずは Google ログインから始めてください")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("まだ寝てる?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Googleカレンダーの予定に合わせて、前日の夜に\n起床アラームと充電を自動で整えるアプリ。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func stepCard<Content: View>(
        index: Int, title: String, subtitle: String, done: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(done ? Theme.charge : Color.white.opacity(0.15))
                        .frame(width: 28, height: 28)
                    if done {
                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                    } else {
                        Text("\(index)").font(.caption.bold()).foregroundStyle(.white)
                    }
                }
                Text(title).font(.headline).foregroundStyle(.white)
                Spacer()
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            content()
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func authLabel(_ status: AuthStatus) -> String {
        switch status {
        case .authorized:    return "許可済み"
        case .denied:        return "拒否されています（設定アプリで変更）"
        case .notDetermined: return "許可する"
        }
    }
}

/// 時:分のピッカー行（設定画面でも使う）。
struct TimePickerRow: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("時", selection: $hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .labelsHidden()
            Text(":")
            Picker("分", selection: $minute) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) {
                    Text(String(format: "%02d", $0)).tag($0)
                }
            }
            .labelsHidden()
        }
        .pickerStyle(.menu)
    }
}

#Preview {
    OnboardingView()
        .environment(PreviewSupport.appModel(signedIn: false, seedEvents: false))
}
