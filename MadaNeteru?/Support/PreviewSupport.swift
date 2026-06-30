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
            for e in sampleEvents(userId: user.id) { ctx.insert(e) }
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

    @MainActor
    private static func sampleEvents(userId: String) -> [CalendarEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func at(_ dayOffset: Int, _ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0,
                     of: cal.date(byAdding: .day, value: dayOffset, to: today)!)!
        }
        func make(_ id: String, _ title: String, _ start: Date, _ end: Date,
                  location: String? = nil, allDay: Bool = false) -> CalendarEvent {
            CalendarEvent(
                id: "primary|\(id)", userId: userId,
                googleCalendarId: "primary", googleEventId: id,
                title: title, location: location,
                startDateTime: start, endDateTime: end, isAllDay: allDay
            )
        }
        return [
            make("today-dentist", "歯医者", at(0, 18, 30), at(0, 19, 0), location: "渋谷"),
            make("tmr-interview", "面接", at(1, 10, 0), at(1, 11, 30), location: "品川オフィス 12F"),
            make("tmr-lunch", "ランチ（友人）", at(1, 13, 0), at(1, 14, 30), location: "表参道"),
            make("tmr-study", "オンライン勉強会", at(1, 20, 0), at(1, 21, 30), location: "オンライン"),
            make("d3-trip", "日帰り出張", at(3, 8, 0), at(3, 19, 0), location: "名古屋")
        ]
    }
}
