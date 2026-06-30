//
//  NotificationService.swift
//  MadaNeteru?
//
//  要件 12章。AlarmKit を使わない「軽い」通知（予定リマインド・前日確認・
//  同期完了など）を UNUserNotificationCenter で扱う。
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    @discardableResult
    func requestAuthorization() async -> AuthStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func authorizationStatus() async -> AuthStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    /// 通常通知としてスケジュール（fixed のみ対応。weekly は AlarmKit 側で扱う）。
    func schedule(_ alarm: PlannedAlarm) async throws {
        guard let fireDate = alarm.fireDate, fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = alarm.title
        content.body = alarm.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    /// 即時の情報通知（同期完了・設定変更など）。
    func notifyNow(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
