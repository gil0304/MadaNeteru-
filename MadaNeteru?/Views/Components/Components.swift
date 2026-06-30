//
//  Components.swift
//  MadaNeteru?
//
//  画面間で使い回す小さなビュー部品。
//

import SwiftUI

// MARK: - 警告バナー（要件 17.1）

struct WarningsBanner: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if !app.warnings.isEmpty {
            VStack(spacing: 8) {
                ForEach(Array(app.warnings.enumerated()), id: \.offset) { index, message in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warning)
                        Text(message)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            app.dismissWarning(index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Theme.warning.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

// MARK: - アラーム種別チップ

struct AlarmChip: View {
    let type: AlarmType
    var text: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.symbolName)
                .font(.caption2)
            Text(text ?? type.title)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.color(for: type).opacity(0.18),
                    in: Capsule())
        .foregroundStyle(Theme.color(for: type))
    }
}

// MARK: - 統計カード（ホーム）

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - バッテリーバッジ

struct BatteryBadge: View {
    let state: BatteryStateKind
    let level: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(label)
                .font(.subheadline.weight(.medium))
        }
    }

    private var symbol: String {
        switch state {
        case .charging:   return "battery.100.bolt"
        case .full:       return "battery.100"
        case .unplugged:  return level >= 0 && level < 0.25 ? "battery.25" : "battery.75"
        case .unknown, .notChecked: return "battery.0"
        }
    }
    private var tint: Color {
        state.isConfirmedCharged ? Theme.charge : (state == .unplugged ? Theme.warning : .secondary)
    }
    private var label: String {
        var text = state.label
        if level >= 0 { text += " \(Int(level * 100))%" }
        return text
    }
}

// MARK: - 予定行

struct EventRowView: View {
    let event: CalendarEvent
    let appliedAlarms: [EffectiveAlarm]
    let isMissing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.title)
                    .font(.headline)
                Spacer()
                if event.isAllDay {
                    Text("終日").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(AppDate.timeString(event.startDateTime))–\(AppDate.timeString(event.endDateTime))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isMissing {
                Label("起床アラーム未設定", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warning)
            }

            if !appliedAlarms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(uniqueTypes, id: \.self) { type in
                            AlarmChip(type: type, text: chipText(for: type))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var uniqueTypes: [AlarmType] {
        var seen: [AlarmType] = []
        for a in appliedAlarms.sorted(by: { $0.fireDate < $1.fireDate }) where !seen.contains(a.alarmType) {
            seen.append(a.alarmType)
        }
        return seen
    }

    private func chipText(for type: AlarmType) -> String {
        guard let a = appliedAlarms.first(where: { $0.alarmType == type }) else { return type.title }
        return "\(type.title) \(AppDate.timeString(a.fireDate))"
    }
}

// MARK: - セクション見出し

struct SectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.headline)
    }
}
