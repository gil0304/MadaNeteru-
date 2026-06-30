//
//  AlarmKitScheduler.swift
//  MadaNeteru?
//
//  要件 9章。AlarmKit を使った長時間アラームの実装。
//  起床・充電確認・出発・未設定警告など「強く鳴らす」アラームをここで担う。
//
//  注意: ロック画面 / Dynamic Island のカウントダウン Live Activity を完全表示
//  するには別途 Widget Extension で AlarmAttributes に対応した
//  ActivityConfiguration を実装する必要がある（MVP では本体スケジュールのみ）。
//

import Foundation
import SwiftUI
import AlarmKit
import ActivityKit

/// AlarmKit に渡すメタデータ。プライバシー要件に沿い最小限のみ。
struct MadaNeteruMetadata: AlarmMetadata {
    var alarmTypeRaw: String
    var eventTitle: String?
}

final class AlarmKitScheduler: AlarmScheduling, @unchecked Sendable {

    private var manager: AlarmManager { AlarmManager.shared }

    // MARK: 認可

    var authorizationState: AuthStatus {
        get async { Self.map(manager.authorizationState) }
    }

    @discardableResult
    func requestAuthorization() async -> AuthStatus {
        // 既に確定済みなら再リクエストしない（要件 9.3）。
        if manager.authorizationState != .notDetermined {
            return Self.map(manager.authorizationState)
        }
        do {
            let state = try await manager.requestAuthorization()
            return Self.map(state)
        } catch {
            return .denied
        }
    }

    // MARK: スケジュール

    func schedule(_ alarm: PlannedAlarm) async throws {
        let schedule = Self.makeSchedule(alarm.when)

        // 停止ボタン
        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: alarm.stopButtonText),
            textColor: .white,
            systemImageName: "stop.circle.fill"
        )

        // スヌーズ（secondaryButton + .countdown）
        var secondaryButton: AlarmButton?
        var secondaryBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior?
        var countdownPresentation: AlarmPresentation.Countdown?
        var countdownDuration: Alarm.CountdownDuration?
        if alarm.snoozeEnabled {
            secondaryButton = AlarmButton(
                text: "スヌーズ",
                textColor: .white,
                systemImageName: "zzz"
            )
            secondaryBehavior = .countdown
            countdownPresentation = AlarmPresentation.Countdown(
                title: "スヌーズ中",
                pauseButton: nil
            )
            countdownDuration = Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: TimeInterval(alarm.snoozeIntervalMinutes * 60)
            )
        }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.title),
            stopButton: stopButton,
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryBehavior
        )

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: countdownPresentation,
            paused: nil
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: MadaNeteruMetadata(
                alarmTypeRaw: alarm.alarmType.rawValue,
                eventTitle: alarm.body.isEmpty ? nil : alarm.body
            ),
            tintColor: Color(hex: alarm.tintHex)
        )

        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .default
        )

        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
    }

    func cancel(id: UUID) async {
        try? manager.cancel(id: id)
    }

    func stop(id: UUID) async {
        try? manager.stop(id: id)
    }

    func activeAlarmIDs() async -> Set<UUID> {
        guard let alarms = try? manager.alarms else { return [] }
        return Set(alarms.map(\.id))
    }

    // MARK: マッピング

    private static func map(_ state: AlarmManager.AuthorizationState) -> AuthStatus {
        switch state {
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .notDetermined: return .notDetermined
        @unknown default:    return .notDetermined
        }
    }

    private static func makeSchedule(_ when: PlannedAlarm.When) -> Alarm.Schedule {
        switch when {
        case .fixed(let date):
            return .fixed(date)
        case .weekly(let hour, let minute, let weekdays):
            let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
            let recurrence: Alarm.Schedule.Relative.Recurrence =
                weekdays.isEmpty ? .never : .weekly(weekdays.map(\.localeWeekday))
            return .relative(.init(time: time, repeats: recurrence))
        }
    }
}
