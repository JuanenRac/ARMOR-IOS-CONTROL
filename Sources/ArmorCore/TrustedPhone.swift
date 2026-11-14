// ARMOR-IOS-CONTROL - a trusted phone: a key pair that never leaves the phone, registered with the server, so that the session can be renewed by signing a challenge instead of typing the password and the
// code again. The same rules as the Android app.
// OFF by default, and only offered when the administrator turned on `client.trusted_devices` in Studio (announced in `capabilities.security` of the session). The private half is made inside the Secure
// Enclave, cannot be exported and can be used only while the phone is unlocked. The server keeps the public half, hands out a one-time challenge, and opens a session of the length the administrator chose
// only to the phone that signs it. The administrator (or the person) can end the phone from Studio at any time, and turning the switch off here ends it too.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The key pair of the phone, behind a protocol so the rules can be tested without a phone (the real one is in the Secure Enclave).
public protocol DeviceSigner: AnyObject, Sendable {
    /// Whether this phone can hold the key (a simulator or a test cannot).
    func available() -> Bool
    /// The public key as base64 of its DER form (SubjectPublicKeyInfo), made on the first call; nil when it cannot be made.
    func publicKey() -> String?
    /// The ECDSA P-256 signature with SHA-256, in DER, of `data`; nil when the key cannot be used now (the phone is locked) or there is none.
    func sign(_ data: Data) -> Data?
    /// Forgets the key pair.
    func forget()
}

/// No key at all: a preview, a test.
public final class NoDeviceSigner: DeviceSigner {
    public init() {}
    public func available() -> Bool { false }
    public func publicKey() -> String? { nil }
    public func sign(_ data: Data) -> Data? { nil }
    public func forget() {}
}

/// What the person chose and what the server gave this phone, in the preferences of the app.
public final class TrustedPhoneSettings {
    private let store: KeyValueStore
    private static let enabledKey = "trusted_phone"
    private static let idPrefix = "trusted_phone_id:"
    public init(_ store: KeyValueStore) { self.store = store }

    /// The person's switch; off until they turn it on.
    public var enabled: Bool {
        get { store.get(Self.enabledKey) == "1" }
        set { store.put(Self.enabledKey, newValue ? "1" : "0") }
    }

    /// The id the server gave this phone on `origin`: 24 lowercase hex digits, or nil.
    public func id(_ origin: String) -> String? {
        guard let value = store.get(Self.idPrefix + origin), Self.valid(value) else { return nil }
        return value
    }

    public func setId(_ origin: String, _ id: String) { if Self.valid(id) { store.put(Self.idPrefix + origin, id) } }
    public func clear(_ origin: String) { store.remove(Self.idPrefix + origin) }

    static func valid(_ id: String) -> Bool {
        id.count == 24 && id.unicodeScalars.allSatisfy { ($0 >= "0" && $0 <= "9") || ($0 >= "a" && $0 <= "f") }
    }
}

/// What came of asking the server to trust this phone.
public enum TrustResult: Equatable, Sendable {
    /// Registered (or it already was).
    case done
    /// The person's switch is off.
    case off
    /// The server does not offer it (an older one, or the administrator left it off) or this phone cannot hold a key.
    case unavailable
    /// The server wants a new proof of identity first.
    case needsProof
    /// The server refused (too many phones, a bad name) or could not be reached.
    case failed
}

/// The text the phone signs: the same the server checks, tied to one phone and one challenge.
public func trustedSignedText(id: String, challenge: String) -> String { "armor-device-trust-v1|\(id)|\(challenge)" }

public final class TrustedPhone: @unchecked Sendable {
    private let api: ArmorApi
    private let signer: DeviceSigner
    private let settings: TrustedPhoneSettings
    private let phoneName: @Sendable () -> String

    public init(api: ArmorApi, signer: DeviceSigner, settings: TrustedPhoneSettings, phoneName: @escaping @Sendable () -> String) {
        self.api = api; self.signer = signer; self.settings = settings; self.phoneName = phoneName
    }

    /// Whether the person asked for it and this phone can do it.
    public func wanted() -> Bool { settings.enabled && signer.available() }

    /// Registers this phone with the server once signed in, when the person asked for it and the server offers it (`offered`: `capabilities.security` says so).
    public func register(_ origin: String, offered: Bool) async -> TrustResult {
        if !settings.enabled { return .off }
        if !offered || !signer.available() { return .unavailable }
        if settings.id(origin) != nil { return .done }
        guard let key = signer.publicKey() else { return .unavailable }
        let name = String(phoneName().prefix(60))
        do {
            let id = try await api.trustRegister(origin, name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "iPhone" : name, publicKey: key)
            settings.setId(origin, id)
            return settings.id(origin) != nil ? .done : .failed
        } catch let error as ArmorApiError {
            return error.isElevationRequired ? .needsProof : .failed
        } catch { return .failed }
    }

    /// Opens a new session by signing a challenge, when this phone was registered on `origin`. True when the server opened one (its cookie is then the session of the client). A refusal that says the
    /// server no longer knows this phone (ended from Studio, the option turned off) forgets the id, so the person signs in the ordinary way and is not asked again for nothing; a server that could not
    /// be reached leaves everything as it is.
    public func renew(_ origin: String) async -> Bool {
        guard settings.enabled, let id = settings.id(origin) else { return false }
        do {
            let challenge = try await api.trustChallenge(origin, id: id)
            // the phone is locked: try again later, keep the id
            guard let signature = signer.sign(Data(trustedSignedText(id: id, challenge: challenge).utf8)) else { return false }
            try await api.trustSession(origin, id: id, challenge: challenge, signature: signature.base64EncodedString())
            return true
        } catch let error as ArmorApiError {
            if error.status == 404 || error.status == 401 { settings.clear(origin) }
            return false
        } catch { return false }
    }

    /// The person turned it off, or signed out of this server: the server forgets the phone (when it can be asked) and so does the app. The key is kept for the other servers unless `dropKey`.
    public func end(_ origin: String, dropKey: Bool = false) async {
        if let id = settings.id(origin) { try? await api.trustRemove(origin, id: id) }
        settings.clear(origin)
        if dropKey { signer.forget() }
    }
}
