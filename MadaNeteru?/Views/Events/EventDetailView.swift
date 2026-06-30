//
//  EventDetailView.swift
//  MadaNeteru?
//
//  要件 13.4 / 15.3。予定ごとのアラーム設定。
//  起床・前日確認・出発・直前通知の追加、充電確認 ON/OFF、この予定だけ不要。
//

import SwiftUI

struct EventDetailView: View {
    @Environment(AppModel.self) private var app
    let event: CalendarEvent

    @State private var addType: AlarmType?
    @State private var optedOut: Bool = false

    var body: some View {
        List {
            headerSection
            appliedSection
            eventAlarmsSection
            chargeSection
            optOutSection
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { optedOut = app.isEventOptedOut(event) }
        .sheet(item: $addType) { type in
            AddAlarmSheet(event: event, type: type)
                .presentationDetents([.medium])
        }
    }

    // MARK: 予定情報

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(event.title).font(.title3.bold())
                Label(AppDate.dateTimeString(event.startDateTime) + "–" + AppDate.timeString(event.endDateTime),
                      systemImage: "clock")
                    .font(.subheadline)
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse").font(.subheadline)
                }
                Label(calendarName, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var calendarName: String {
        switch event.googleCalendarId {
        case "primary": return "予定"
        case "work":    return "仕事"
        default:        return event.googleCalendarId
        }
    }

    // MARK: 適用中のルール

    private var appliedSection: some View {
        Section("適用中のアラーム") {
            let applied = app.effectiveAlarms(for: event).sorted { $0.fireDate < $1.fireDate }
            if applied.isEmpty {
                Text("適用中のアラームはありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(applied) { alarm in
                    HStack {
                        Image(systemName: alarm.alarmType.symbolName)
                            .foregroundStyle(Theme.color(for: alarm.alarmType))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alarm.alarmType.title).font(.subheadline.weight(.medium))
                            Text(tierLabel(alarm)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(AppDate.dateTimeString(alarm.fireDate))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func tierLabel(_ alarm: EffectiveAlarm) -> String {
        if alarm.ruleId.hasPrefix("global-") { return "全体デフォルト" }
        if let rule = app.allRules().first(where: { $0.id == alarm.ruleId }) {
            switch rule.targetType {
            case .event:   return "この予定の個別設定"
            case .weekday: return (rule.weekday?.longLabel ?? "曜日") + "の設定"
            case .global:  return "全体デフォルト"
            }
        }
        return "—"
    }

    // MARK: 個別アラーム

    private var eventAlarmsSection: some View {
        Section {
            let eventRules = app.rules(forEvent: event.id).filter { $0.isEnabled }
            ForEach(eventRules) { rule in
                HStack {
                    Image(systemName: rule.alarmType.symbolName)
                        .foregroundStyle(Theme.color(for: rule.alarmType))
                        .frame(width: 24)
                    Text(rule.alarmType.title)
                    Spacer()
                    Text(rule.timeDescription)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("削除", role: .destructive) {
                        Task { await app.removeRule(rule) }
                    }
                }
            }

            Menu {
                Button { addType = .wakeUp } label: { Label("起床アラーム", systemImage: "alarm") }
                Button { addType = .previousDayCheck } label: { Label("前日確認", systemImage: "checklist") }
                Button { addType = .departure } label: { Label("出発アラーム", systemImage: "figure.walk") }
                Button { addType = .eventReminder } label: { Label("直前通知", systemImage: "bell") }
            } label: {
                Label("アラームを追加", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("この予定の個別アラーム")
        } footer: {
            Text("個別設定は曜日・全体より優先されます（要件 8章）。")
        }
    }

    // MARK: 充電確認

    private var chargeSection: some View {
        Section {
            Toggle(isOn: chargeBinding) {
                Label("充電確認アラーム", systemImage: "battery.100.bolt")
            }
            .tint(Theme.charge)
        } footer: {
            Text("ONにすると、この予定の前夜に充電確認アラームを鳴らします。")
        }
    }

    private var chargeBinding: Binding<Bool> {
        Binding(
            get: { isChargeEnabled },
            set: { newValue in Task { await app.setEventChargeCheck(event: event, enabled: newValue) } }
        )
    }

    private var isChargeEnabled: Bool {
        let chargeRules = app.rules(forEvent: event.id).filter { $0.alarmType == .chargeCheck }
        if let explicit = chargeRules.first { return explicit.isEnabled }
        return app.settings.chargeCheckEnabled   // 全体デフォルトに従う
    }

    // MARK: オプトアウト

    private var optOutSection: some View {
        Section {
            Toggle(isOn: $optedOut) {
                Label("この予定だけアラーム不要", systemImage: "bell.slash")
            }
            .tint(Theme.warning)
            .onChange(of: optedOut) { _, newValue in
                Task { await app.setEventOptOut(event: event, optedOut: newValue) }
            }
        } footer: {
            Text("ONにすると、この予定に対する全てのアラームを鳴らしません。")
        }
    }
}

// MARK: - アラーム追加シート

struct AddAlarmSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let event: CalendarEvent
    let type: AlarmType

    enum Mode: String, CaseIterable, Identifiable { case absolute = "時刻指定", relative = "開始前"; var id: String { rawValue } }
    @State private var mode: Mode = .absolute
    @State private var hour: Int = 7
    @State private var minute: Int = 0
    @State private var relativeMinutes: Int = 15

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(type.title, systemImage: type.symbolName)
                        .foregroundStyle(Theme.color(for: type))
                }
                if supportsRelative {
                    Picker("方式", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .absolute || !supportsRelative {
                    TimePickerRow(title: timeLabel, hour: $hour, minute: $minute)
                } else {
                    Picker("開始前", selection: $relativeMinutes) {
                        ForEach([5, 10, 15, 30, 45, 60, 90, 120], id: \.self) {
                            Text("\($0)分前").tag($0)
                        }
                    }
                }
            }
            .navigationTitle("\(type.title)を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { save() }
                }
            }
            .onAppear(perform: applyDefaults)
        }
    }

    private var supportsRelative: Bool {
        type == .departure || type == .eventReminder || type == .wakeUp
    }

    private var timeLabel: String {
        switch type {
        case .previousDayCheck: return "前日の時刻"
        default: return "当日の時刻"
        }
    }

    private func applyDefaults() {
        switch type {
        case .wakeUp:           hour = app.settings.defaultWakeHour; minute = app.settings.defaultWakeMinute
        case .previousDayCheck: hour = app.settings.defaultPrevCheckHour; minute = app.settings.defaultPrevCheckMinute
        case .departure:        hour = 8; minute = 30; mode = .relative; relativeMinutes = 60
        case .eventReminder:    mode = .relative; relativeMinutes = 15
        default:                hour = 7; minute = 0
        }
    }

    private func save() {
        Task {
            if mode == .relative && supportsRelative {
                await app.addEventAlarm(event: event, type: type, timeType: .relativeToEvent,
                                        relativeMinutes: relativeMinutes)
            } else {
                await app.addEventAlarm(event: event, type: type, timeType: .absolute,
                                        hour: hour, minute: minute)
            }
            dismiss()
        }
    }
}

// AlarmType をシートの item: に使えるよう Identifiable に。
extension AlarmType: Identifiable { var id: String { rawValue } }

#Preview {
    NavigationStack {
        EventDetailView(event: PreviewSupport.appModel().tomorrowEvents.first!)
            .environment(PreviewSupport.appModel())
    }
}
