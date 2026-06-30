//
//  GoogleConfig.swift
//  MadaNeteru?
//
//  Google OAuth の設定。Google Cloud Console で発行した iOS OAuth クライアントID を
//  clientID に入れると実連携が有効になる。空のままならアプリはモックで動作する。
//
//  ── 取得手順 ──────────────────────────────────────────────
//  1. https://console.cloud.google.com/ でプロジェクト作成
//  2. 「APIとサービス」→ Google Calendar API を有効化
//  3. 「OAuth 同意画面」を構成（スコープ: .../auth/calendar.readonly）
//  4. 「認証情報」→「OAuth クライアントID」→ アプリの種類「iOS」
//     - Bundle ID: app.Ochiai.gil.MadaNeteru-
//  5. 発行された「クライアントID」(…….apps.googleusercontent.com) を下に貼る
//  ────────────────────────────────────────────────────────
//

import Foundation

enum GoogleConfig {
    /// 例: "1234567890-abcdefg.apps.googleusercontent.com"
    static let clientID = "322873895616-vqaon87crcvl3oojbccs8linorq3gs5d.apps.googleusercontent.com"

    /// 読み取り専用スコープ（要件 17.2/17.3）。
    static let scopes = "openid email profile https://www.googleapis.com/auth/calendar.readonly"

    static var isConfigured: Bool { !clientID.isEmpty }

    /// 逆ドメインのカスタムスキーム（ASWebAuthenticationSession のコールバック用）。
    static var redirectScheme: String {
        let suffix = ".apps.googleusercontent.com"
        let base = clientID.hasSuffix(suffix) ? String(clientID.dropLast(suffix.count)) : clientID
        return "com.googleusercontent.apps." + base
    }

    static var redirectURI: String { redirectScheme + ":/oauth2redirect" }
}
