//
//  RulesView.swift
//  MadaNeteru?
//
//  「ルール」タブの入口＝適用ルール。個別＞曜日＞デフォルトの優先順位を色バッジで
//  示し、曜日ルール／デフォルト設定への導線を持つ。iOS標準 List。
//

import SwiftUI

struct RulesView: View {
    @Environment(AppModel.self) private var app
    @State private var addDeparture = false

    private let shownTypes: [AlarmType] = [.wakeUp, .previousDayCheck, .chargeCheck]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    cameoRow(text: "どの設定から来たか、色でわかるよ！")
                }
                .listRowBackground(Color.clear)

                if let ev = app.representativeEvent {
                    Section {
                        ForEach(shownTypes, id: \.self) { type in
                            ruleRow(ev: ev, type: type)
                        }
                    } header: {
                        Text(subtitle(ev))
                    } footer: {
                        legend
                    }

                    Section {
                        Button {
                            addDeparture = true
                        } label: {
                            Label("出発アラームを追加", systemImage: "plus")
                        }
                        .tint(Theme.orange)
                    }
                    .sheet(isPresented: $addDeparture) {
                        AddAlarmSheet(event: ev, type: .departure).presentationDetents([.medium])
                    }
                } else {
                    Section {
                        Text("適用中の予定がありません").foregroundStyle(.secondary)
                    }
                }

                Section("ルールを編集") {
                    NavigationLink { WeekdayRulesView() } label: {
                        Label("曜日ごとのルール", systemImage: "calendar.day.timeline.left")
                    }
                    NavigationLink { DefaultSettingsView() } label: {
                        Label("全体のデフォルト設定", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .navigationTitle("アラームルール")
        }
    }

    private func subtitle(_ ev: CalendarEvent) -> String {
        "\(ev.title) \(AppDate.dateString(ev.startDateTime)) に適用中"
    }

    private func ruleRow(ev: CalendarEvent, type: AlarmType) -> some View {
        let applied = app.appliedAlarm(for: ev, type: type)
        return Toggle(isOn: binding(ev: ev, type: type)) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(label(for: type)).foregroundStyle(Theme.label)
                    if let a = applied {
                        Text(AppDate.timeString(a.fireDate)).fontWeight(.semibold).foregroundStyle(Theme.label)
                    }
                }
                if let a = applied {
                    SourceBadge(tier: app.tier(for: a))
                } else {
                    Text("オフ").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .tint(Theme.green)
    }

    private func label(for type: AlarmType) -> String {
        switch type {
        case .wakeUp:           return "起床"
        case .previousDayCheck: return "前日確認"
        case .chargeCheck:      return "充電確認"
        default:                return type.title
        }
    }

    private func binding(ev: CalendarEvent, type: AlarmType) -> Binding<Bool> {
        Binding(
            get: { app.appliedAlarm(for: ev, type: type) != nil },
            set: { v in app.setEventAlarmEnabled(event: ev, type: type, enabled: v) }
        )
    }

    private var legend: some View {
        HStack(spacing: 7) {
            SourceBadge(tier: .individual)
            Text("＞").foregroundStyle(.secondary)
            SourceBadge(tier: .weekday)
            Text("＞").foregroundStyle(.secondary)
            SourceBadge(tier: .defaults)
            Text("の順で優先")
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.top, 4)
    }

    private func cameoRow(text: String) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            CharacterView(character: .shiro, height: 116)
            SpeechBubble(tail: .leading, radius: 15) {
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.bubbleText)
            }
            .padding(.bottom, 18)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    RulesView().environment(PreviewSupport.appModel())
}
