//
//  MadaNeteru_App.swift
//  MadaNeteru?
//
//  エントリポイント。SwiftData コンテナと各サービスを 1 度だけ構築し、
//  AppModel を environment で配布する。
//

import SwiftUI
import SwiftData

@main
struct MadaNeteru_App: App {
    @State private var root = RootContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(root.appModel)
                .modelContainer(root.container)
        }
    }
}

/// アプリ全体で 1 つだけ生成する依存のまとまり。
@MainActor
final class RootContainer {
    let container: ModelContainer
    let appModel: AppModel

    init() {
        let schema = Schema([
            AppUser.self,
            CalendarEvent.self,
            AlarmRule.self,
            ScheduledAlarm.self,
            ChargeCheck.self,
            CalendarSyncState.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // 永続ストアが壊れている場合はメモリ上で起動して復帰可能にする。
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }

        let settings = SettingsStore()
        // GoogleConfig.clientID が設定済みなら実連携、未設定ならモックで動作。
        let calendarProvider: CalendarSyncService = GoogleConfig.isConfigured
            ? GoogleCalendarProvider(auth: GoogleAuthService())
            : MockCalendarProvider()

        appModel = AppModel(
            context: container.mainContext,
            settings: settings,
            calendar: calendarProvider,
            alarmScheduler: AlarmKitScheduler(),       // 実 AlarmKit
            notifications: NotificationService(),
            battery: BatteryMonitor()
        )

        // バックグラウンド更新ハンドラを登録（launch 完了前に必要）。
        BackgroundRefreshController.shared.configure(appModel: appModel)
    }
}
