// ARMOR-IOS-CONTROL - the use cases of the app (sign in, refresh, arm, disarm, acknowledge, silence, ask the assistant) without any screen, so they are tested with a fake server.
// The screens only show `state` and call these methods.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// Why an order did not go out, apart from the server's own refusals (those are `ArmorApiError`).
public enum ControllerError: Error, Equatable, Sendable {
    /// The person did not pass the lock of the phone: nothing was done.
    case lockRefused
    /// The role of the signed-in user only lets it look.
    case readOnly
    /// Not signed in.
    case notSignedIn
    /// The proof of identity the server asked for was not given.
    case elevationDeclined
}

public struct ArmorState: Equatable, Sendable {
    public var origin: String?
    public var signedIn = false
    public var facts = SessionFacts()
    public var snapshot = ArmorSnapshot()
    public var active: [Alarm] = []
    public var recent: [Alarm] = []
    public var events: [ArmorEvent] = []
    public var panels: [AlarmPanelView] = []
    public var profiles: [ArmProfileView] = []
    /// The arming modes of the server; nil until it has answered (and kept as it was against an older server that never does).
    public var armingModes: ArmingModesView?
    public var commandsEnabled = false
    public var unseenAlarms: Int { active.filter { !$0.acknowledged }.count }
    public var lastRefreshFailed = false
    public init() {}
}

/// Asks the person to prove who they are again (the server asks it for critical actions from outside the house); nil when they decline.
public typealias ElevationAsker = @Sendable () async -> (password: String, code: String)?

public final class ArmorController: @unchecked Sendable {
    public let api: ArmorApi
    public let vault: SessionVault
    public let gate: LockGate
    public let lockSettings: LockSettings
    public let translator: Translator
    private let lock = NSLock()
    private var current = ArmorState()
    private let seen = SeenEvents()

    public init(api: ArmorApi, vault: SessionVault, gate: LockGate, lockSettings: LockSettings, translator: Translator) {
        self.api = api; self.vault = vault; self.gate = gate; self.lockSettings = lockSettings; self.translator = translator
    }

    public var state: ArmorState { lock.lock(); defer { lock.unlock() }; return current }
    private func update(_ change: (inout ArmorState) -> Void) { lock.lock(); change(&current); lock.unlock() }
    private func origin() throws -> String {
        guard let origin = state.origin, state.signedIn else { throw ControllerError.notSignedIn }
        return origin
    }

    // MARK: sign in

    /// The password goes to the server once. With `remember` the user and the password are kept in the Keychain; without it nothing of them is kept.
    public func signIn(origin: String, username: String, password: String, remember: Bool) async throws -> SignIn {
        let outcome = try await api.signIn(origin, username: username, password: password)
        if outcome == .done { try await opened(origin, username: username, password: remember ? password : nil) }
        else { update { $0.origin = origin } }
        return outcome
    }

    /// The second step: the challenge of the first and the code of the app (or a recovery code).
    public func completeSignIn(origin: String, challenge: String, code: String, username: String, password: String?) async throws {
        try await api.completeSignIn(origin, challenge: challenge, code: code)
        try await opened(origin, username: username, password: password)
    }

    private func opened(_ origin: String, username: String, password: String?) async throws {
        if let password { vault.rememberLogin(origin: origin, username: username, password: password) } else { vault.forgetLogin() }
        if let cookie = api.sessionCookie(origin) { vault.saveSession(cookie, origin: origin) }
        let facts = (try? await api.sessionFacts(origin)) ?? SessionFacts()
        lockSettings.server = ServerLock.parse(facts.deviceLock)
        update { $0.origin = origin; $0.signedIn = true; $0.facts = facts }
    }

    /// Opens the app already signed in when the server still honours the kept session; false when the person must sign in (the kept session is dropped when the server refused it).
    public func restore(origin: String) async -> Bool {
        guard let cookie = vault.loadSession(origin: origin) else { return false }
        api.restoreSessionCookie(origin, cookie)
        do {
            let facts = try await api.sessionFacts(origin)
            if facts.role.isEmpty { vault.dropSession(); api.forgetSession(origin); return false }
            lockSettings.server = ServerLock.parse(facts.deviceLock)
            if let renewed = api.sessionCookie(origin) { vault.saveSession(renewed, origin: origin) }
            update { $0.origin = origin; $0.signedIn = true; $0.facts = facts }
            return true
        } catch let error as ArmorApiError {
            if error.isUnauthorized { vault.dropSession(); api.forgetSession(origin) }
            return false
        } catch { return false }
    }

    /// Ends the session at the server (whatever it says) and forgets it here.
    public func signOut(forgetLogin: Bool = true) async {
        if let origin = state.origin {
            try? await api.closeSession(origin)
            api.forgetSession(origin)
        }
        vault.dropSession()
        if forgetLogin { vault.forgetLogin() }
        update { $0 = ArmorState() }
    }

    // MARK: reading

