//
//  AlarmPlanner.swift
//  MadaNeteru?
//
//  予定 + ルール + 全体デフォルトから「実際に鳴らす PlannedAlarm 群」を組み立てる。
//  要件 9（種別）・10（未設定警告）・11（充電確認）をまとめて計画する。純粋関数。
//
//  重複排除の方針:
//    起床 / 前日確認 / 充電確認 … 1 日（夜）あたり 1 件（最も早い時刻を採用）
//    出発 / 予定リマインド       … 予定ごと（各予定に対して 1 件）
//

import Foundation
import SwiftUI

struct AlarmPlan {
    var alarms: [PlannedAlarm]
    /// 充電確認を出した夜の一覧（ChargeCheck 永続化用）。eventDate=対象の予定日。
    var chargeNights: [(eventDate: Date, checkTime: Date)]
    /// 日付ごとの「起床アラーム未設定」予定（ホーム/予定画面の警告表示用）。
    var missingByDay: [Date: [CalendarEvent]]
}

enum AlarmPlanner {

    static func makePlan(
        events: [CalendarEvent],
        rules: [AlarmRule],
        globals: GlobalDefaults,
        missingCheck: TimeOfDay,
        now: Date = .now
    ) -> AlarmPlan {
        let eligible = events.filter { $0.isAlarmEligible }

        // 1. 各予定の有効アラームを解決
        let effective = eligible.flatMap {
            AlarmRuleResolver.effectiveAlarms(for: $0, rules: rules, globals: globals, now: now)
        }

        // 2. 種別ごとに重複排除
        let dayUnique: Set<AlarmType> = [.wakeUp, .previousDayCheck, .chargeCheck]
        var bestPerDay: [String: EffectiveAlarm] = [:]   // key: type|fireDay
        var perEvent: [EffectiveAlarm] = []
        for ea in effective {
            if dayUnique.contains(ea.alarmType) {
                let key = "\(ea.alarmType.rawValue)|\(Int(AppDate.startOfDay(ea.fireDate).timeIntervalSince1970))"
                if let existing = bestPerDay[key], existing.fireDate <= ea.fireDate { continue }
                bestPerDay[key] = ea
            } else {
                perEvent.append(ea)
            }
        }

        var alarms: [PlannedAlarm] = []
        var chargeNights: [(eventDate: Date, checkTime: Date)] = []

        let sortedBest = bestPerDay.values.sorted(by: { $0.fireDate < $1.fireDate })
        // 直近（今夜）の充電確認だけ「充電できるまで再通知」のチェーンに展開する。
        // 先の夜の分は単発（AlarmKit のアラーム数を抑える）。その夜が近づいて
        // 再構築が走ったタイミングで、直近分としてチェーン展開される。
        let nearestChargeID = sortedBest.first { $0.alarmType == .chargeCheck && $0.fireDate > now }?.id
        for ea in sortedBest {
            if ea.alarmType == .chargeCheck {
                if ea.id == nearestChargeID {
                    alarms.append(contentsOf: chargeChain(from: ea, globals: globals, now: now))
                } else {
                    alarms.append(planned(from: ea, globals: globals))
                }
                // 充電確認は前夜に鳴るので、対象の「予定日」は翌日。
                let night = AppDate.startOfDay(ea.fireDate)
                let eventDate = AppDate.calendar.date(byAdding: .day, value: 1, to: night)!
                chargeNights.append((eventDate: eventDate, checkTime: ea.fireDate))
            } else {
                alarms.append(planned(from: ea, globals: globals))
            }
        }
        for ea in perEvent.sorted(by: { $0.fireDate < $1.fireDate }) {
            alarms.append(planned(from: ea, globals: globals))
        }

        // 3. 未設定警告（要件 10）。対象日ごとに、前日の missingCheck 時刻で 1 件。
        var missingByDay: [Date: [CalendarEvent]] = [:]
        let days = Set(eligible.map { AppDate.startOfDay($0.startDateTime) })
        for day in days {
            let missing = AlarmRuleResolver.missingAlarmEvents(
                on: day, events: eligible, rules: rules, globals: globals
            )
            guard !missing.isEmpty else { continue }
            missingByDay[day] = missing

            let fire = AppDate.previousDay(at: missingCheck.hour, minute: missingCheck.minute, of: day)
            guard fire > now else { continue }
            let first = missing[0]
            let body = "明日 \(AppDate.timeString(first.startDateTime))「\(first.title)」"
                + (missing.count > 1 ? " ほか\(missing.count - 1)件" : "")
                + " に起床アラームがありません"
            alarms.append(PlannedAlarm(
                id: UUID(),
                alarmType: .missingAlarmWarning,
                title: "アラーム未設定",
                body: body,
                when: .fixed(fire),
                snoozeEnabled: false,
                snoozeIntervalMinutes: globals.snoozeIntervalMinutes,
                tintHex: Color.hex(for: .missingAlarmWarning),
                stopButtonText: "確認した",
                useAlarmKit: true,
                eventId: first.id,
                ruleId: "missing-\(Int(day.timeIntervalSince1970))",
                eventTitle: first.title
            ))
        }

        return AlarmPlan(alarms: alarms, chargeNights: chargeNights, missingByDay: missingByDay)
    }

