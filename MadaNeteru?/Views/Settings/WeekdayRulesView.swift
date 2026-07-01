//
//  WeekdayRulesView.swift
//  MadaNeteru?
//
//  曜日ルール。曜日サークルで日を選び、その日の設定を iOS標準 Form で編集する。
//

import SwiftUI

struct WeekdayRulesView: View {
    @Environment(AppModel.self) private var app
    @State private var selected: Weekday = Weekday.of(.now)

    var body: some View {
        VStack(spacing: 0) {
            dayCircles
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
                .background(Theme.groupedBg)

            Form {
                Section("\(selected.longLabel)の設定") {
                    timeRow(.wakeUp, title: "起床アラーム")
                    timeRow(.previousDayCheck, title: "前日の確認")
                    timeRow(.chargeCheck, title: "充電の確認")
                    Toggle(isOn: departureBinding) {
                        Label { Text("出発アラーム") } icon: { AlarmTypeIcon(type: .departure, size: 26) }
                    }
                    .tint(Theme.green)
                }

                Section {
                    Toggle("この曜日を有効", isOn: enabledBinding).tint(Theme.green)
                } footer: {
                    Text("曜日の設定は予定ごとの個別設定の次に優先され、全体デフォルトを上書きします。")
                }
            }
        }
        .navigationTitle("曜日ルール")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 曜日サークル

    private var dayCircles: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.mondayFirst) { w in
                DayCircle(label: w.shortLabel, selected: w == selected,
                          textColor: textColor(w), action: { selected = w })
            }
        }
    }

    private func textColor(_ w: Weekday) -> Color {
        if !app.weekdayHasRules(w) { return Theme.chevron }
        switch w {
        case .sunday:   return Theme.red
        case .saturday: return Theme.orange
        default:        return Theme.label
        }
    }

    // MARK: 行

    private func timeRow(_ type: AlarmType, title: String) -> some View {
        DatePicker(selection: timeBinding(type), displayedComponents: .hourAndMinute) {
            Label { Text(title) } icon: { AlarmTypeIcon(type: type, size: 26) }
        }
    }

    private func rule(_ type: AlarmType) -> AlarmRule? {
        app.weekdayRules(selected).first { $0.alarmType == type && $0.isEnabled }
    }

    private func defaultHour(_ type: AlarmType) -> Int {
        switch type {
        case .wakeUp:           return app.settings.defaultWakeHour
        case .previousDayCheck: return app.settings.defaultPrevCheckHour
        case .chargeCheck:      return app.settings.defaultChargeHour
        default:                return 8
        }
    }

    private func timeBinding(_ type: AlarmType) -> Binding<Date> {
        Binding(
            get: {
                if let r = rule(type), let h = r.alarmHour, let m = r.alarmMinute {
                    return AppDate.at(hour: h, minute: m, on: .now)
                }
                return AppDate.at(hour: defaultHour(type), minute: 0, on: .now)
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                app.setWeekdayRule(weekday: selected, type: type, enabled: true,
                                   hour: c.hour ?? 7, minute: c.minute ?? 0)
            }
        )
    }

    private var departureBinding: Binding<Bool> {
        Binding(
            get: { rule(.departure) != nil },
            set: { v in app.setWeekdayRule(weekday: selected, type: .departure, enabled: v, hour: 8, minute: 30) }
        )
    }
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { app.weekdayHasRules(selected) },
            set: { v in app.setWeekdayEnabled(selected, enabled: v) }
        )
    }
}

#Preview {
    NavigationStack {
        WeekdayRulesView().environment(PreviewSupport.appModel())
    }
}
