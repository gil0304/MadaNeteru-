//
//  CalendarSyncState.swift
//  MadaNeteru?
//
//  要件 6.3/6.4・14章。カレンダーごとの差分同期トークン（syncToken）を保持。
//  Google Calendar API の events.list は前回同期以降の差分だけを syncToken で
//  取得できるため、カレンダー単位で最新トークンを覚えておく。
//

import Foundation
import SwiftData

@Model
final class CalendarSyncState {
    @Attribute(.unique) var id: String
    var userId: String
    var googleCalendarId: String
    var syncToken: String?
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        googleCalendarId: String,
        syncToken: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.googleCalendarId = googleCalendarId
        self.syncToken = syncToken
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = .now
        self.updatedAt = .now
    }
}
