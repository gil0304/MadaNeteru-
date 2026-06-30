//
//  KeychainStore.swift
//  MadaNeteru?
//
//  リフレッシュトークン等の機密情報を Keychain に安全に保存する（要件 17.2/17.3）。
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "app.Ochiai.gil.MadaNeteru.google"

    static func set(_ data: Data, for key: String) {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // Codable 値の保存補助
    static func setCodable<T: Encodable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) { set(data, for: key) }
    }
    static func getCodable<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = get(key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
