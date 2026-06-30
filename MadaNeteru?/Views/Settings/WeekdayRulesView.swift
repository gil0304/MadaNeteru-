//
//  WeekdayRulesView.swift
//  MadaNeteru?
//
//  要件 13.5 / 7.2。曜日ごとのアラームルール。
//

import SwiftUI

struct WeekdayRulesView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        List {
            Section {
                ForEach(Weekday.mondayFirst) { weekday in
                    NavigationLink {
                        WeekdayEditorView(weekday: weekday)
                    } label: {
                        HStack {
                            Text(weekday.longLabel)
                            Spacer()
                            Text(summary(weekday))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("曜日の設定は予定ごとの個別設定の次に優先され、全体デフォルトを上書きします。")
            }
        }
        .navigationTitle("曜日ごとのルール")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ weekday: Weekday) -> String {
        let rules = app.weekdayRules(weekday).filter { $0.isEnabled }
        if rules.isEmpty { return "全体デフォルト" }
        return rules
            .sorted { ($0.alarmHour ?? 0) < ($1.alarmHour ?? 0) }
            .map { "\($0.alarmType.title.prefix(2))\($0.timeDescription)" }
            .joined(separator: " / ")
    }
}

// MARK: - 曜日エディタ

struct WeekdayEditorView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let weekday: Weekday

    @State private var fields: [AlarmType: RuleField] = [:]

    private let editableTypes: [AlarmType] = [.wakeUp, .previousDayCheck, .chargeCheck, .departure]

    var body: some View {
        Form {
            ForEach(editableTypes) { type in
                Section {
                    Toggle(isOn: binding(type).enabled) {
                        Label(type.title, systemImage: type.symbolName)
                    }
                    .tint(Theme.color(for: type))

                    if fields[type]?.enabled == true {
                        TimePickerRow(title: timeLabel(type),
                                      hour: binding(type).hour,
                                      minute: binding(type).minute)
                    }
                }
            }
        }
        .navigationTitle(weekday.longLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
            }
        }
        .onAppear(perform: load)
    }

    private func timeLabel(_ type: AlarmType) -> String {
        switch type {
        case .chargeCheck, .previousDayCheck: return "前日の時刻"
        default: return "時刻"
        }
    }

    private func load() {
        var dict: [AlarmType: RuleField] = [:]
        for type in editableTypes {
            if let rule = app.weekdayRules(weekday).first(where: { $0.alarmType == type }) {
                dict[type] = RuleField(enabled: rule.isEnabled,
                                       hour: rule.alarmHour ?? defaultHour(type),
                                       minute: rule.alarmMinute ?? 0)
            } else {
                dict[type] = RuleField(enabled: false, hour: defaultHour(type), minute: 0)
            }
        }
        fields = dict
    }

    private func defaultHour(_ type: AlarmType) -> Int {
        switch type {
        case .wakeUp: return app.settings.defaultWakeHour
        case .previousDayCheck: return app.settings.defaultPrevCheckHour
        case .chargeCheck: return app.settings.defaultChargeHour
        case .departure: return 8
        default: return 7
        }
    }

    private func save() {
        Task {
            for type in editableTypes {
                guard let f = fields[type] else { continue }
                await app.setWeekdayRule(weekday: weekday, type: type,
                                         enabled: f.enabled, hour: f.hour, minute: f.minute)
            }
            dismiss()
        }
    }

    private func binding(_ type: AlarmType) -> (enabled: Binding<Bool>, hour: Binding<Int>, minute: Binding<Int>) {
        (
            enabled: Binding(get: { fields[type]?.enabled ?? false },
                             set: { fields[type, default: .init()].enabled = $0 }),
            hour: Binding(get: { fields[type]?.hour ?? 7 },
                          set: { fields[type, default: .init()].hour = $0 }),
            minute: Binding(get: { fields[type]?.minute ?? 0 },
                            set: { fields[type, default: .init()].minute = $0 })
        )
    }
}

struct RuleField {
    var enabled: Bool = false
    var hour: Int = 7
    var minute: Int = 0
}

#Preview {
    NavigationStack {
        WeekdayRulesView()
            .environment(PreviewSupport.appModel())
    }
}
