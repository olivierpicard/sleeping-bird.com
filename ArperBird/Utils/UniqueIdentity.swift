//
//  UniqueIdentity.swift
//  ArperBird
//
//  Created by Olivier Picard on 05/06/2026.
//

import Foundation
import Security

/// Stores a stable, per-install UUID in the Keychain.
///
/// The Keychain survives app deletion/reinstall and is encrypted at rest, so it
/// is the source of truth for the identity. Items use
/// `kSecAttrAccessibleAfterFirstUnlock` so the value is readable on background
/// launches after the first unlock following a reboot.
struct UniqueIdentityStore {
    /// Keychain account key under which the identity is stored.
    private let account = "com.alizetech.arperbird.uniqueIdentity"

    /// Returns the existing identity, creating and persisting one if none exists.
    func get() -> String {
        if let existing = load() {
            return existing
        }
        return generateAndSave()
    }

    /// Generates a fresh UUID, stores it in the Keychain, and returns it.
    @discardableResult
    func generateAndSave() -> String {
        let identity = UUID().uuidString
        save(identity)
        return identity
    }

    // MARK: - Keychain access

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
    }

    private func load() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func save(_ value: String) {
        let data = Data(value.utf8)

        // Replace any existing item so we never end up with duplicates.
        SecItemDelete(baseQuery() as CFDictionary)

        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(attributes as CFDictionary, nil)
    }
}
