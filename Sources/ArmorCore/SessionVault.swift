// ARMOR-IOS-CONTROL - keeps the session of the server between launches, so the app opens already signed in, and, only if the person ticks "remember me", the user and the password.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
//
// What is kept is the session cookie the server handed out. The password is typed once and forgotten unless the person asks to remember it. Everything secret lives in the Keychain of the phone,
// which cannot be taken out of it. By default it is readable after the first unlocking of the phone since it started (so that the app can work after a restart); with the optional switch (off by
// default, with a visible warning) it is readable only while the phone is unlocked.
import Foundation

public enum SecretRead: Equatable, Sendable {
    case value(String)
    case absent
    /// There is something, but the phone is locked and cannot give it now: it is left alone, not taken for lost.
    case locked
}

/// Where the secrets are kept (the Keychain in the app, a dictionary in a test).
public protocol SecretStore: AnyObject {
    func read(_ key: String) -> SecretRead
    /// `tiedToUnlock` chooses the accessibility class of the item: only while the phone is unlocked, or after the first unlocking.
    func write(_ key: String, _ value: String, tiedToUnlock: Bool)
    func remove(_ key: String)
}

public final class MemorySecrets: SecretStore {
    public var items: [String: (value: String, tied: Bool)] = [:]
    public var phoneLocked = false
    public init() {}
    public func read(_ key: String) -> SecretRead {
        guard let item = items[key] else { return .absent }
        return item.tied && phoneLocked ? .locked : .value(item.value)
    }
    public func write(_ key: String, _ value: String, tiedToUnlock: Bool) { items[key] = (value, tiedToUnlock) }
    public func remove(_ key: String) { items[key] = nil }
}

public struct RememberedLogin: Equatable, Sendable {
    public let username: String
    public let password: String
}

public final class SessionVault {
    private let secrets: SecretStore
    private let prefs: KeyValueStore
    public init(secrets: SecretStore, prefs: KeyValueStore) { self.secrets = secrets; self.prefs = prefs }

    /// Option of the person, off by default: the secrets are readable only while the phone is unlocked.
    public var tiedToUnlock: Bool { prefs.get("vault_tied") == "1" }

    /// Turns the option on or off and moves what is kept to the other accessibility class. Returns false when something could not be moved because the phone is locked.
    @discardableResult
    public func setTiedToUnlock(_ on: Bool) -> Bool {
        var moved = true
        for key in [Self.cookieKey, Self.loginKey] {
            switch secrets.read(key) {
            case .value(let text): secrets.write(key, text, tiedToUnlock: on)
            case .locked: moved = false
            case .absent: break
            }
        }
        if moved { prefs.put("vault_tied", on ? "1" : "0") }
        return moved
    }

    /// False while the secrets cannot be read for a reason that will pass (tied to the unlocking, and the phone is locked).
    public func readable() -> Bool {
        for key in [Self.cookieKey, Self.loginKey] { if secrets.read(key) == .locked { return false } }
        return true
    }

    static let cookieKey = "session_cookie"
    static let loginKey = "remembered_login"

    public func saveSession(_ cookie: SessionCookie, origin: String) {
        secrets.write(Self.cookieKey, Self.join([origin, cookie.name, cookie.value]), tiedToUnlock: tiedToUnlock)
    }

    /// The kept session, for that origin only; nil when there is none, when it belongs to another server, or when the phone is locked (see `readable`).
    public func loadSession(origin: String) -> SessionCookie? {
        guard case .value(let text) = secrets.read(Self.cookieKey) else { return nil }
        let parts = Self.split(text)
        guard parts.count == 3, parts[0] == origin else { return nil }
        return SessionCookie(name: parts[1], value: parts[2])
    }

    public func dropSession() { secrets.remove(Self.cookieKey) }

    public func rememberLogin(origin: String, username: String, password: String) {
        secrets.write(Self.loginKey, Self.join([origin, username, password]), tiedToUnlock: tiedToUnlock)
    }

    public func rememberedLogin(origin: String) -> RememberedLogin? {
        guard case .value(let text) = secrets.read(Self.loginKey) else { return nil }
        let parts = Self.split(text)
        guard parts.count == 3, parts[0] == origin else { return nil }
        return RememberedLogin(username: parts[1], password: parts[2])
    }

    public func forgetLogin() { secrets.remove(Self.loginKey) }

    /// The way out of a locked app: forgets the session and the remembered login. The server and its alarms are not touched.
    public func forgetAll() { dropSession(); forgetLogin() }

    // the three pieces are kept as one text with a separator that cannot be in any of them (a unit separator)
    private static let separator = "\u{1F}"
    private static func join(_ parts: [String]) -> String { parts.map { $0.replacingOccurrences(of: separator, with: "") }.joined(separator: separator) }
    private static func split(_ text: String) -> [String] { text.components(separatedBy: separator) }
}
