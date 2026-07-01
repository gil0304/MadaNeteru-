//
//  ChargeAlarmView.swift
//  MadaNeteru?
//
//  アラーム鳴動画面（ロック画面風・アプリ内表示）。充電確認と起床の2種に対応。
//  ※ 実機のロック画面アラームは AlarmKit がシステム描画。これはアプリ内の表示。
//

import SwiftUI

/// 鳴動画面の種類。キャラと文言はここで切り替える。
enum AlarmRingKind: Identifiable, Hashable {
    case charge   // 充電確認 → ユウチャ
    case wake     // 起床     → エミリー

    var id: Self { self }

    var title: String { self == .charge ? "充電確認アラーム" : "起床アラーム" }
    var character: AppCharacter { self == .charge ? .yucha : .emily }
    var caption: String? { self == .charge ? "充電を確認できると自動で止まります" : nil }
}

struct AlarmRingingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    var kind: AlarmRingKind = .charge

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "H:mm"; return f
    }()

    var body: some View {
        ZStack {
            Theme.chargeAlarmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(kind.title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 24)

                Text(Self.timeFmt.string(from: .now))
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                SpeechBubble(tail: .bottomCenter) { bubbleText }
                    .padding(.top, 18)
                    .padding(.horizontal, 24)

                CharacterView(character: kind.character, height: 220, onDark: true)
                    .padding(.top, 6)

                if let caption = kind.caption {
                    Text(caption)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 4)
                }

                Spacer(minLength: 12)

                buttons
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: 文言

    @ViewBuilder private var bubbleText: some View {
        let timeStr = app.representativeEvent.map { AppDate.timeString($0.startDateTime) } ?? "予定"
        let title = app.representativeEvent?.title ?? "予定"
        switch kind {
        case .charge:
            styledText([("まだ充電してないよ〜！\n明日 ", nil), (timeStr, Theme.orange2), (" に予定あるのに！", nil)])
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.label)
                .multilineTextAlignment(.center).lineSpacing(3)
        case .wake:
            styledText([("朝だよ〜、起きて！\n", nil), (timeStr, Theme.orange2), (" に「\(title)」だよ！", nil)])
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.label)
                .multilineTextAlignment(.center).lineSpacing(3)
        }
    }

    // MARK: ボタン

    @ViewBuilder private var buttons: some View {
        switch kind {
        case .charge:
            VStack(spacing: 10) {
                primaryButton("充電した", color: Theme.green) { Task { await charged() } }
                HStack(spacing: 10) {
                    glassButton("15分後に再通知") { dismiss() }
                    glassButton("今日は不要") { Task { await app.chargeNotNeededTonight(); dismiss() } }
                }
            }
        case .wake:
            VStack(spacing: 10) {
                primaryButton("止める", color: Theme.green) { dismiss() }
                glassButton("スヌーズ") { dismiss() }
            }
        }
    }

    private func primaryButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(color, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func glassButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func charged() async {
        await app.confirmCharged()
        if app.tonightChargeCheck?.batteryState.isConfirmedCharged == true { dismiss() }
    }
}

/// 既存参照互換（充電確認の鳴動画面）。
struct ChargeAlarmView: View {
    var body: some View { AlarmRingingView(kind: .charge) }
}

#Preview("充電") { AlarmRingingView(kind: .charge).environment(PreviewSupport.appModel()) }
#Preview("起床") { AlarmRingingView(kind: .wake).environment(PreviewSupport.appModel()) }
