//
//  TomorrowEventsView.swift
//  MadaNeteru?
//
//  要件 13.3。明日の予定一覧（予定名・時刻・場所・適用中のアラーム・
//  充電確認の有無・未設定警告）。
//

import SwiftUI

struct TomorrowEventsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerSummary
                }

                if timedEvents.isEmpty && allDayEvents.isEmpty {
                    ContentUnavailableView(
                        "明日の予定はありません",
                        systemImage: "moon.zzz.fill",
                        description: Text("ゆっくり休みましょう。")
                    )
                } else {
                    if !timedEvents.isEmpty {
                        Section("予定") {
                            ForEach(timedEvents) { event in
                                NavigationLink {
                                    EventDetailView(event: event)
                                } label: {
                                    EventRowView(
                                        event: event,
                                        appliedAlarms: app.effectiveAlarms(for: event),
                                        isMissing: isMissing(event)
                                    )
                                }
                            }
                        }
                    }
                    if !allDayEvents.isEmpty {
                        Section("終日") {
                            ForEach(allDayEvents) { event in
                                Text(event.title).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("明日の予定")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await app.sync() }
        }
    }

    private var timedEvents: [CalendarEvent] {
        app.tomorrowEvents.filter { !$0.isAllDay }
    }
    private var allDayEvents: [CalendarEvent] {
        app.tomorrowEvents.filter { $0.isAllDay }
    }
    private func isMissing(_ event: CalendarEvent) -> Bool {
        app.missingTomorrow.contains { $0.id == event.id }
    }

    private var headerSummary: some View {
        HStack {
            Label("\(AppDate.dateString(AppDate.startOfTomorrow()))", systemImage: "calendar")
            Spacer()
            Text("\(timedEvents.count)件")
                .foregroundStyle(.secondary)
            if app.missingTomorrowCount > 0 {
                Label("\(app.missingTomorrowCount)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warning)
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
            }
        }
    }
}

#Preview {
    TomorrowEventsView()
        .environment(PreviewSupport.appModel())
}
