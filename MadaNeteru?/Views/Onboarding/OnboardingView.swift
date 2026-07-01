//
//  OnboardingView.swift
//  MadaNeteru?
//
//  v4 オンボーディング。① ようこそ・ログイン → ② 許可。
//  キャラクターが自己紹介しながらログイン・権限へ誘導する。
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var step = DemoLaunch.onboardStep
    @State private var busy = false

    var body: some View {
        ZStack {
            if step == 0 {
                loginStep.transition(.opacity)
            } else {
                permissionsStep.transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: ① ようこそ・ログイン

    private var loginStep: some View {
        ZStack {
            Theme.loginBg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                SpeechBubble(tail: .bottomCenter) {
                    Text("はじめまして！\nあなたが寝坊しないように、\nわたしが見張ってるね。")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.bubbleText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)

                CharacterView(character: .emily, height: 264)
                    .padding(.top, 12)

                Text("まだねてる？")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Theme.label)
                    .padding(.top, 4)

                Spacer(minLength: 16)

                Button {
                    Task {
                        busy = true
                        await app.signInWithGoogle()
                        busy = false
                        // 初回のみ許可ステップへ。再ログイン（オンボ済み）はそのままメインへ。
                        if app.isSignedIn && !app.settings.onboardingCompleted { step = 1 }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if busy {
                            ProgressView()
                        } else {
                            GoogleGlyph()
                            Text("Google でログイン")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.label)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .padding(.horizontal, 24)

                Text("カレンダーの予定を読み取ります")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 10)

                Spacer(minLength: 30)
            }
        }
    }

    // MARK: ② 許可

    private var permissionsStep: some View {
        ZStack {
            Theme.groupedBg.ignoresSafeArea()
            VStack(spacing: 0) {
                // 上部：キャラ＋吹き出し
                HStack(alignment: .bottom, spacing: 10) {
                    CharacterView(character: .gil, height: 152)
                    SpeechBubble(tail: .leading, bg: Color(hex: "EAEAEF")) {
                        Text("アラームをちゃんと鳴らすのに、4つだけ許可してね！")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.bubbleText)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(Color.white)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "アクセスの許可")
                        InsetCard {
                            permissionRow(color: Theme.red, emoji: "📅", title: "カレンダー",
                                          subtitle: "予定を読み取る", granted: app.isSignedIn)
                            RowSeparator()
                            permissionRow(color: Theme.orange2, emoji: "⏰", title: "アラーム（AlarmKit）",
                                          subtitle: "長く鳴らす重要アラーム", granted: app.alarmAuth == .authorized)
                            RowSeparator()
                            permissionRow(color: Theme.green, emoji: "🔋", title: "バッテリー",
                                          subtitle: "充電を確認する", granted: batteryGranted)
                            RowSeparator()
                            permissionRow(color: Theme.pink, emoji: "🔔", title: "通知",
                                          subtitle: "軽いリマインド", granted: app.notifAuth == .authorized)
                        }
                    }
                    .padding(16)
                }

                PrimaryButton(title: "すべて許可してつづける") {
                    Task { await grantAllAndContinue() }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
    }

    private var batteryGranted: Bool { app.battery.state != .notChecked }

    private func permissionRow(color: Color, emoji: String, title: String, subtitle: String, granted: Bool) -> some View {
        HStack(spacing: 13) {
            EmojiIcon(emoji: emoji, color: color, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.label)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22)).foregroundStyle(Theme.green)
            } else {
                Circle().strokeBorder(Theme.chevron, lineWidth: 2).frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }

    private func grantAllAndContinue() async {
        app.battery.refresh()
        await app.requestAlarmAuthorization()
        await app.requestNotificationAuthorization()
        app.settings.onboardingCompleted = true
        if app.isSignedIn { await app.sync() }
    }
}

/// Google ブランドの 4 色 G（簡易）。
struct GoogleGlyph: View {
    var body: some View {
        Text("G")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color(hex: "4285F4"))
            .frame(width: 18, height: 18)
    }
}

#Preview {
    OnboardingView()
        .environment(PreviewSupport.appModel(signedIn: false, seedEvents: false))
}
