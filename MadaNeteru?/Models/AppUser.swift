//
//  AppUser.swift
//  MadaNeteru?
//
//  要件 14章 User。MVP は端末内・単一ユーザー想定だが、将来の複数端末同期に
//  備えて Google アカウント情報と各種許可状態を 1 レコードに保持する。
//

import Foundation
import SwiftData

@Model
final class AppUser {
    @Attribute(.unique) var id: String
    var googleAccountId: String?
    var email: String
    var name: String

    /// AlarmKit / 通知 / カレンダー同期の許可状態（rawValue 保存）。
    var alarmKitAuthorizationStatusRaw: String
    var notificationAuthorizationStatusRaw: String
    var calendarSyncEnabled: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        googleAccountId: String? = nil,
        email: String = "",
        name: String = "",
        alarmKitAuthorizationStatus: AuthStatus = .notDetermined,
        notificationAuthorizationStatus: AuthStatus = .notDetermined,
        calendarSyncEnabled: Bool = false
    ) {
        self.id = id
        self.googleAccountId = googleAccountId
        self.email = email
        self.name = name
        self.alarmKitAuthorizationStatusRaw = alarmKitAuthorizationStatus.rawValue
        self.notificationAuthorizationStatusRaw = notificationAuthorizationStatus.rawValue
        self.calendarSyncEnabled = calendarSyncEnabled
        self.createdAt = .now
        self.updatedAt = .now
    }

    var alarmKitAuthorizationStatus: AuthStatus {
        get { AuthStatus(rawValue: alarmKitAuthorizationStatusRaw) ?? .notDetermined }
        set { alarmKitAuthorizationStatusRaw = newValue.rawValue }
    }

    var notificationAuthorizationStatus: AuthStatus {
        get { AuthStatus(rawValue: notificationAuthorizationStatusRaw) ?? .notDetermined }
        set { notificationAuthorizationStatusRaw = newValue.rawValue }
    }

    var isSignedIn: Bool { googleAccountId != nil }
}

/// 許可状態の共通表現（AlarmKit / 通知 とも同じ 3 値で扱う）。
enum AuthStatus: String, Codable, Sendable {
    case notDetermined
    case denied
    case authorized

    var isAuthorized: Bool { self == .authorized }
}
