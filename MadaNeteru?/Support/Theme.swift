//
//  Theme.swift
//  MadaNeteru?
//
//  夜・睡眠・起床を連想させる配色とスタイル。要件全体のトーンに合わせ、
//  「夜に整えて朝に起こす」アプリらしい落ち着いた色味にする。
//

import SwiftUI

enum Theme {
    /// アクセント（起床・行動を促すウォームカラー）。
    static let accent = Color(red: 1.0, green: 0.62, blue: 0.30)
    /// 夜・確認系のクールカラー。
    static let night = Color(red: 0.36, green: 0.40, blue: 0.78)
    static let charge = Color(red: 0.30, green: 0.78, blue: 0.55)
    static let warning = Color(red: 0.95, green: 0.45, blue: 0.42)

    /// 背景グラデーション（夜空 → 夜明け）。
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.09, green: 0.10, blue: 0.20),
            Color(red: 0.16, green: 0.15, blue: 0.30)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func color(for type: AlarmType) -> Color {
        switch type {
        case .wakeUp:              return accent
        case .previousDayCheck:    return night
        case .chargeCheck:         return charge
        case .departure:           return Color(red: 0.45, green: 0.70, blue: 0.95)
        case .eventReminder:       return .secondary
        case .missingAlarmWarning: return warning
        }
    }
}

/// カード共通スタイル。
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}
