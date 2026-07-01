//
//  HomeView.swift
//  MadaNeteru?
//
//  ホーム。iOS標準 List をベースに、先頭にキャラのヒーローカード。
//  設定は標準ツールバーのギア。安全領域の小細工はせず堅牢に保つ。
//

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var ringing: AlarmRingKind?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    heroCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    if let wake = earliest(.wakeUp) {
                        Button { ringing = .wake } label: {
                            checkRow(done: true, title: "起床アラーム", trailing: AppDate.timeString(wake.fireDate))
                        }
                        .tint(.primary)
                    }
                    if let dep = earliest(.departure) {
                        checkRow(done: true, title: "出発アラーム", trailing: AppDate.timeString(dep.fireDate))
                    }
                    chargeRow
                } header: {
                    Text("今夜のチェック")
                } footer: {
                    Text("行をタップするとアラームの鳴動画面を確認できます。")
                }

                if app.missingTomorrowCount > 0, let first = app.missingTomorrow.first {
                    Section {
                        NavigationLink {
                            EventDetailView(event: first)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Theme.yellow).frame(width: 22, height: 22)
                                    Image(systemName: "exclamationmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                }
                                styledText([("アラーム未設定 ", nil), ("\(app.missingTomorrowCount)件", Theme.orange2)])
                                    .font(.system(size: 15))
                            }
                        }
                    }
                }
            }
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { DefaultSettingsView() } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .refreshable { await app.sync() }
            .fullScreenCover(item: $ringing) { kind in
                AlarmRingingView(kind: kind)
            }
        }
    }

    // MARK: ヒーローカード

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SpeechBubble(tail: .bottomLeading) {
                heroMessage
            }
            HStack(alignment: .bottom, spacing: 8) {
                CharacterView(character: .kamimu, height: 152, onDark: true)
                CharacterView(character: .honopi, height: 152, onDark: true)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.homeHero)
    }

    @ViewBuilder private var heroMessage: some View {
        let count = app.tomorrowEventCount
        if count == 0 {
            Text("明日は予定がないよ。\nゆっくり休んでね。")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Theme.bubbleText)
        } else if let ev = app.representativeEvent,
                  let wake = app.appliedAlarm(for: ev, type: .wakeUp) {
            styledText([
                ("明日は予定が ", nil),
                ("\(count)件", Theme.orange),
                ("！\n\(AppDate.timeString(ev.startDateTime))の\(ev.title)にあわせて、\n", nil),
                (AppDate.timeString(wake.fireDate), Theme.orange2),
                (" に起こすね。", nil)
            ])
            .font(.system(size: 13.5, weight: .bold))
            .foregroundStyle(Theme.bubbleText)
            .lineSpacing(3)
        } else {
            styledText([("明日は予定が ", nil), ("\(count)件", Theme.orange), ("！\nアラームの準備をするね。", nil)])
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Theme.bubbleText)
                .lineSpacing(3)
        }
    }

    // MARK: 今夜のチェック行

    private func checkRow(done: Bool, title: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22)).foregroundStyle(done ? Theme.green : Theme.chevron)
            Text(title)
            Spacer()
            Text(trailing).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var chargeRow: some View {
        let confirmed = app.tonightChargeCheck?.batteryState.isConfirmedCharged ?? false
        if confirmed {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.green)
                Text("充電を確認")
                Spacer()
                Text("充電済み").foregroundStyle(Theme.green)
            }
        } else if app.tonightChargeTime != nil {
            HStack(spacing: 12) {
                Image(systemName: "bolt.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.orange2)
                Text("充電を確認")
                Spacer()
                Button("確認する") { ringing = .charge }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Theme.orange2)
            }
        } else {
            checkRow(done: true, title: "充電確認", trailing: "予定なし")
        }
    }

    // MARK: 集計

    private func earliest(_ type: AlarmType) -> EffectiveAlarm? {
        app.tomorrowEvents.filter { !$0.isAllDay }
            .flatMap { app.effectiveAlarms(for: $0) }
            .filter { $0.alarmType == type }
            .min { $0.fireDate < $1.fireDate }
    }
}

#Preview {
    HomeView()
        .environment(PreviewSupport.appModel())
}
