//
//  HomeView.swift
//  MadaNeteru?
//
//  要件 13.2。明日の予定件数・未設定件数・充電確認・次のアラーム・今夜の充電状態。
//

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WarningsBanner()

                    statsGrid
                    chargeCard

                    if !app.missingTomorrow.isEmpty {
                        missingSection
                    }

                    tomorrowPreview
                }
                .padding(16)
            }
            .navigationTitle("まだ寝てる?")
            .background(backgroundTint)
            .refreshable { await app.sync() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await app.sync() }
                    } label: {
                        if app.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(app.isSyncing)
                }
            }
        }
    }

    private var backgroundTint: some View {
        LinearGradient(colors: [Theme.night.opacity(0.08), .clear],
                       startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }

    // MARK: 統計

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "明日の予定", value: "\(app.tomorrowEventCount)件",
                     systemImage: "calendar", tint: Theme.night)
            StatCard(title: "アラーム未設定",
                     value: "\(app.missingTomorrowCount)件",
                     systemImage: "exclamationmark.triangle.fill",
                     tint: app.missingTomorrowCount > 0 ? Theme.warning : Theme.charge)
            StatCard(title: "充電確認",
                     value: app.tonightChargeTime.map { AppDate.timeString($0) } ?? "—",
                     systemImage: "battery.100.bolt", tint: Theme.charge)
            StatCard(title: "次のアラーム",
                     value: app.nextAlarmDate.map { AppDate.relativeString(to: $0) } ?? "なし",
                     systemImage: "alarm.fill", tint: Theme.accent)
        }
    }

    // MARK: 今夜の充電

    private var chargeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "今夜の充電確認", systemImage: "bolt.fill")
                Spacer()
                BatteryBadge(state: app.battery.state, level: app.battery.level)
            }

            if let time = app.tonightChargeTime {
                Text("明日の予定にそなえて、\(AppDate.timeString(time)) に充電を確認します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if app.tomorrowEventCount == 0 {
                Text("明日は対象の予定がないため、充電確認はありません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("充電確認はオフ、または設定待ちです。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let cc = app.tonightChargeCheck, cc.alarmDismissed {
                Label("対応済み（\(cc.userAction.label)）", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.charge)
            } else if app.tonightChargeTime != nil {
                HStack(spacing: 10) {
                    Button {
                        Task { await app.confirmCharged() }
                    } label: {
                        Label("充電した", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.charge)

                    Button("今日は不要") {
                        Task { await app.chargeNotNeededTonight() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .cardStyle()
    }

    // MARK: 未設定

    private var missingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "今日やるべき確認", systemImage: "checklist")
            ForEach(app.missingTomorrow) { event in
                MissingFixRow(event: event)
            }
        }
        .cardStyle()
    }

    // MARK: 明日の予定プレビュー

    private var tomorrowPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "明日の予定", systemImage: "calendar")
                Spacer()
                NavigationLink("すべて見る") { TomorrowEventsView() }
                    .font(.subheadline)
            }
            let events = app.tomorrowEvents.filter { !$0.isAllDay }
            if events.isEmpty {
                Text("明日の予定はありません。ゆっくり休みましょう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events.prefix(3)) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        EventRowView(
                            event: event,
                            appliedAlarms: app.effectiveAlarms(for: event),
                            isMissing: app.missingTomorrow.contains { $0.id == event.id }
                        )
                    }
                    .buttonStyle(.plain)
                    if event.id != events.prefix(3).last?.id { Divider() }
                }
            }
        }
        .cardStyle()
    }
}

/// 未設定予定に対するクイック操作（要件 10.3）。
struct MissingFixRow: View {
    @Environment(AppModel.self) private var app
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(AppDate.timeString(event.startDateTime))「\(event.title)」")
                .font(.subheadline.weight(.semibold))
            Text("起床アラームが未設定です")
                .font(.caption)
                .foregroundStyle(Theme.warning)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("7:00に設定") {
                        Task { await app.quickFixMissing(event: event, choice: .wakeAt(hour: 7, minute: 0)) }
                    }
                    Button("2時間前") {
                        Task { await app.quickFixMissing(event: event, choice: .relativeHours(2)) }
                    }
                    Button("明日は不要") {
                        Task { await app.quickFixMissing(event: event, choice: .notTomorrow) }
                    }
                    NavigationLink("詳細設定") { EventDetailView(event: event) }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView()
        .environment(PreviewSupport.appModel())
}
