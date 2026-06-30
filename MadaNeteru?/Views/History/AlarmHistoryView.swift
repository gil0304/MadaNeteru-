//
//  AlarmHistoryView.swift
//  MadaNeteru?
//
//  要件 13.7。アラーム実行・予定の履歴。
//

import SwiftUI

struct AlarmHistoryView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            Group {
                let grouped = groupedHistory
                if grouped.isEmpty {
                    ContentUnavailableView(
                        "履歴はまだありません",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("アラームがスケジュール・実行されると、ここに表示されます。")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.day) { group in
                            Section(AppDate.dateString(group.day)) {
                                ForEach(group.items) { item in
                                    HistoryRow(alarm: item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("履歴")
        }
    }

    private var groupedHistory: [(day: Date, items: [ScheduledAlarm])] {
        let history = app.alarmHistory()
        let groups = Dictionary(grouping: history) { AppDate.startOfDay($0.scheduledAt) }
        return groups.keys.sorted(by: >).map { (day: $0, items: groups[$0]!.sorted { $0.scheduledAt > $1.scheduledAt }) }
    }
}

struct HistoryRow: View {
    let alarm: ScheduledAlarm

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alarm.alarmType.symbolName)
                .foregroundStyle(Theme.color(for: alarm.alarmType))
                .frame(width: 26)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(alarm.title).font(.subheadline.weight(.semibold))
                if let eventTitle = alarm.eventTitle, !eventTitle.isEmpty {
                    Text(eventTitle).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Label(AppDate.timeString(alarm.scheduledAt), systemImage: "clock")
                    if alarm.snoozeCount > 0 {
                        Label("\(alarm.snoozeCount)", systemImage: "zzz")
                    }
                    if alarm.chargeConfirmed {
                        Label("充電確認済", systemImage: "bolt.fill").foregroundStyle(Theme.charge)
                    }
                    if !alarm.usedAlarmKit {
                        Label("通知", systemImage: "bell").foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        Text(alarm.status.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.18), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch alarm.status {
        case .scheduled: return Theme.night
        case .fired:     return Theme.accent
        case .dismissed: return Theme.charge
        case .snoozed:   return Theme.accent
        case .cancelled: return .secondary
        case .failed:    return Theme.warning
        }
    }
}

#Preview {
    AlarmHistoryView()
        .environment(PreviewSupport.appModel())
}