    // MARK: - 充電確認「充電できるまで再通知」

    /// 充電確認の再通知間隔（分）。
    static let chargeRepeatIntervalMinutes = 15
    /// 充電確認を鳴らす総回数（初回含む）。0/15/30/45 分 → 最長 45 分。
    /// 充電を検知できたら AppModel 側で残りをまとめてキャンセルする。
    static let chargeRepeatMaxCount = 4

    /// 充電確認を一定間隔で繰り返す連続アラーム群を作る。
    /// 実体は個別の PlannedAlarm。充電が確認できた時点で AppModel が
    /// 未来の充電確認アラームを一括キャンセルするため、"充電するまで鳴り続ける"。
    private static func chargeChain(from ea: EffectiveAlarm, globals: GlobalDefaults, now: Date) -> [PlannedAlarm] {
        var chain: [PlannedAlarm] = []
        for i in 0..<chargeRepeatMaxCount {
            let fire = ea.fireDate.addingTimeInterval(TimeInterval(i * chargeRepeatIntervalMinutes * 60))
            guard fire > now else { continue }
            chain.append(planned(from: ea, globals: globals, fireDate: fire, repeatIndex: i))
        }
        return chain
    }

    /// アプリ内「15分後に再通知」ボタン用の、単発の充電確認アラーム。
    static func chargeSnooze(minutes: Int = chargeRepeatIntervalMinutes,
                             now: Date = .now,
                             globals: GlobalDefaults) -> PlannedAlarm {
        let ea = EffectiveAlarm(
            ruleId: "charge-snooze",
            eventId: nil,
            eventTitle: nil,
            alarmType: .chargeCheck,
            fireDate: now.addingTimeInterval(TimeInterval(minutes * 60)),
            snoozeEnabled: true,
            snoozeIntervalMinutes: chargeRepeatIntervalMinutes,
            useAlarmKit: true
        )
        return planned(from: ea, globals: globals, repeatIndex: 1)
    }

    // MARK: - 1 件の PlannedAlarm を作る

    private static func planned(from ea: EffectiveAlarm, globals: GlobalDefaults,
                                fireDate: Date? = nil, repeatIndex: Int = 0) -> PlannedAlarm {
        let type = ea.alarmType
        let fire = fireDate ?? ea.fireDate
        let eventTitle = ea.eventTitle ?? "予定"
        let title: String
        var body: String
        var stop = "止める"
        var snoozeInterval = ea.snoozeIntervalMinutes

        switch type {
        case .wakeUp:
            title = "起床アラーム"
            body = "明日「\(eventTitle)」の予定があります"
        case .previousDayCheck:
            title = "明日の予定確認"
            body = "明日「\(eventTitle)」の準備を確認しましょう"
        case .chargeCheck:
            title = "充電確認"
            body = "明日予定があります。スマホを充電してください。"
            stop = "充電した"
            snoozeInterval = chargeRepeatIntervalMinutes   // 要件 11.4「15分後に再通知」
        case .departure:
            title = "出発アラーム"
            body = "「\(eventTitle)」に間に合うように出発しましょう"
        case .eventReminder:
            title = "まもなく予定"
            body = "まもなく「\(eventTitle)」が始まります"
        case .missingAlarmWarning:
            title = "アラーム未設定"
            body = eventTitle
        }
        // 2 回目以降の充電確認は「まだ充電できてない」旨に変える。
        if type == .chargeCheck, repeatIndex > 0 {
            body = "まだ充電できてないみたい。今すぐ充電してね！"
        }

        return PlannedAlarm(
            id: UUID(),
            alarmType: type,
            title: title,
            body: body,
            when: .fixed(fire),
            snoozeEnabled: ea.snoozeEnabled && type != .missingAlarmWarning,
            snoozeIntervalMinutes: snoozeInterval,
            tintHex: Color.hex(for: type),
            stopButtonText: stop,
            useAlarmKit: ea.useAlarmKit,
            eventId: ea.eventId,
            ruleId: repeatIndex == 0 ? ea.ruleId : "\(ea.ruleId)#\(repeatIndex)",
            eventTitle: ea.eventTitle
        )
    }
}
