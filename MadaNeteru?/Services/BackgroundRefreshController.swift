//
//  BackgroundRefreshController.swift
//  MadaNeteru?
//
//  要件 6.4 / 10.2 / 11.1。BGTaskScheduler で定期バックグラウンド更新を行う。
//  起動していない間も、システムが許す範囲でカレンダー同期・アラーム再構築・
//  充電状態の自動確認を実行する。
//
//  ※ Info.plist に以下が必要:
//     UIBackgroundModes = [fetch, processing]
//     BGTaskSchedulerPermittedIdentifiers = [app.Ochiai.gil.MadaNeteru.refresh]
//

import Foundation
import BackgroundTasks

/// BGTask を @Sendable クロージャ越しに安全に運ぶための入れ物（MainActor でのみ触る）。
private final class BGTaskBox: @unchecked Sendable {
    let task: BGTask
    init(_ task: BGTask) { self.task = task }
}

@MainActor
final class BackgroundRefreshController {
    static let shared = BackgroundRefreshController()
    static let refreshIdentifier = "app.Ochiai.gil.MadaNeteru.refresh"

    private weak var appModel: AppModel?
    private var registered = false

    private init() {}

    /// アプリ起動時に 1 度だけ呼ぶ（ハンドラ登録は launch 完了前に必要）。
    func configure(appModel: AppModel) {
        self.appModel = appModel
        guard !registered else { return }
        registered = true
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier, using: .main
        ) { task in
            // using:.main なので main 上で呼ばれる。
            MainActor.assumeIsolated {
                BackgroundRefreshController.shared.handle(task)
            }
        }
    }

    private func handle(_ task: BGTask) {
        scheduleNext()                       // 次回分を予約しておく
        let model = appModel
        let box = BGTaskBox(task)
        task.expirationHandler = { box.task.setTaskCompleted(success: false) }
        Task { @MainActor in
            await model?.backgroundRefresh()
            box.task.setTaskCompleted(success: true)
        }
    }

    /// 次のバックグラウンド更新を予約。アプリのバックグラウンド遷移時にも呼ぶ。
    func scheduleNext(after interval: TimeInterval = 2 * 60 * 60) {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }
}
