// ARMOR-IOS-CONTROL - the lock of the phone, used to protect the app: Face ID, Touch ID or the passcode of the phone itself, asked before the sensitive actions and, if wanted, to open the app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
//
// Everything here is a choice of the person, with the careful default: before arming, disarming, silencing a siren, unlocking and the other critical orders the app asks for Face ID or Touch ID
// when the phone has one (and for nothing when it has no passcode at all). Opening the app behind the lock is off until the person turns it on. The server can only RAISE this (the security
// option `client.device_lock` of Studio: "sensitive" or "always"); it can never lower what the person chose. A phone with no lock at all is never shut out, and a locked app always offers the
// way out of signing in again with the password. The lock only protects an unattended phone: the server keeps checking the session, the PIN and the proof of identity on its own.
import Foundation

/// What the phone can ask: Face ID or Touch ID (and, as the way out of it, the passcode), the passcode alone, or nothing.
public enum LockAvailability: Equatable, Sendable { case biometric, deviceCredential, none }

/// What the server asks of every phone: nothing more than the person chose, also the sensitive actions, or also to open the app.
public enum ServerLock: String, Equatable, Sendable {
    case user, sensitive, always
    /// The value the server announced; anything it did not say (an older server) or a word this version does not know is "the person decides".
    public static func parse(_ text: String?) -> ServerLock {
        switch text {
        case "sensitive": return .sensitive
        case "always": return .always
        default: return .user
        }
    }
    public var wire: String { rawValue }
}

public enum AuthResult: Equatable, Sendable {
    case success
    /// The person closed the question.
    case cancelled
    /// The phone cannot ask (no passcode, nothing enrolled): the person is not shut out for it.
    case unavailable
    /// A refusal that is not a choice: too many wrong tries, a lock-out.
    case failed(String)
}

/// The phone's question, behind a protocol so the rules can be tested without a phone.
public protocol DeviceAuth: Sendable {
    func availability() -> LockAvailability
    func authenticate(title: String, subtitle: String) async -> AuthResult
}

/// The phone that has nothing to ask with (a preview, a test): the app is not locked by it.
public struct NoDeviceAuth: DeviceAuth {
    public init() {}
    public func availability() -> LockAvailability { .none }
    public func authenticate(title: String, subtitle: String) async -> AuthResult { .unavailable }
}

/// The few places the app writes small settings and secrets.
public protocol KeyValueStore: AnyObject {
    func get(_ key: String) -> String?
    func put(_ key: String, _ value: String)
    func remove(_ key: String)
}

public final class MemoryStore: KeyValueStore {
    private var values: [String: String] = [:]
    public init() {}
    public func get(_ key: String) -> String? { values[key] }
    public func put(_ key: String, _ value: String) { values[key] = value }
    public func remove(_ key: String) { values[key] = nil }
}

/// What the person chose, kept in the phone's preferences.
public final class LockSettings {
    public static let graceChoices = [0, 30, 120, 300]
    public static let defaultGrace = 30
    private let store: KeyValueStore
    public init(_ store: KeyValueStore) { self.store = store }

    /// Before the sensitive actions: what the person chose, else on when the phone has Face ID or Touch ID, else off.
    public func sensitive(_ availability: LockAvailability) -> Bool {
        if let value = store.get("lock_sensitive") { return value == "1" }
        return availability == .biometric
    }
    public func setSensitive(_ on: Bool) { store.put("lock_sensitive", on ? "1" : "0") }

    /// Behind the lock to open the app: off until the person turns it on.
    public var openApp: Bool {
        get { store.get("lock_open") == "1" }
        set { store.put("lock_open", newValue ? "1" : "0") }
    }

    /// For how long one unlocking counts, in seconds: 0 asks every time.
    public var graceSeconds: Int {
        get { store.get("lock_grace").flatMap(Int.init).flatMap { LockSettings.graceChoices.contains($0) ? $0 : nil } ?? LockSettings.defaultGrace }
        set { store.put("lock_grace", String(LockSettings.graceChoices.contains(newValue) ? newValue : LockSettings.defaultGrace)) }
    }

    /// What the server asked the last time the person was signed in, so it also holds when the app opens before the sign-in.
    public var server: ServerLock {
        get { ServerLock.parse(store.get("lock_server")) }
        set { store.put("lock_server", newValue.wire) }
    }
}

/// What the screen of the settings shows.
public struct LockStatus: Equatable, Sendable {
    public let availability: LockAvailability
    public let sensitiveOn: Bool, openOn: Bool
    public let graceSeconds: Int
    public let server: ServerLock
    public let unmet: Bool
    /// The server asks for it, so the person's switch cannot turn it off.
    public var sensitiveForced: Bool { server != .user }
    public var openForced: Bool { server == .always }
}

