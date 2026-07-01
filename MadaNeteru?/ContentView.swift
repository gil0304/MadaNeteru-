//
//  ContentView.swift
//  MadaNeteru?
//
//  ルート。オンボーディング未完ならオンボーディング、完了後はメインタブ。
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var didBootstrap = false

    var body: some View {
        Group {
            // ログイン済み かつ オンボーディング完了 のときだけメイン。
            // ログアウトすると isSignedIn=false になり、ここが再評価されてログインへ戻る。
            if app.isSignedIn && app.settings.onboardingCompleted {
                #if DEBUG
                if let screen = DemoLaunch.demoScreen {
                    demoGallery(screen)
                } else {
                    MainTabView()
                }
                #else
                MainTabView()
                #endif
            } else {
                OnboardingView()
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            await app.bootstrap()
            #if DEBUG
            // 開発用: `-demoMode` 起動でオンボーディングを飛ばしモックログイン+同期。
            if ProcessInfo.processInfo.arguments.contains("-demoMode") {
                app.settings.onboardingCompleted = true
                await app.loadDemoSeed()
                return
            }
            #endif
            if app.settings.onboardingCompleted, app.isSignedIn {
                await app.sync()   // 起動時同期（要件 6.4）
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // フォアグラウンド復帰で同期＋充電自動確認（要件 6.4 / 11.1）
                guard app.settings.onboardingCompleted else { return }
                app.battery.refresh()
                Task {
                    await app.autoStopChargeIfCharged()
                    if app.isSignedIn { await app.sync() }
                }
            case .background:
                // バックグラウンド更新を予約（要件 6.4）
                BackgroundRefreshController.shared.scheduleNext()
            default:
                break
            }
        }
    }

    #if DEBUG
    /// 開発時にプッシュ遷移先の画面を単体スクショ確認するためのギャラリー。
    @ViewBuilder
    private func demoGallery(_ screen: String) -> some View {
        switch screen {
        case "default": NavigationStack { DefaultSettingsView() }
        case "weekday": NavigationStack { WeekdayRulesView() }
        case "detail":
            if let ev = app.tomorrowEvents.first(where: { !$0.isAllDay }) {
                NavigationStack { EventDetailView(event: ev) }
            } else {
                ProgressView()
            }
        case "charge": AlarmRingingView(kind: .charge)
        case "wake": AlarmRingingView(kind: .wake)
        default: MainTabView()
        }
    }
    #endif
}

/// デザイン v4 の 3 タブ（ホーム / 予定 / ルール）。
struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @State private var selection = DemoLaunch.initialTab

    var body: some View {
        TabView(selection: $selection) {
            Tab("ホーム", systemImage: "house.fill", value: 0) {
                HomeView()
            }
            Tab("予定", systemImage: "calendar", value: 1) {
                EventsView()
            }
            Tab("ルール", systemImage: "alarm.fill", value: 2) {
                RulesView()
            }
        }
        .tint(Theme.orange)
    }
}

/// 開発時にスクリーンショット確認するための初期タブ指定（本番では常に 0）。
enum DemoLaunch {
    static func arg(_ flag: String) -> String? {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: flag), i + 1 < a.count { return a[i + 1] }
        #endif
        return nil
    }
    static var initialTab: Int { Int(arg("-demoTab") ?? "") ?? 0 }
    static var demoScreen: String? { arg("-demoScreen") }
    static var onboardStep: Int { Int(arg("-onboardStep") ?? "") ?? 0 }
}

// プレビュー用のインメモリ AppModel を供給。
#Preview {
    RootView()
        .environment(PreviewSupport.appModel())
}
