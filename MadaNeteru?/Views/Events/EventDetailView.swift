//
//  EventDetailView.swift
//  MadaNeteru?
//
//  予定詳細。個別アラーム設定（最優先で曜日・デフォルトを上書き）。iOS標準 List。
//

import SwiftUI

struct EventDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let event: CalendarEvent

    @State private var editType: AlarmType?
    @State private var optedOut = false

    private let editableTypes: [AlarmType] = [.wakeUp, .previousDayCheck, .chargeCheck, .departure]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.headline)
                    Text(dateRange).font(.subheadline).foregroundStyle(.secondary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section {
                cameoRow(text: "この予定、わたしが担当するね！")
            }
            .listRowBackground(Color.clear)

            if !optedOut {
                Section {
                    ForEach(appliedEditable, id: \.0) { type, alarm in
                        Button { editType = type } label: {
                            HStack(spacing: 12) {
                                AlarmTypeIcon(type: type, size: 28)
                                Text(type.title).foregroundStyle(Theme.label)
                                Spacer()
                                Text(AppDate.timeString(alarm.fireDate)).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.chevron)
                            }
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button("オフ", role: .destructive) {
                                app.setEventAlarmEnabled(event: event, type: type, enabled: false)
                            }
                        }
                    }
                    ForEach(addableTypes, id: \.self) { type in
                        Button { editType = type } label: {
                            Label("\(type.title)を追加", systemImage: "plus")
                        }
                        .tint(Theme.orange)
                    }
                } header: {
                    Text("この予定のアラーム")
                } footer: {
                    Text("時刻をタップで変更、左スワイプでこの予定だけオフにできます。")
                }
            }

            Section {
                Button(role: .destructive) {
                    optedOut.toggle()
                    app.setEventOptOut(event: event, optedOut: optedOut)
                } label: {
                    Text(optedOut ? "アラームを有効に戻す" : "この予定はアラーム不要にする")
                        .frame(maxWidth: .infinity)
                }
                .tint(optedOut ? Theme.orange : Theme.red)
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() } }
        }
        .onAppear { optedOut = app.isEventOptedOut(event) }
        .sheet(item: $editType) { type in
            AddAlarmSheet(event: event, type: type).presentationDetents([.medium])
        }
    }

    private var dateRange: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "M月d日(E) HH:mm"
        return "\(f.string(from: event.startDateTime)) – \(AppDate.timeString(event.endDateTime))"
    }
    private var subtitle: String {
        let cal = event.googleCalendarId == "primary" ? "予定" : (event.googleCalendarId == "work" ? "仕事" : event.googleCalendarId)
        if let loc = event.location, !loc.isEmpty { return "\(loc) ・ \(cal)カレンダー" }
        return "\(cal)カレンダー"
    }

    private var appliedEditable: [(AlarmType, EffectiveAlarm)] {
        editableTypes.compactMap { type in app.appliedAlarm(for: event, type: type).map { (type, $0) } }
    }
    private var addableTypes: [AlarmType] {
        editableTypes.filter { app.appliedAlarm(for: event, type: $0) == nil }
    }

    private func cameoRow(text: String) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            CharacterView(character: .aiueo, height: 112)
            SpeechBubble(tail: .leading, radius: 15) {
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.label)
            }
            .padding(.bottom, 18)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - アラーム追加/編集シート（iOS標準 Form）

struct AddAlarmSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let event: CalendarEvent
    let type: AlarmType

    enum Mode: String, CaseIterable, Identifiable { case absolute = "時刻指定", relative = "開始前"; var id: String { rawValue } }
    @State private var mode: Mode = .absolute
    @State private var time = Date()
    @State private var relativeMinutes = 15

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label { Text(type.title) } icon: { AlarmTypeIcon(type: type, size: 26) }
                }
                if supportsRelative {
                    Picker("方式", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if mode == .absolute || !supportsRelative {
                    DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                } else {
                    Picker("開始前", selection: $relativeMinutes) {
                        ForEach([5, 10, 15, 30, 45, 60, 90, 120], id: \.self) { Text("\($0)分前").tag($0) }
                    }
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("追加") { save() } }
            }
            .onAppear(perform: applyDefaults)
        }
    }

    private var supportsRelative: Bool { type == .departure || type == .eventReminder || type == .wakeUp }

    private func applyDefaults() {
        switch type {
        case .wakeUp:           time = AppDate.at(hour: app.settings.defaultWakeHour, minute: app.settings.defaultWakeMinute, on: .now)
        case .previousDayCheck: time = AppDate.at(hour: app.settings.defaultPrevCheckHour, minute: app.settings.defaultPrevCheckMinute, on: .now)
        case .chargeCheck:      time = AppDate.at(hour: app.settings.defaultChargeHour, minute: app.settings.defaultChargeMinute, on: .now)
        case .departure:        time = AppDate.at(hour: 8, minute: 30, on: .now); mode = .relative; relativeMinutes = 60
        case .eventReminder:    mode = .relative; relativeMinutes = 15
        default:                time = AppDate.at(hour: 7, minute: 0, on: .now)
        }
    }

    private func save() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        if mode == .relative && supportsRelative {
            app.addEventAlarm(event: event, type: type, timeType: .relativeToEvent, relativeMinutes: relativeMinutes)
        } else {
            app.addEventAlarm(event: event, type: type, timeType: .absolute, hour: c.hour ?? 7, minute: c.minute ?? 0)
        }
        dismiss()
    }
}

extension AlarmType: Identifiable { var id: String { rawValue } }

#Preview {
    NavigationStack {
        EventDetailView(event: PreviewSupport.appModel().tomorrowEvents.first!)
            .environment(PreviewSupport.appModel())
    }
}
