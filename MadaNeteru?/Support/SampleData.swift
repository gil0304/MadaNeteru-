//
//  SampleData.swift
//  MadaNeteru?
//
//  プレビュー / デモ起動で使うサンプル予定。実Google同期とは無関係。
//

import Foundation

enum SampleData {
    static func events(userId: String) -> [CalendarEvent] {
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
            make("tmr-interview", "面接", at(1, 10, 0), at(1, 11, 0), location: "○○ビル 5F"),
            make("tmr-meeting", "打ち合わせ", at(1, 14, 0), at(1, 15, 0), location: "オンライン"),
            make("tmr-gym", "ジム", at(1, 19, 0), at(1, 20, 0), location: "駅前スタジオ"),
            make("tmr-trash", "資源ごみの日", at(1, 0, 0), at(2, 0, 0), allDay: true),
            make("d3-trip", "日帰り出張", at(3, 8, 0), at(3, 19, 0), location: "名古屋")
        ]
    }
}
