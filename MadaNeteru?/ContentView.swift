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
            if app.settings.onboardingCompleted {
                MainTabView()
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
                if app.isSignedIn { await app.sync() } else { await app.signInWithGoogle() }
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
}

/// 要件 13章の 4 つの主要画面をタブで束ねる。
struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @State private var selection = DemoLaunch.initialTab

    var body: some View {
        TabView(selection: $selection) {
            Tab("ホーム", systemImage: "house.fill", value: 0) {
                HomeView()
            }
            Tab("明日の予定", systemImage: "calendar", value: 1) {
                TomorrowEventsView()
            }
            Tab("設定", systemImage: "gearshape.fill", value: 2) {
                SettingsHubView()
            }
            Tab("履歴", systemImage: "clock.arrow.circlepath", value: 3) {
                AlarmHistoryView()
            }
        }
        .tint(Theme.accent)
    }
}

/// 開発時にスクリーンショット確認するための初期タブ指定（本番では常に 0）。
enum DemoLaunch {
    static var initialTab: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-demoTab"), i + 1 < args.count {
            return Int(args[i + 1]) ?? 0
        }
        #endif
        return 0
    }
}

// プレビュー用のインメモリ AppModel を供給。
#Preview {
    RootView()
        .environment(PreviewSupport.appModel())
}
