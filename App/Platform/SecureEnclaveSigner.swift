// ARMOR-IOS-CONTROL - the key pair of a trusted phone, made inside the Secure Enclave: the private half cannot be exported and can be used only while the phone is unlocked.
// The Keychain keeps only the opaque handle CryptoKit gives (it is of no use on another phone). A phone without a Secure Enclave (a simulator) offers nothing, and the app then never shows the phone as a trusted one.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import CryptoKit
import Foundation
import Security
import ArmorCore

final class SecureEnclaveSigner: DeviceSigner, @unchecked Sendable {
    private let keychain = KeychainSecrets()
    private let slot = "trusted_phone_key"

    func available() -> Bool { SecureEnclave.isAvailable }

    private func existing() -> SecureEnclave.P256.Signing.PrivateKey? {
        guard case .value(let text) = keychain.read(slot), let data = Data(base64Encoded: text) else { return nil }
        return try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
    }

    private func made() -> SecureEnclave.P256.Signing.PrivateKey? {
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .privateKeyUsage, nil),
              let key = try? SecureEnclave.P256.Signing.PrivateKey(accessControl: access) else { return nil }
        keychain.write(slot, key.dataRepresentation.base64EncodedString(), tiedToUnlock: true)
        return key
    }

    /// The public half as base64 of its DER form (SubjectPublicKeyInfo), the key being made on the first call.
    func publicKey() -> String? {
        guard available(), let key = existing() ?? made() else { return nil }
        return key.publicKey.derRepresentation.base64EncodedString()
    }

    /// The ECDSA P-256 signature with SHA-256, in DER; nil while the phone is locked or without a key.
    func sign(_ data: Data) -> Data? {
        guard available(), let key = existing() else { return nil }
        return try? key.signature(for: data).derRepresentation
    }

    func forget() { keychain.remove(slot) }
}
