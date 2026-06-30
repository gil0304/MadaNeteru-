//
//  CalendarEvent.swift
//  MadaNeteru?
//
//  要件 6章・14章。Google カレンダーから取り込んだ予定。プライバシー要件
//  (17.2) に従い、タイトル・日時・場所など最小限のみ保持する。
//

import Foundation
import SwiftData

@Model
final class CalendarEvent {
    /// 端末内の安定 ID。googleEventId + calendarId から決定的に作る。
    @Attribute(.unique) var id: String

    var userId: String
    var googleCalendarId: String
    var googleEventId: String

    var title: String
    var eventDescription: String?
    var location: String?

    var startDateTime: Date
    var endDateTime: Date
    var isAllDay: Bool

    /// RFC 5545 RRULE（繰り返し）。MVP では表示用に保持するのみ。
    var recurrenceRule: String?
    /// "confirmed" / "tentative" / "cancelled"
    var status: String

    var lastSyncedAt: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        googleCalendarId: String,
        googleEventId: String,
        title: String,
        eventDescription: String? = nil,
        location: String? = nil,
        startDateTime: Date,
        endDateTime: Date,
        isAllDay: Bool = false,
        recurrenceRule: String? = nil,
        status: String = "confirmed"
    ) {
        self.id = id
        self.userId = userId
        self.googleCalendarId = googleCalendarId
        self.googleEventId = googleEventId
        self.title = title
        self.eventDescription = eventDescription
        self.location = location
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.isAllDay = isAllDay
        self.recurrenceRule = recurrenceRule
        self.status = status
        self.lastSyncedAt = .now
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// 起床/出発アラームの対象になり得る予定か（要件 10.2）。
    var isAlarmEligible: Bool {
        !isAllDay && status != "cancelled"
    }

    var startWeekday: Weekday { Weekday.of(startDateTime) }
}
