//
//  EventsView.swift
//  MadaNeteru?
//
//  「予定」タブ。明日/今日/7日間 を標準セグメントで切替、iOS標準 List で一覧。
//  各行に適用中のアラームを色バッジで表示。
//

import SwiftUI

struct EventsView: View {
    @Environment(AppModel.self) private var app
    @State private var segment = 0   // 0:明日 1:今日 2:7日間

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("表示範囲", selection: $segment) {
                        Text("明日").tag(0); Text("今日").tag(1); Text("7日間").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listRowBackground(Color.clear)

                Section {
                    cameoRow
                }
                .listRowBackground(Color.clear)

                if timedEvents.isEmpty && allDayEvents.isEmpty {
                    Section {
                        ContentUnavailableView("予定はありません", systemImage: "moon.zzz.fill",
                                               description: Text("ゆっくり休みましょう。"))
                    }
                    .listRowBackground(Color.clear)
                } else {
                    if !timedEvents.isEmpty {
                        Section {
                            ForEach(timedEvents) { ev in
                                NavigationLink { EventDetailView(event: ev) } label: { EventRow(event: ev) }
                            }
                        }
                    }
                    if !allDayEvents.isEmpty {
                        Section("終日") {
                            ForEach(allDayEvents) { ev in Text(ev.title) }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .refreshable { await app.sync() }
        }
    }

    private var title: String {
        switch segment {
        case 1:  return "今日の予定"
        case 2:  return "今後7日間"
        default: return "明日の予定"
        }
    }

    private var sourceEvents: [CalendarEvent] {
        switch segment {
        case 1:  return app.todayEvents
        case 2:  return app.upcomingEvents
        default: return app.tomorrowEvents
        }
    }
    private var timedEvents: [CalendarEvent] { sourceEvents.filter { !$0.isAllDay } }
    private var allDayEvents: [CalendarEvent] { sourceEvents.filter { $0.isAllDay } }

    private var firstMissing: CalendarEvent? {
        timedEvents.first { app.appliedAlarm(for: $0, type: .wakeUp) == nil && !app.isEventOptedOut($0) }
    }

    private var cameoRow: some View {
        HStack(alignment: .bottom, spacing: 6) {
            CharacterView(character: .watami, height: 116)
            SpeechBubble(tail: .leading, radius: 16) {
                Text(cameoText).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.bubbleText)
            }
            .padding(.bottom, 18)
            Spacer(minLength: 0)
        }
    }

    private var cameoText: String {
        if let m = firstMissing {
            return "\(AppDate.timeString(m.startDateTime))の\(m.title)、アラームまだ無いよ？"
        }
        return "予定の準備、ばっちりだよ！"
    }
}

// MARK: - 予定の行（NavigationLink 内で標準シェブロンが付く）

private struct EventRow: View {
    @Environment(AppModel.self) private var app
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Text(AppDate.timeString(event.startDateTime))
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(optedOut ? .secondary : Color.primary)
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 14, weight: .semibold))
                if let loc = event.location, !loc.isEmpty {
                    Text(loc).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                badges.padding(.top, 7)
            }
        }
        .padding(.vertical, 4)
    }

    private var optedOut: Bool { app.isEventOptedOut(event) }
    private var wake: EffectiveAlarm? { app.appliedAlarm(for: event, type: .wakeUp) }
    private var departure: EffectiveAlarm? { app.appliedAlarm(for: event, type: .departure) }
    private var hasCharge: Bool { app.appliedAlarm(for: event, type: .chargeCheck) != nil }

    @ViewBuilder private var badges: some View {
        HStack(spacing: 5) {
            if optedOut {
                Badge(text: "アラーム不要", fg: Theme.secondary, bg: Color(hex: "EFEFF2"))
            } else if wake == nil {
                Badge(text: "⚠︎ アラーム未設定", fg: Theme.orange2, bg: Color(hex: "FFF1DD"))
            } else {
                if let w = wake { Badge(text: "起床 \(AppDate.timeString(w.fireDate))", fg: Theme.orange, bg: Color(hex: "FDEDE3")) }
                if let d = departure { Badge(text: "出発 \(AppDate.timeString(d.fireDate))", fg: Theme.orange2, bg: Color(hex: "FFF1DD")) }
                if hasCharge { Badge(text: "🔋 ON", fg: Theme.green, bg: Color(hex: "E3F8E9")) }
            }
        }
    }
}

private struct Badge: View {
    let text: String; let fg: Color; let bg: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(fg)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(bg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    EventsView().environment(PreviewSupport.appModel())
}
