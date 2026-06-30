//
//  GoogleAuthService.swift
//  MadaNeteru?
//
//  外部 SDK に依存しない OAuth 2.0（Authorization Code + PKCE）実装。
//  ASWebAuthenticationSession でブラウザ同意 → トークン交換 → 自動リフレッシュ。
//  リフレッシュトークンは Keychain に保存（要件 17.2/17.3）。
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class GoogleAuthService: NSObject {

    struct StoredTokens: Codable {
        var accessToken: String
        var refreshToken: String
        var expiry: Date
    }

    private let tokenKey = "google.tokens"
    private let accountKey = "google.account"

    // ASWebAuthenticationSession はフロー中保持しておく必要がある。
    private var session: ASWebAuthenticationSession?

    // MARK: 公開

    var account: GoogleAccount? {
        guard let data = UserDefaults.standard.data(forKey: accountKey) else { return nil }
        return try? JSONDecoder().decode(GoogleAccount.self, from: data)
    }

    var isSignedIn: Bool { KeychainStore.get(tokenKey) != nil }

    /// 同意フロー → トークン取得 → ユーザー情報取得。
    func signIn() async throws -> GoogleAccount {
        guard GoogleConfig.isConfigured else {
            throw CalendarSyncError.notImplemented("GoogleConfig.clientID 未設定")
        }
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: GoogleConfig.clientID),
            .init(name: "redirect_uri", value: GoogleConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: GoogleConfig.scopes),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent")
        ]

        let callbackURL = try await presentAuthSession(
            url: comps.url!, scheme: GoogleConfig.redirectScheme
        )
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw CalendarSyncError.network("認可コードを取得できませんでした")
        }

        let token = try await exchangeCode(code, verifier: verifier)
        let tokens = StoredTokens(
            accessToken: token.access_token,
            refreshToken: token.refresh_token ?? "",
            expiry: Date(timeIntervalSinceNow: TimeInterval(token.expires_in))
        )
        KeychainStore.setCodable(tokens, for: tokenKey)

        let account = try await fetchUserInfo(accessToken: token.access_token)
        UserDefaults.standard.set(try? JSONEncoder().encode(account), forKey: accountKey)
        return account
    }

    func signOut() {
        KeychainStore.delete(tokenKey)
        UserDefaults.standard.removeObject(forKey: accountKey)
    }

    /// 有効なアクセストークンを返す（期限が近ければリフレッシュ）。
    func validAccessToken() async throws -> String {
        guard var tokens = KeychainStore.getCodable(StoredTokens.self, for: tokenKey) else {
            throw CalendarSyncError.notSignedIn
        }
        if tokens.expiry.timeIntervalSinceNow > 60 { return tokens.accessToken }
        guard !tokens.refreshToken.isEmpty else { throw CalendarSyncError.notSignedIn }

        let refreshed = try await refreshToken(tokens.refreshToken)
        tokens.accessToken = refreshed.access_token
        tokens.expiry = Date(timeIntervalSinceNow: TimeInterval(refreshed.expires_in))
        if let newRefresh = refreshed.refresh_token { tokens.refreshToken = newRefresh }
        KeychainStore.setCodable(tokens, for: tokenKey)
        return tokens.accessToken
    }

    // MARK: トークンエンドポイント

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
        let token_type: String
    }

    private func exchangeCode(_ code: String, verifier: String) async throws -> TokenResponse {
        try await postToken([
            "client_id": GoogleConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": GoogleConfig.redirectURI
        ])
    }

    private func refreshToken(_ refresh: String) async throws -> TokenResponse {
        try await postToken([
            "client_id": GoogleConfig.clientID,
            "refresh_token": refresh,
            "grant_type": "refresh_token"
        ])
    }

    private func postToken(_ params: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarSyncError.network("トークン取得失敗 (\((response as? HTTPURLResponse)?.statusCode ?? -1))")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchUserInfo(accessToken: String) async throws -> GoogleAccount {
        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct UserInfo: Decodable { let sub: String; let email: String?; let name: String? }
        let info = try JSONDecoder().decode(UserInfo.self, from: data)
        return GoogleAccount(id: info.sub, email: info.email ?? "", name: info.name ?? "")
    }

    // MARK: ASWebAuthenticationSession

    private func presentAuthSession(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CalendarSyncError.network("認証がキャンセルされました"))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }

    // MARK: PKCE

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(hash))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow })
            ?? scenes.first?.windows.first {
            return window
        }
        // 認証セッション提示時は必ず前面シーンが存在する。
        return UIWindow(windowScene: scenes.first!)
    }
}
