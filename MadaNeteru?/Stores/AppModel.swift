//
//  AppModel.swift
//  MadaNeteru?
//
//  アプリ全体のコーディネータ。SwiftData・各サービス・AlarmPlanner を束ね、
//  画面はこの 1 オブジェクトだけを見る。要件 15章の各フローを実装する。
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppModel {
    // 依存
    let context: ModelContext
    let settings: SettingsStore
    let calendar: CalendarSyncService
    let alarmScheduler: AlarmScheduling
    let notifications: NotificationService
    let battery: BatteryMonitor

    // 状態（画面が参照）
    private(set) var user: AppUser?
    private(set) var todayEvents: [CalendarEvent] = []
    private(set) var tomorrowEvents: [CalendarEvent] = []
    private(set) var upcomingEvents: [CalendarEvent] = []
    private(set) var missingTomorrow: [CalendarEvent] = []

    private(set) var tonightChargeTime: Date?
    private(set) var nextAlarmDate: Date?
    private(set) var nextAlarmTitle: String?
    private(set) var scheduledCount: Int = 0

    var alarmAuth: AuthStatus = .notDetermined
    var notifAuth: AuthStatus = .notDetermined

    var isSyncing = false
    var lastSyncedAt: Date?
    /// 失敗・注意の通知（要件 17.1）。
    var warnings: [String] = []

    init(
        context: ModelContext,
        settings: SettingsStore,
        calendar: CalendarSyncService,
        alarmScheduler: AlarmScheduling,
        notifications: NotificationService,
        battery: BatteryMonitor
    ) {
        self.context = context
        self.settings = settings
        self.calendar = calendar
        self.alarmScheduler = alarmScheduler
        self.notifications = notifications
        self.battery = battery
    }

    var userId: String { user?.id ?? "local-user" }

    // MARK: - 全体デフォルト → GlobalDefaults

    var globalDefaults: GlobalDefaults {
        GlobalDefaults(
            wake: settings.defaultWakeEnabled
                ? TimeOfDay(hour: settings.defaultWakeHour, minute: settings.defaultWakeMinute) : nil,
            previousDayCheck: settings.defaultPrevCheckEnabled
                ? TimeOfDay(hour: settings.defaultPrevCheckHour, minute: settings.defaultPrevCheckMinute) : nil,
            charge: TimeOfDay(hour: settings.defaultChargeHour, minute: settings.defaultChargeMinute),
            departure: nil,
            reminderMinutesBefore: settings.defaultReminderEnabled ? settings.defaultReminderMinutesBefore : nil,
            snoozeIntervalMinutes: settings.snoozeIntervalMinutes,
            snoozeEnabled: true,
            chargeEnabled: settings.chargeCheckEnabled
        )
    }

    // MARK: - 起動

    func bootstrap() async {
        loadOrCreateUser()
        await refreshAuthStates()
        battery.refresh()
        reloadEventsFromStore()
        recomputeSummary()
    }

    private func loadOrCreateUser() {
        let descriptor = FetchDescriptor<AppUser>()
        if let existing = try? context.fetch(descriptor).first {
            user = existing
        } else {
            let u = AppUser()
            context.insert(u)
            user = u
            try? context.save()
        }
    }

    func refreshAuthStates() async {
        alarmAuth = await alarmScheduler.authorizationState
        notifAuth = await notifications.authorizationStatus()
        if let user {
            user.alarmKitAuthorizationStatus = alarmAuth
            user.notificationAuthorizationStatus = notifAuth
            try? context.save()
        }
    }

    // MARK: - 権限（要件 9.3 / 15.1）

    func requestAlarmAuthorization() async {
        alarmAuth = await alarmScheduler.requestAuthorization()
        await persistAuth()
    }

    func requestNotificationAuthorization() async {
        notifAuth = await notifications.requestAuthorization()
        await persistAuth()
    }

    private func persistAuth() async {
        user?.alarmKitAuthorizationStatus = alarmAuth
        user?.notificationAuthorizationStatus = notifAuth
        try? context.save()
    }

    // MARK: - Google ログイン（要件 6 / 15.1）

    func signInWithGoogle() async {
        do {
            let account = try await calendar.signIn()
            if let user {
                user.googleAccountId = account.id
                user.email = account.email
                user.name = account.name
                user.calendarSyncEnabled = true
                user.updatedAt = .now
                try? context.save()
            }
            await sync()
        } catch {
            warnings.append("Google ログインに失敗しました: \(error.localizedDescription)")
        }
    }

    func signOut() async {
        await calendar.signOut()
        user?.googleAccountId = nil
        user?.calendarSyncEnabled = false
        try? context.save()
    }

    var isSignedIn: Bool { user?.isSignedIn ?? false }

    // MARK: - 同期（要件 6.3 / 6.4 / 17.1）

    func sync() async {
        guard isSignedIn else { return }
        isSyncing = true
        defer { isSyncing = false }

        let timeMin = AppDate.startOfToday()
        let timeMax = AppDate.startOfDay(daysFromNow: 8)

        do {
            let calendars = try await calendar.calendars()
            // 所有カレンダー以外（以前同期した他人/購読カレンダー）の予定を掃除。
            // 一覧が空（取得失敗の可能性）の時は誤って全消ししない。
            if !calendars.isEmpty {
                purgeEvents(keeping: Set(calendars.map(\.id)))
            }
            for cal in calendars {
                let state = syncState(for: cal.id)
                let result = try await calendar.fetchEvents(
                    calendarId: cal.id,
                    syncToken: state.syncToken,
                    timeMin: timeMin,
                    timeMax: timeMax
                )
                upsert(result.events, calendarId: cal.id)
                for deleted in result.deletedEventIds {
                    deleteEvent(googleEventId: deleted, calendarId: cal.id)
                }
                state.syncToken = result.nextSyncToken
                state.lastSyncedAt = .now
                state.updatedAt = .now
            }
            try? context.save()
            lastSyncedAt = .now
            reloadEventsFromStore()
            await rebuildAlarms()
        } catch {
            // 失敗時は前回同期データを使う（要件 17.1）。警告のみ。
            warnings.append("カレンダー同期に失敗しました。前回のデータを表示します。")
            reloadEventsFromStore()
            recomputeSummary()
        }
    }

    private func syncState(for calendarId: String) -> CalendarSyncState {
        let uid = userId
        let descriptor = FetchDescriptor<CalendarSyncState>(
            predicate: #Predicate { $0.userId == uid && $0.googleCalendarId == calendarId }
        )
        if let existing = try? context.fetch(descriptor).first { return existing }
        let s = CalendarSyncState(userId: uid, googleCalendarId: calendarId)
        context.insert(s)
        return s
    }

    private func upsert(_ remotes: [RemoteEvent], calendarId: String) {
        for r in remotes {
            let stableId = "\(calendarId)|\(r.id)"
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.id == stableId }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.title = r.title
                existing.eventDescription = r.description
                existing.location = r.location
                existing.startDateTime = r.start
                existing.endDateTime = r.end
                existing.isAllDay = r.isAllDay
                existing.recurrenceRule = r.recurrenceRule
                existing.status = r.status
                existing.lastSyncedAt = .now
                existing.updatedAt = .now
            } else {
                let event = CalendarEvent(
                    id: stableId,
                    userId: userId,
                    googleCalendarId: calendarId,
                    googleEventId: r.id,
                    title: r.title,
                    eventDescription: r.description,
                    location: r.location,
                    startDateTime: r.start,
                    endDateTime: r.end,
                    isAllDay: r.isAllDay,
                    recurrenceRule: r.recurrenceRule,
                    status: r.status
                )
                context.insert(event)
            }
        }
    }

    /// 指定したカレンダーID群に属さない予定を全削除する（所有外カレンダーの掃除）。
    private func purgeEvents(keeping calendarIds: Set<String>) {
        let all = (try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        for event in all where !calendarIds.contains(event.googleCalendarId) {
            context.delete(event)
        }
    }

    private func deleteEvent(googleEventId: String, calendarId: String) {
        let stableId = "\(calendarId)|\(googleEventId)"
        let descriptor = FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.id == stableId })
        if let event = try? context.fetch(descriptor).first {
            context.delete(event)
        }
    }

    // MARK: - 取得・集計

    func reloadEventsFromStore() {
        let start = AppDate.startOfToday()
        let end = AppDate.startOfDay(daysFromNow: 8)
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.startDateTime >= start && $0.startDateTime < end },
            sortBy: [SortDescriptor(\.startDateTime)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        upcomingEvents = all
        todayEvents = all.filter { AppDate.isSameDay($0.startDateTime, AppDate.startOfToday()) }
        tomorrowEvents = all.filter { AppDate.isTomorrow($0.startDateTime) }
        missingTomorrow = AlarmRuleResolver.missingAlarmEvents(
            on: AppDate.startOfTomorrow(), events: all, rules: allRules(), globals: globalDefaults
        )
    }

    func allRules() -> [AlarmRule] {
        let descriptor = FetchDescriptor<AlarmRule>()
        return (try? context.fetch(descriptor)) ?? []
    }

    func rules(forEvent eventId: String) -> [AlarmRule] {
        allRules().filter { $0.targetType == .event && $0.targetId == eventId }
    }

    func effectiveAlarms(for event: CalendarEvent) -> [EffectiveAlarm] {
        AlarmRuleResolver.effectiveAlarms(
            for: event, rules: allRules(), globals: globalDefaults, now: .distantPast
        )
    }

    private func recomputeSummary() {
        // 次のアラーム
        let actives = activeScheduledAlarms()
        let future = actives.filter { $0.scheduledAt > .now }.sorted { $0.scheduledAt < $1.scheduledAt }
        nextAlarmDate = future.first?.scheduledAt
        nextAlarmTitle = future.first?.title
        scheduledCount = future.count

        // 今夜の充電確認
        tonightChargeTime = future.first(where: { $0.alarmType == .chargeCheck })?.scheduledAt
            ?? actives.first(where: { $0.alarmType == .chargeCheck && $0.scheduledAt > .now })?.scheduledAt
    }

    var tomorrowEventCount: Int { tomorrowEvents.filter { !$0.isAllDay }.count }
    var missingTomorrowCount: Int { missingTomorrow.count }

    // MARK: - アラーム再構築（要件 15.2 / 15.3）

    /// 既存のスケジュールを全キャンセルし、現在の予定+ルールから作り直す。
    func rebuildAlarms() async {
        // 1. 既存を取り消し
        for sa in activeScheduledAlarms() {
            if let idStr = sa.alarmKitAlarmId, let uuid = UUID(uuidString: idStr) {
                if sa.usedAlarmKit { await alarmScheduler.cancel(id: uuid) }
                else { notifications.cancel(id: uuid) }
            }
            sa.status = .cancelled
            sa.updatedAt = .now
        }

        // 2. 計画
        let plan = AlarmPlanner.makePlan(
            events: upcomingEvents,
            rules: allRules(),
            globals: globalDefaults,
            missingCheck: TimeOfDay(hour: settings.missingCheckHour, minute: settings.missingCheckMinute)
        )

        let canUseAlarmKit = settings.useAlarmKit && alarmAuth == .authorized

        // 3. スケジュール + 永続化
        for planned in plan.alarms {
            let viaAlarmKit = planned.useAlarmKit && canUseAlarmKit
            var scheduledOK = true
            do {
                if viaAlarmKit {
                    try await alarmScheduler.schedule(planned)
                } else {
                    try await notifications.schedule(planned)
                }
            } catch {
                scheduledOK = false
                warnings.append("「\(planned.title)」のアラーム作成に失敗しました")
                // フォールバック: 通常通知（要件 17.1）
                try? await notifications.schedule(planned)
            }
            let record = ScheduledAlarm(
                userId: userId,
                eventId: planned.eventId,
                alarmRuleId: planned.ruleId,
                alarmKitAlarmId: planned.id.uuidString,
                alarmType: planned.alarmType,
                title: planned.title,
                eventTitle: planned.eventTitle,
                scheduledAt: planned.fireDate ?? .now,
                status: scheduledOK ? .scheduled : .failed,
                usedAlarmKit: viaAlarmKit && scheduledOK
            )
            context.insert(record)
        }

        // 4. 充電確認の記録（要件 11）
        for night in plan.chargeNights {
            recordChargeCheck(eventDate: night.eventDate, checkTime: night.checkTime)
        }

        try? context.save()
        recomputeSummary()
    }

    func activeScheduledAlarms() -> [ScheduledAlarm] {
        let descriptor = FetchDescriptor<ScheduledAlarm>(
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.isActive }
    }

    // MARK: - 充電確認（要件 11）

    private func recordChargeCheck(eventDate: Date, checkTime: Date) {
        let uid = userId
        let day = AppDate.startOfDay(eventDate)
        let next = AppDate.calendar.date(byAdding: .day, value: 1, to: day)!
        let descriptor = FetchDescriptor<ChargeCheck>(
            predicate: #Predicate { $0.userId == uid && $0.eventDate >= day && $0.eventDate < next }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.checkTime = checkTime
            existing.alarmScheduled = true
            existing.updatedAt = .now
        } else {
            let cc = ChargeCheck(
                userId: uid, eventDate: day, checkTime: checkTime,
                batteryState: .notChecked, alarmScheduled: true
            )
            context.insert(cc)
        }
    }

    /// 「充電した」: 充電状態を確認し、充電済みなら今夜の充電アラームを止める（要件 11.3/11.4）。
    func confirmCharged() async {
        battery.refresh()
        let state = battery.state
        let level = battery.level
        updateTonightChargeCheck { cc in
            cc.batteryState = state
            cc.batteryLevel = level
            cc.confirmedCharging = state.isConfirmedCharged
            cc.userAction = .charged
            cc.alarmDismissed = state.isConfirmedCharged
        }
        // 充電済みと確認できた時だけ、今夜の充電アラームを停止。
        if state.isConfirmedCharged {
            await cancelTonightChargeAlarm()
        } else {
            warnings.append("まだ充電が確認できません（\(state.label)）。充電を開始してください。")
        }
    }

    func chargeNotNeededTonight() async {
        updateTonightChargeCheck { cc in
            cc.userAction = .notNeeded
            cc.alarmDismissed = true
        }
        await cancelTonightChargeAlarm()
    }

    private func cancelTonightChargeAlarm() async {
        for sa in activeScheduledAlarms() where sa.alarmType == .chargeCheck {
            if let idStr = sa.alarmKitAlarmId, let uuid = UUID(uuidString: idStr) {
                if sa.usedAlarmKit { await alarmScheduler.cancel(id: uuid) }
                else { notifications.cancel(id: uuid) }
            }
            sa.status = .dismissed
            sa.dismissedAt = .now
            sa.chargeConfirmed = true
        }
        try? context.save()
        recomputeSummary()
    }

    private func updateTonightChargeCheck(_ mutate: (ChargeCheck) -> Void) {
        let uid = userId
        let tomorrow = AppDate.startOfTomorrow()
        let next = AppDate.startOfDay(daysFromNow: 2)
        let descriptor = FetchDescriptor<ChargeCheck>(
            predicate: #Predicate { $0.userId == uid && $0.eventDate >= tomorrow && $0.eventDate < next }
        )
        let cc: ChargeCheck
        if let existing = try? context.fetch(descriptor).first {
            cc = existing
        } else {
            cc = ChargeCheck(userId: uid, eventDate: tomorrow, checkTime: .now)
            context.insert(cc)
        }
        mutate(cc)
        cc.updatedAt = .now
        try? context.save()
    }

    var tonightChargeCheck: ChargeCheck? {
        let uid = userId
        let tomorrow = AppDate.startOfTomorrow()
        let next = AppDate.startOfDay(daysFromNow: 2)
        let descriptor = FetchDescriptor<ChargeCheck>(
            predicate: #Predicate { $0.userId == uid && $0.eventDate >= tomorrow && $0.eventDate < next }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - 予定ごとの設定（要件 13.4 / 15.3）

    func addEventAlarm(
        event: CalendarEvent,
        type: AlarmType,
        timeType: AlarmTimeType,
        hour: Int? = nil,
        minute: Int? = nil,
        relativeMinutes: Int? = nil
    ) async {
        let rule = AlarmRule(
            userId: userId,
            targetType: .event,
            targetId: event.id,
            alarmType: type,
            alarmTimeType: timeType,
            alarmHour: hour,
            alarmMinute: minute,
            relativeMinutes: relativeMinutes,
            snoozeEnabled: true,
            snoozeIntervalMinutes: settings.snoozeIntervalMinutes
        )
        context.insert(rule)
        try? context.save()
        await afterRuleChange()
    }

    func setEventChargeCheck(event: CalendarEvent, enabled: Bool) async {
        // 既存の event スコープ charge ルールを掃除してから設定。
        for r in rules(forEvent: event.id) where r.alarmType == .chargeCheck {
            context.delete(r)
        }
        if enabled {
            // 全体の充電時刻で明示 ON。
            let rule = AlarmRule(
                userId: userId, targetType: .event, targetId: event.id,
                alarmType: .chargeCheck, alarmTimeType: .absolute,
                alarmHour: settings.defaultChargeHour, alarmMinute: settings.defaultChargeMinute,
                snoozeEnabled: true, snoozeIntervalMinutes: 15
            )
            context.insert(rule)
        } else {
            // 明示 OFF（無効ルールで下位を抑制）。
            let rule = AlarmRule(
                userId: userId, targetType: .event, targetId: event.id,
                alarmType: .chargeCheck, alarmTimeType: .absolute,
                alarmHour: settings.defaultChargeHour, alarmMinute: settings.defaultChargeMinute,
                isEnabled: false
            )
            context.insert(rule)
        }
        try? context.save()
        await afterRuleChange()
    }

    /// 「この予定だけアラーム不要にする」: 全種別を無効ルールで抑制。
    func setEventOptOut(event: CalendarEvent, optedOut: Bool) async {
        let types: [AlarmType] = [.wakeUp, .previousDayCheck, .chargeCheck, .departure, .eventReminder]
        // いったん既存の event ルールを削除
        for r in rules(forEvent: event.id) { context.delete(r) }
        if optedOut {
            for t in types {
                let rule = AlarmRule(
                    userId: userId, targetType: .event, targetId: event.id,
                    alarmType: t, alarmTimeType: .absolute,
                    alarmHour: 0, alarmMinute: 0, isEnabled: false
                )
                context.insert(rule)
            }
        }
        try? context.save()
        await afterRuleChange()
    }

    func isEventOptedOut(_ event: CalendarEvent) -> Bool {
        let eventRules = rules(forEvent: event.id)
        guard !eventRules.isEmpty else { return false }
        return eventRules.filter { !$0.isEnabled }.count >= 5
    }

    func removeRule(_ rule: AlarmRule) async {
        context.delete(rule)
        try? context.save()
        await afterRuleChange()
    }

    /// 未設定警告の操作（要件 10.3）。
    func quickFixMissing(event: CalendarEvent, choice: MissingFixChoice) async {
        switch choice {
        case .wakeAt(let h, let m):
            await addEventAlarm(event: event, type: .wakeUp, timeType: .absolute, hour: h, minute: m)
        case .relativeHours(let hours):
            await addEventAlarm(event: event, type: .wakeUp, timeType: .relativeToEvent,
                                relativeMinutes: hours * 60)
        case .notTomorrow:
            await setEventOptOut(event: event, optedOut: true)
        }
    }

    private func afterRuleChange() async {
        reloadEventsFromStore()
        await rebuildAlarms()
    }

    /// 全体デフォルト等の設定変更後に、予定の再評価とアラーム再構築を行う。
    func refreshAfterSettingsChange() async {
        await afterRuleChange()
    }

    // MARK: - バックグラウンド更新（要件 6.4 / 10.2 / 11.1）

    /// バックグラウンドで同期・アラーム再構築・充電自動確認をまとめて行う。
    func backgroundRefresh() async {
        battery.refresh()
        await refreshAuthStates()
        if isSignedIn {
            await sync()                 // 同期 → 予定再読込 → アラーム再構築（未設定再評価込み）
        } else {
            reloadEventsFromStore()
            await rebuildAlarms()
        }
        await autoStopChargeIfCharged()
    }

    /// 充電中/満充電と確認できたら、今夜の充電確認アラームを自動で止める（要件 11.1）。
    /// フォアグラウンド復帰時にも呼ぶ。
    func autoStopChargeIfCharged() async {
        battery.refresh()
        guard battery.isConfirmedCharged else { return }
        let hasPendingCharge = activeScheduledAlarms().contains {
            $0.alarmType == .chargeCheck && $0.scheduledAt > .now
        }
        guard hasPendingCharge else { return }

        let state = battery.state
        let level = battery.level
        updateTonightChargeCheck { cc in
            cc.batteryState = state
            cc.batteryLevel = level
            cc.confirmedCharging = true
            cc.alarmDismissed = true
            cc.userAction = .charged
        }
        await cancelTonightChargeAlarm()
    }

    // MARK: - 曜日ルール（要件 13.5）

    func weekdayRules(_ weekday: Weekday) -> [AlarmRule] {
        allRules().filter { $0.targetType == .weekday && $0.targetId == String(weekday.rawValue) }
    }

    func setWeekdayRule(
        weekday: Weekday, type: AlarmType, enabled: Bool, hour: Int, minute: Int
    ) async {
        let target = String(weekday.rawValue)
        let existing = allRules().first {
            $0.targetType == .weekday && $0.targetId == target && $0.alarmType == type
        }
        if let rule = existing {
            rule.alarmHour = hour
            rule.alarmMinute = minute
            rule.isEnabled = enabled
            rule.updatedAt = .now
        } else {
            let rule = AlarmRule(
                userId: userId, targetType: .weekday, targetId: target,
                alarmType: type, alarmTimeType: .absolute,
                alarmHour: hour, alarmMinute: minute,
                snoozeEnabled: true, snoozeIntervalMinutes: settings.snoozeIntervalMinutes,
                isEnabled: enabled
            )
            context.insert(rule)
        }
        try? context.save()
        await afterRuleChange()
    }

    // MARK: - 履歴（要件 13.7）

    func alarmHistory() -> [ScheduledAlarm] {
        let descriptor = FetchDescriptor<ScheduledAlarm>(
            sortBy: [SortDescriptor(\.scheduledAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func dismissWarning(_ index: Int) {
        guard warnings.indices.contains(index) else { return }
        warnings.remove(at: index)
    }
}

/// 未設定警告のクイック操作（要件 10.3）。
enum MissingFixChoice {
    case wakeAt(hour: Int, minute: Int)
    case relativeHours(Int)
    case notTomorrow
}
