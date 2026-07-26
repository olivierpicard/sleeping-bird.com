//
//  UniqueIdentity.swift
//  ArperBird
//
//  Created by Olivier Picard on 05/06/2026.
//

import Foundation
import PostHog
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

    /// Removes the stored identity from the Keychain.
    ///
    /// The next `get()` generates a brand-new UUID, simulating a fresh install.
    /// Kept for test purposes (exercising the restore flow); not called in the
    /// normal app lifecycle.
    func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    // MARK: - Keychain access

    /// Matches the identity item regardless of its iCloud-sync flag, so we find
    /// both legacy (per-device) items and synchronizable ones written below.
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
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
        // Write a concrete value (not `...Any`) so the item is created as
        // iCloud-synced: the same Apple ID gets the same identity across
        // devices/reinstalls, keeping the RevenueCat appUserID and PostHog
        // distinct_id aligned so RC-origin events match the right person.
        attributes[kSecAttrSynchronizable as String] = true
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status != errSecSuccess else { return }
        // A failed write means the next `get()` mints a brand-new UUID, which
        // would silently fragment the user's analytics and RevenueCat identity.
        // Surface it so the breakage is visible instead of invisible.
        PostHogSDK.shared.capture(
            "identity_keychain_write_failed",
            properties: ["os_status": Int(status)]
        )
    }
}
