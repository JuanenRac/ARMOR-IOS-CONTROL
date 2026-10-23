// ARMOR-IOS-CONTROL - the Keychain of the phone as the place of the secrets (the session, the remembered login).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import Security
import ArmorCore

/// By default an item is readable after the first unlocking since the phone started (so the app can work after a restart); `tiedToUnlock` makes it readable only while the phone is unlocked.
/// Items never leave this phone (`ThisDeviceOnly`): no backup, no iCloud.
final class KeychainSecrets: SecretStore {
    private let service = "es.electrohobby3d.armor.ios"

    private func base(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    func read(_ key: String) -> SecretRead {
        var query = base(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            guard let data = out as? Data, let text = String(data: data, encoding: .utf8) else { return .absent }
            return .value(text)
        case errSecInteractionNotAllowed: return .locked   // the item exists but the phone is locked
        default: return .absent
        }
    }

    func write(_ key: String, _ value: String, tiedToUnlock: Bool) {
        remove(key)
        var item = base(key)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = tiedToUnlock ? kSecAttrAccessibleWhenUnlockedThisDeviceOnly : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    func remove(_ key: String) { SecItemDelete(base(key) as CFDictionary) }
}

/// Small settings in the preferences of the app (nothing secret).
final class PreferencesStore: KeyValueStore {
    private let defaults: UserDefaults
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    func get(_ key: String) -> String? { defaults.string(forKey: "armor." + key) }
    func put(_ key: String, _ value: String) { defaults.set(value, forKey: "armor." + key) }
    func remove(_ key: String) { defaults.removeObject(forKey: "armor." + key) }
}