    /// Reads the status, the alarms and the history; returns the notices of what is new since the last time (the first call only records where the history stands).
    @discardableResult
    public func refresh() async -> [AlarmNotice] {
        guard let origin = state.origin, state.signedIn else { return [] }
        do {
            async let snapshot = api.status(origin)
            async let alarms = api.alarms(origin)
            async let events = api.history(origin, limit: 50, before: nil, after: nil)
            let (status, list, history) = try await (snapshot, alarms, events)
            let panels = (try? await api.alarmPanels(origin)) ?? state.panels
            let modes = (try? await api.armingModes(origin)) ?? state.armingModes
            let fresh = seen.fresh(history)
            let notices = AlarmPolicy.notices(fresh, armed: status.armed, translator)
            update { $0.snapshot = status; $0.active = list.active; $0.recent = list.recent; $0.events = history; $0.panels = panels; $0.armingModes = modes; $0.lastRefreshFailed = false }
            return notices
        } catch let error as ArmorApiError {
            if error.isUnauthorized { update { $0.signedIn = false } }
            update { $0.lastRefreshFailed = true }
            return []
        } catch {
            update { $0.lastRefreshFailed = true }
            return []
        }
    }

    /// What would leave the perimeter blind or noisy, asked before arming.
    public func preflight() async throws -> Preflight { try await api.preflight(try origin()) }

    // MARK: orders

    /// Runs an order behind the lock of the phone, and, if the server asks for a new proof of identity, asks the person and tries again once.
    public func guarded(reason: String, asker: ElevationAsker? = nil, _ action: @escaping @Sendable (String) async throws -> Void) async throws {
        let origin = try origin()
        guard state.facts.canChange else { throw ControllerError.readOnly }
        guard await gate.allow(reason: reason) else { throw ControllerError.lockRefused }
        do { try await action(origin) }
        catch let error as ArmorApiError where error.isElevationRequired {
            guard let asker, let proof = await asker() else { throw ControllerError.elevationDeclined }
            try await api.elevate(origin, password: proof.password, code: proof.code)
            try await action(origin)
        }
        await refresh()
    }

    public func arm(asker: ElevationAsker? = nil) async throws {
        try await guarded(reason: translator.tr("Armar el sistema"), asker: asker) { [api] origin in try await api.setMode(origin, mode: "armed", pin: nil) }
    }

    public func disarm(pin: String?, asker: ElevationAsker? = nil) async throws {
        try await guarded(reason: translator.tr("Desarmar el sistema"), asker: asker) { [api] origin in try await api.setMode(origin, mode: "disarmed", pin: pin) }
    }

    /// Arms the system in a mode of the server (Away, Home or Night). Behind the lock of the phone like arming; a refusal that the picker answers (the confirmation of a mode with nothing assigned, a
    /// PIN) comes as an `ArmorApiError` whose `code` says which.
    public func armInMode(_ mode: String, pin: String?, confirmUnassigned: Bool, asker: ElevationAsker? = nil) async throws {
        try await guarded(reason: translator.tr("Armar el sistema"), asker: asker) { [api] origin in
            try await api.setArmingMode(origin, mode: mode, pin: pin, confirmUnassigned: confirmUnassigned)
        }
    }

    public func armPanel(_ node: String, mode: String, force: Bool, profile: String?, asker: ElevationAsker? = nil) async throws {
        try await guarded(reason: translator.trf("Armar %s", node), asker: asker) { [api] origin in
            try await api.sendAlarmCommand(origin, node: node, mode: mode, force: force, pin: nil, profile: profile)
        }
    }

    public func disarmPanel(_ node: String, pin: String?, asker: ElevationAsker? = nil) async throws {
        try await guarded(reason: translator.trf("Desarmar %s", node), asker: asker) { [api] origin in
            try await api.sendAlarmCommand(origin, node: node, mode: nil, force: false, pin: pin, profile: nil)
        }
    }

    public func silencePanel(_ node: String, pin: String?, asker: ElevationAsker? = nil) async throws {
        try await guarded(reason: translator.tr("Silenciar la alarma"), asker: asker) { [api] origin in try await api.silenceAlarmSiren(origin, node: node, pin: pin) }
    }

    public func acknowledge(_ id: String) async throws { try await guarded(reason: translator.tr("Confirmar"), asker: nil) { [api] origin in try await api.acknowledgeAlarm(origin, id: id) } }
    public func acknowledgeAll() async throws { try await guarded(reason: translator.tr("Confirmar todas"), asker: nil) { [api] origin in try await api.acknowledgeAllAlarms(origin) } }

    public func command(device: SiteDevice, command: String, confirmed: Bool, asker: ElevationAsker? = nil) async throws {
        try await guarded(reason: translator.tr("Dispositivos"), asker: asker) { [api] origin in try await api.commandDevice(origin, id: device.id, command: command, confirm: confirmed) }
    }

    // MARK: assistant

    /// One written command to the assistant. Arming and disarming need a second turn with the token of the first answer; that second turn is the person's confirmation and goes behind the lock.
    public func ask(_ text: String, confirmation: String?) async throws -> VoiceReply {
        let origin = try origin()
        if confirmation != nil, !(await gate.allow(reason: translator.tr("Confirmar"))) { throw ControllerError.lockRefused }
        return try await api.voiceCommand(origin, text: text, language: translator.language, confirmation: confirmation)
    }
}