/// When the lock is asked for: the rules, with the clock and the phone's answer given from outside.
public final class LockPolicy: @unchecked Sendable {
    private let settings: LockSettings
    private let availability: () -> LockAvailability
    private let clock: () -> Double
    private let state = NSLock()
    private var lastAuthAt: Double?
    private var leftAt: Double?
    private var promptingFlag = false

    public init(settings: LockSettings, availability: @escaping () -> LockAvailability, clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime * 1000 }) {
        self.settings = settings; self.availability = availability; self.clock = clock
    }

    /// True while the phone's own question is on screen: leaving the app for it is not leaving the app.
    public var prompting: Bool {
        get { state.lock(); defer { state.unlock() }; return promptingFlag }
        set { state.lock(); defer { state.unlock() }; promptingFlag = newValue }
    }

    /// The sensitive actions need the lock: the person's choice, or the server's, and only when the phone has a lock to ask.
    public func sensitiveRequired() -> Bool {
        let phone = availability()
        if phone == .none { return false }
        return settings.sensitive(phone) || settings.server != .user
    }

    /// Opening the app needs the lock.
    public func openRequired() -> Bool {
        if availability() == .none { return false }
        return settings.openApp || settings.server == .always
    }

    /// The last unlocking still counts.
    public func fresh() -> Bool {
        state.lock(); defer { state.unlock() }
        guard let at = lastAuthAt else { return false }
        let grace = settings.graceSeconds
        return grace > 0 && clock() - at < Double(grace) * 1000
    }

    /// A sensitive action has to ask now.
    public func promptNeeded() -> Bool { sensitiveRequired() && !fresh() }

    /// The person was recognised just now.
    public func unlocked() { state.lock(); lastAuthAt = clock(); state.unlock() }

    /// The app went out of sight.
    public func left() { state.lock(); if !promptingFlag { leftAt = clock() }; state.unlock() }

    /// The app is back in sight: true when it must be locked again (it was away for as long as an unlocking counts, or longer).
    public func returned() -> Bool {
        state.lock()
        if promptingFlag { state.unlock(); return false }
        guard let at = leftAt else { state.unlock(); return false }
        leftAt = nil
        let away = clock() - at
        state.unlock()
        return openRequired() && away >= Double(settings.graceSeconds) * 1000
    }

    public func status() -> LockStatus {
        let phone = availability()
        let sensitive = settings.sensitive(phone) || settings.server != .user
        let open = settings.openApp || settings.server == .always
        return LockStatus(availability: phone, sensitiveOn: sensitive, openOn: open, graceSeconds: settings.graceSeconds, server: settings.server,
                          unmet: phone == .none && (sensitive || open))
    }
}

/// Puts the question of the phone in front of the actions and of the opening of the app. Two orders at once ask once.
public actor LockGate {
    public nonisolated let policy: LockPolicy
    private let auth: DeviceAuth
    private let translator: Translator
    public init(policy: LockPolicy, auth: DeviceAuth, translator: Translator) { self.policy = policy; self.auth = auth; self.translator = translator }

    /// True when the action may go on.
    public func allow(reason: String) async -> Bool {
        if !policy.promptNeeded() { return true }
        switch await ask(translator.tr("Confirma que eres tú"), reason) {
        case .success, .unavailable: return true   // a phone that cannot ask is not a phone that cannot be used
        default: return false
        }
    }

    /// The question to change the lock itself: turning it on proves it works on this phone, turning it off proves it is the person.
    public func prove() async -> AuthResult { await ask(translator.tr("Confirma que eres tú"), translator.tr("Cambiar el bloqueo de la aplicación")) }

    /// The question to open the app.
    public func unlockToOpen() async -> AuthResult {
        await ask(translator.tr("Abre A.R.M.O.R. con el bloqueo del teléfono"), translator.tr("Solo tú puedes abrir la aplicación."))
    }

    private var inflight: Task<AuthResult, Never>?

    private func ask(_ title: String, _ subtitle: String) async -> AuthResult {
        // an actor lets another call in while this one waits for the phone: the second one waits for the same answer instead of asking again
        if let running = inflight { return await running.value }
        let policy = self.policy, auth = self.auth
        let task = Task<AuthResult, Never> {
            policy.prompting = true
            let result = await auth.authenticate(title: title, subtitle: subtitle)
            policy.prompting = false
            if result == .success || result == .unavailable { policy.unlocked() }
            return result
        }
        inflight = task
        let result = await task.value
        inflight = nil
        return result
    }
}
