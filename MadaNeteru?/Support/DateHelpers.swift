//
//  DateHelpers.swift
//  MadaNeteru?
//
//  「明日」「前日夜」など、このアプリのドメインで多用する日付計算をまとめる。
//

import Foundation

enum AppDate {
    static var calendar: Calendar = {
        var cal = Calendar.current
        return cal
    }()

    /// 今日の 0:00。
    static func startOfToday(_ now: Date = .now) -> Date {
        calendar.startOfDay(for: now)
    }

    /// 明日の 0:00。
    static func startOfTomorrow(_ now: Date = .now) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfToday(now))!
    }

    /// n 日後の 0:00。
    static func startOfDay(daysFromNow n: Int, _ now: Date = .now) -> Date {
        calendar.date(byAdding: .day, value: n, to: startOfToday(now))!
    }

    /// 指定日の 0:00（時刻を切り捨て）。
    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// 同じ暦日か。
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// date が「今日から見た明日」か。
    static func isTomorrow(_ date: Date, now: Date = .now) -> Bool {
        isSameDay(date, startOfTomorrow(now))
    }

    /// 指定日の特定時刻（hour:minute）の Date を返す。
    static func at(hour: Int, minute: Int, on day: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    /// 「予定日の前日」の特定時刻。充電確認・前日確認に使う。
    static func previousDay(at hour: Int, minute: Int, of eventDay: Date) -> Date {
        let prev = calendar.date(byAdding: .day, value: -1, to: startOfDay(eventDay))!
        return at(hour: hour, minute: minute, on: prev)
    }

    // MARK: - 表示用フォーマッタ

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let weekdayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return f
    }()

    static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E) HH:mm"
        return f
    }()

    static func timeString(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func dateString(_ date: Date) -> String { weekdayDateFormatter.string(from: date) }
    static func dateTimeString(_ date: Date) -> String { dateTimeFormatter.string(from: date) }

    /// 「あと◯時間」「◯分後」などの相対表現。
    static func relativeString(to date: Date, from now: Date = .now) -> String {
        let interval = date.timeIntervalSince(now)
        if interval < 0 { return "経過" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "あと\(max(minutes, 1))分" }
        let hours = minutes / 60
        if hours < 24 { return "あと\(hours)時間" }
        return "あと\(hours / 24)日"
    }
}
