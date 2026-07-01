//
//  Theme.swift
//  MadaNeteru?
//
//  「まだねてる？ ハイファイ v4」のデザイントークン。
//  iOS標準デザインを基調に、オレンジ(#EE5A24)をアクセントにする。
//

import SwiftUI
import UIKit

enum Theme {
    // アクセント
    static let orange = Color(hex: "EE5A24")   // 主アクセント（タブ・ボタン・個別バッジは赤系）
    static let orange2 = Color(hex: "FF9500")  // 時刻・起床・注意
    static let accent = orange                 // 後方互換

    // システムカラー（iOS 標準に寄せる）
    static let red = Color(hex: "FF3B30")
    static let indigo = Color(hex: "5856D6")
    static let green = Color(hex: "34C759")
    static let teal = Color(hex: "00C7BE")
    static let yellow = Color(hex: "FFCC00")
    static let purple = Color(hex: "AF52DE")
    static let pink = Color(hex: "FF2D55")
    static let cyan = Color(hex: "30B0C7")

    // 後方互換エイリアス
    static let night = indigo
    static let charge = green
    static let warning = orange2

    // ニュートラル
    static let groupedBg = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let label = Color(uiColor: .label)
    static let bubbleText = Color(hex: "1C1C1E")
    static let secondary = Color(uiColor: .secondaryLabel)
    static let sectionLabel = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    static let chevron = Color(uiColor: .tertiaryLabel)
    static let segmentBg = Color(uiColor: .tertiarySystemFill)
    static let legendBg = Color(uiColor: .secondarySystemFill)

    // グラデーション
    /// ホームのヒーロー（夜）。
    static let homeHeroNight = LinearGradient(
        stops: [
            .init(color: Color(hex: "2E2A55"), location: 0.0),
            .init(color: Color(hex: "5B4E8C"), location: 0.48),
            .init(color: Color(hex: "C58BB0"), location: 0.88),
            .init(color: Color(hex: "F2C9A0"), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )
    /// ホームのヒーロー（朝〜昼）。
    static let homeHeroMorning = LinearGradient(
        stops: [
            .init(color: Color(hex: "8FD3FF"), location: 0.0),
            .init(color: Color(hex: "B5E4FF"), location: 0.40),
            .init(color: Color(hex: "FFD59A"), location: 0.88),
            .init(color: Color(hex: "FFF1C8"), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )
    /// オンボーディングのログイン背景。
    static let loginBg = LinearGradient(
        stops: [
            .init(color: Color(hex: "FFE7C4"), location: 0.0),
            .init(color: Color(hex: "FFF3E2"), location: 0.46),
            .init(color: Color(hex: "F2F2F7"), location: 0.46),
            .init(color: Color(hex: "F2F2F7"), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )
    /// 充電確認アラーム（鳴動）背景。
    static let chargeAlarmBg = LinearGradient(
        stops: [
            .init(color: Color(hex: "1A1430"), location: 0.0),
            .init(color: Color(hex: "3A2740"), location: 0.6),
            .init(color: Color(hex: "5A3A44"), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )
    /// 後方互換（旧 backgroundGradient 利用箇所向け）。
    static let backgroundGradient = loginBg

    /// アラーム種別の代表色（行アイコンの背景など）。
    static func color(for type: AlarmType) -> Color {
        switch type {
        case .wakeUp:              return orange2
        case .previousDayCheck:    return indigo
        case .chargeCheck:         return green
        case .departure:           return teal
        case .eventReminder:       return cyan
        case .missingAlarmWarning: return yellow
        }
    }
}

/// インセットグループ風カードの共通スタイル。
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}
