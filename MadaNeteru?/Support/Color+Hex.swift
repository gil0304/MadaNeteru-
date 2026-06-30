//
//  Color+Hex.swift
//  MadaNeteru?
//

import SwiftUI

extension Color {
    /// "#RRGGBB" / "RRGGBB" から Color を生成。失敗時は accent。
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else {
            self = Theme.accent
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }

    /// 代表色を 16 進文字列に固定で持たせるためのヘルパ。
    static func hex(for type: AlarmType) -> String {
        switch type {
        case .wakeUp:              return "FF9E4D"
        case .previousDayCheck:    return "5C66C7"
        case .chargeCheck:         return "4DC78C"
        case .departure:           return "73B3F2"
        case .eventReminder:       return "9AA0A6"
        case .missingAlarmWarning: return "F2736B"
        }
    }
}
