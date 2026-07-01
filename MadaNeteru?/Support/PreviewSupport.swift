//
//  PreviewSupport.swift
//  MadaNeteru?
//
//  SwiftUI プレビュー用に、インメモリ SwiftData + モックサービスで構成した
//  AppModel を生成する。サンプル予定も投入する。
//

import Foundation
import SwiftData
import SwiftUI

enum PreviewSupport {
    @MainActor
    static func appModel(signedIn: Bool = true, seedEvents: Bool = true) -> AppModel {
        let schema = Schema([
            AppUser.self, CalendarEvent.self, AlarmRule.self,
            ScheduledAlarm.self, ChargeCheck.self, CalendarSyncState.self
        ])
        let container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext

        let user = AppUser(
            googleAccountId: signedIn ? "preview-uid" : nil,
            email: signedIn ? "you@example.com" : "",
            name: signedIn ? "サンプルユーザー" : "",
            calendarSyncEnabled: signedIn
        )
        ctx.insert(user)

        if seedEvents {
            for e in SampleData.events(userId: user.id) { ctx.insert(e) }
        }
        try? ctx.save()

        let settings = SettingsStore()
        settings.onboardingCompleted = true

        let model = AppModel(
            context: ctx,
            settings: settings,
            calendar: MockCalendarProvider(),
            alarmScheduler: MockAlarmScheduler(),
            notifications: NotificationService(),
            battery: BatteryMonitor()
        )
        model.reloadEventsFromStore()
        return model
    }
}
