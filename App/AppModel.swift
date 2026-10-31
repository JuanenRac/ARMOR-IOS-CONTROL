// ARMOR-IOS-CONTROL - the state the screens show. It owns the pieces (server link, vault, lock) and does nothing but call ArmorCore and publish the result.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import Network
import SwiftUI
import UserNotifications
import ArmorCore

enum Screen { case starting, locked, login, main }

struct Toast: Identifiable, Equatable { let id = UUID(); let text: String; let isError: Bool }

@MainActor
final class AppModel: ObservableObject {
    // pieces
    let prefs = PreferencesStore()
    let translator: Translator
    let trust: TrustDelegate
    let pins: PinStore
    let vault: SessionVault
    let lockSettings: LockSettings
    let policy: LockPolicy
    let gate: LockGate
    let controller: ArmorController
    private let monitor = NWPathMonitor()
    private var pollTask: Task<Void, Never>?

    // what the screens show
    @Published var screen: Screen = .starting
    @Published var language: String
    @Published var state = ArmorState()
    @Published var installation: SavedInstallation
    @Published var activeOrigin: String?
    @Published var place: NetworkPlace = .unknown
    @Published var networkAvailable = true
    @Published var problem: ReachProblem?
    @Published var busy = false
    @Published var toast: Toast?
    @Published var lockStatus: LockStatus
    @Published var needsCode: (challenge: String, username: String, password: String?)?
    @Published var voiceAvailable = false
    @Published var tiedToUnlock: Bool
    @Published var pendingElevation: ElevationRequest?
    @Published var rememberedUser: String = ""
    // what the person chose about the notices (kept in the preferences of the app)
    @Published var notices = NoticeSettings()
    @Published var sounds = SoundSettings()
    @Published var voice = VoiceSettings()
    @Published var speaksAlarms = false

    /// A screen asks the person to prove who they are again; the model waits for the answer.
    final class ElevationRequest: Identifiable {
        let id = UUID()
        let continuation: CheckedContinuation<(password: String, code: String)?, Never>
        init(_ continuation: CheckedContinuation<(password: String, code: String)?, Never>) { self.continuation = continuation }
    }

    init() {
        let pins = PinStore(prefs)
        let trust = TrustDelegate(pins: pins)
        let session = ArmorApiClient.makeSession(delegate: trust)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let api = ArmorApiClient(session: session, clientTag: version)
        let saved = prefs.get("language")
        let code = Translator.pick(saved: saved, phone: Locale.current.language.languageCode?.identifier ?? "en")
        let translator = Translator(language: code)
        let settings = LockSettings(prefs)
        let auth = PhoneAuth()
        let policy = LockPolicy(settings: settings, availability: { auth.availability() })
        let gate = LockGate(policy: policy, auth: auth, translator: translator)
        let vault = SessionVault(secrets: KeychainSecrets(), prefs: prefs)
        self.pins = pins; self.trust = trust; self.translator = translator; self.lockSettings = settings; self.policy = policy; self.gate = gate; self.vault = vault
        self.controller = ArmorController(api: api, vault: vault, gate: gate, lockSettings: settings, translator: translator)
        self.language = code
        self.installation = SavedInstallation.load(from: prefs)
        self.lockStatus = policy.status()
        self.notices = NoticePreferences.load(prefs)
        self.sounds = SoundPreferences.load(prefs)
        self.voice = VoicePreferences.load(prefs)
        self.speaksAlarms = VoicePreferences.speaks(prefs)
        self.tiedToUnlock = vault.tiedToUnlock
        monitor.pathUpdateHandler = { [weak self] path in
            let place: NetworkPlace = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) ? .home : (path.usesInterfaceType(.cellular) ? .away : .unknown)
            Task { @MainActor in self?.place = place; self?.networkAvailable = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "armor.network"))
    }

    func tr(_ es: String) -> String { _ = language; return translator.tr(es) }
    func trf(_ es: String, _ args: Any...) -> String { _ = language; return Translator.fill(translator.tr(es), args) }

    // MARK: start and lock

    func start() async {
        installPushHooks()
        refreshLock()
        if installation.endpoints.home == nil && installation.endpoints.away == nil { screen = .login; return }
        if policy.openRequired() { screen = .locked; return }
        await openKept()
    }

    /// Opens with the kept session when the server still honours it.
    func openKept() async {
        guard await connect() else { screen = .login; return }
        if let origin = activeOrigin, await controller.restore(origin: origin) { enterMain() }
        else { rememberedUser = activeOrigin.flatMap { vault.rememberedLogin(origin: $0)?.username } ?? ""; screen = .login }
    }

    /// Face ID / Touch ID / passcode to get in; the way out is `forgetAndSignInAgain`.
    func unlockToOpen() async {
        switch await gate.unlockToOpen() {
        case .success, .unavailable: await openKept()
        default: break
        }
    }

    /// "I cannot": forgets the session and the remembered login of this phone; the server and its alarms are not touched.
    func forgetAndSignInAgain() {
        vault.forgetAll()
        screen = .login
        refreshLock()
    }

    func refreshLock() { lockStatus = policy.status() }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive: policy.left()
        case .active:
            if screen == .main, policy.returned() { stopPolling(); screen = .locked }
            else if screen == .main { startPolling() }
        @unknown default: break
        }
        if phase == .background { stopPolling() }
    }

    // MARK: connection

    /// Chooses the address (private at home, the other away, the other one if the chosen does not answer).
    @discardableResult
    func connect() async -> Bool {
        let selection = await Connector.select(api: controller.api, installation: installation, place: place, networkAvailable: networkAvailable, pinMismatch: { [trust] in trust.takeMismatch() })
        switch selection {
        case .reached(let endpoint): activeOrigin = endpoint.origin; problem = nil; return true
        case .failed(let reason): activeOrigin = nil; problem = reason; return false
        }
    }

    func saveInstallation(_ new: SavedInstallation) {
        installation = new
        new.save(to: prefs)
    }

    var isAway: Bool {
        guard let origin = activeOrigin, let endpoint = ServerEndpoint.parse(origin) else { return false }
        return Reach.isAway(endpoint, installation: installation)
    }

    // MARK: sign in

    func signIn(username: String, password: String, remember: Bool) async {
        guard !username.isEmpty, !password.isEmpty else { show(tr("Escribe el usuario y la contraseña."), error: true); return }
        busy = true; defer { busy = false }
        guard await connect(), let origin = activeOrigin else { show(problem?.message(translator) ?? tr("La dirección del servidor no es válida."), error: true); return }
        do {
            let outcome = try await controller.signIn(origin: origin, username: username, password: password, remember: remember)
            switch outcome {
            case .done: enterMain()
            case .needsCode(let challenge): needsCode = (challenge, username, remember ? password : nil)
            }
        } catch let error as ArmorApiError { show(describe(error), error: true) }
        catch { show(error.localizedDescription, error: true) }
    }

    func submitCode(_ code: String) async {
        guard let pending = needsCode, let origin = activeOrigin else { return }
        busy = true; defer { busy = false }
        do {
            try await controller.completeSignIn(origin: origin, challenge: pending.challenge, code: code.trimmingCharacters(in: .whitespaces), username: pending.username, password: pending.password)
            needsCode = nil
            enterMain()
        } catch let error as ArmorApiError {
            show(error.status == 401 || error.status == 400 || error.status == 403 ? tr("Ese código no es correcto.") : describe(error), error: true)
        } catch { show(error.localizedDescription, error: true) }
    }

    func signOut() async {
        stopPolling()
        if let origin = activeOrigin, let token = prefs.get("push_token") { try? await controller.api.unregisterPush(origin, token: token) }
        await controller.signOut()
        state = controller.state
        screen = .login
    }

    private func enterMain() {
        state = controller.state
        screen = .main
        Task { await refresh() }
        Task { voiceAvailable = ((try? await controller.api.voiceAvailable(activeOrigin ?? "")) ?? false) }
        startPolling()
        requestNotificationPermission()
        Task { await registerPush() }
    }

    // MARK: push

    /// The app that the Firebase file of the installation lets receive pushes: the delegate calls these.
    func installPushHooks() {
        AppDelegate.onPush = { [weak self] in await self?.refresh() }
        AppDelegate.onToken = { [weak self] token in Task { @MainActor in self?.prefs.put("push_token", token); await self?.registerPush() } }
    }

    /// Tells the server the token of this phone (a server with push off answers 409, which is not a failure).
    func registerPush() async {
        guard screen == .main, let origin = activeOrigin, let token = prefs.get("push_token") else { return }
        try? await controller.api.registerPush(origin, token: token)
    }

    // MARK: polling and notices

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let seconds: UInt64 = (self?.isAway ?? false) ? 10 : 5
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            }
        }
    }

    func stopPolling() { pollTask?.cancel(); pollTask = nil }

    func refresh() async {
        let notices = await controller.refresh()
        state = controller.state
        if !state.signedIn, screen == .main { stopPolling(); screen = .login; show(tr("La sesión ha caducado: inicia sesión de nuevo"), error: true) }
        for notice in notices { post(notice) }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared   // the notices also show while the app is open
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func post(_ notice: AlarmNotice) {
        // What the person chose comes first: some notices are not wanted at all, and some are wanted without sound.
        let decision = notices.decide(notice)
        if decision == .hide { return }
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.text
        content.threadIdentifier = "armor-alarms"
        let critical = notice.severity == "critical"
        if decision == .silent {
            content.sound = nil
            content.interruptionLevel = .passive
        } else {
            content.interruptionLevel = critical ? .timeSensitive : .active
            if let file = sounds.fileFor(severity: notice.severity, kind: notice.kind), AlarmSounds.shared.exists(file) {
                let name = UNNotificationSoundName(rawValue: file)
                content.sound = critical ? UNNotificationSound.criticalSoundNamed(name) : UNNotificationSound(named: name)
            } else {
                content.sound = critical ? .defaultCritical : .default
            }
        }
        let request = UNNotificationRequest(identifier: "armor-\(notice.id)", content: content, trigger: nil)   // the event id: a push for the same event replaces it
        UNUserNotificationCenter.current().add(request)
        if AlarmSpeech.shouldSpeak(decision, enabled: speaksAlarms, voice: voice, severity: notice.severity) {
            AlarmSpeaker.shared.say("\(notice.title). \(notice.text)", voice: voice, language: language)
        }
    }

    func setNotices(_ next: NoticeSettings) { notices = next; NoticePreferences.save(prefs, next) }
    func setVoice(_ next: VoiceSettings) { voice = next; VoicePreferences.save(prefs, next) }
    func setSpeaksAlarms(_ on: Bool) { speaksAlarms = on; VoicePreferences.setSpeaks(prefs, on) }
    func setSounds(_ next: SoundSettings) {
        sounds = next
        SoundPreferences.save(prefs, next)
        AlarmSounds.shared.prune(keeping: next)
    }

    // MARK: orders

    /// Runs an order of the controller, with the proof of identity asked on a screen if the server wants it, and the result said in words.
    @discardableResult
    func order(_ done: String? = nil, _ action: @escaping (ElevationAsker) async throws -> Void) async -> Bool {
        busy = true; defer { busy = false }
        let asker: ElevationAsker = { [weak self] in
            guard let self else { return nil }
            return await withCheckedContinuation { continuation in
                Task { @MainActor in self.pendingElevation = ElevationRequest(continuation) }
            }
        }
        do {
            try await action(asker)
            state = controller.state
            if let done { show(done, error: false) }
            return true
        } catch let error as ControllerError {
            switch error {
            case .lockRefused: show(tr("No se ha confirmado con el bloqueo del teléfono: no se ha hecho nada."), error: true)
            case .readOnly: show(tr("Tu usuario solo puede mirar: no puede cambiar nada."), error: true)
            case .notSignedIn: show(tr("Inicia sesión primero."), error: true)
            case .elevationDeclined: show(tr("No se ha hecho nada: hace falta confirmar tu identidad."), error: true)
            }
            return false
        } catch let error as ArmorApiError { show(describe(error), error: true); return false }
        catch { show(error.localizedDescription, error: true); return false }
    }

    /// Arms in a mode of the server. Returns nil when it was done, else the code of the refusal the picker answers by asking more (`no_zones_assigned`, `wrong_pin`, `pin_locked`,
    /// `pin_not_set`); any other failure is shown in words and returns "failed". The elevation and the lock of the phone work as for every order.
    func armInMode(_ mode: String, pin: String?, confirmUnassigned: Bool) async -> String? {
        final class Refusal: @unchecked Sendable { var code: String? }
        let refusal = Refusal()
        let done = await order(nil) { asker in
            do { try await self.controller.armInMode(mode, pin: pin, confirmUnassigned: confirmUnassigned, asker: asker) }
            catch let error as ArmorApiError where ArmingText.isAskable(error.code) { refusal.code = error.code }
        }
        if let code = refusal.code { return code }
        guard done else { return "failed" }
        show(trf("Sistema armado: %s", ArmingText.name(mode, translator)), error: false)
        return nil
    }

    func answerElevation(_ request: ElevationRequest, password: String, code: String) {
        pendingElevation = nil
        request.continuation.resume(returning: (password, code))
    }

    func declineElevation(_ request: ElevationRequest) {
        pendingElevation = nil
        request.continuation.resume(returning: nil)
    }

    /// An error of the server in the words of the person.
    func describe(_ error: ArmorApiError) -> String {
        switch error.code {
        case "wrong_pin": return tr("El PIN no es correcto")
        case "pin_locked": return tr("Demasiados PIN erróneos: espera un poco")
        case "pin_not_set": return tr("Este usuario no tiene PIN: lo pone un administrador")
        default: break
        }
        switch error.status {
        case nil: return problem?.message(translator) ?? tr("No se puede conectar con el servidor. Comprueba que el móvil esté en la misma wifi y que la dirección es correcta.")
        case 401: return tr("Usuario o contraseña incorrectos.")
        case 403: return tr("Solo un administrador puede armar las centrales.")
        case 404: return tr("El servidor no tiene lo que se pide. Puede que necesite actualizarse.")
        case 429: return tr("Demasiados códigos erróneos: espera un poco y vuelve a intentarlo.")
        case let code? where code >= 500: return tr("El servidor tiene un problema. Inténtalo de nuevo en un momento.")
        default: return trf("El servidor respondió HTTP %s", error.status ?? 0)
        }
    }

    func show(_ text: String, error: Bool) {
        let item = Toast(text: text, isError: error)
        toast = item
        Task { try? await Task.sleep(nanoseconds: 4_000_000_000); if toast == item { toast = nil } }
    }

    // MARK: settings

    func chooseLanguage(_ code: String) {
        translator.select(code)
        language = translator.language
        prefs.put("language", language)
    }

    /// Changing the lock itself asks the lock first: turning it on proves it works on this phone, turning it off proves it is the person.
    func setSensitiveLock(_ on: Bool) async {
        switch await gate.prove() {
        case .success, .unavailable: lockSettings.setSensitive(on)
        default: show(tr("No se ha cambiado: no se pudo comprobar con el bloqueo del teléfono."), error: true)
        }
        refreshLock()
    }

    func setOpenLock(_ on: Bool) async {
        switch await gate.prove() {
        case .success, .unavailable: lockSettings.openApp = on
        default: show(tr("No se ha cambiado: no se pudo comprobar con el bloqueo del teléfono."), error: true)
        }
        refreshLock()
    }

    func setGrace(_ seconds: Int) { lockSettings.graceSeconds = seconds; refreshLock() }

    func setTiedToUnlock(_ on: Bool) async {
        switch await gate.prove() {
        case .success, .unavailable:
            if !vault.setTiedToUnlock(on) { show(tr("No se ha cambiado: no se pudo comprobar con el bloqueo del teléfono."), error: true) }
        default: show(tr("No se ha cambiado: no se pudo comprobar con el bloqueo del teléfono."), error: true)
        }
        tiedToUnlock = vault.tiedToUnlock
    }

    /// Pairs the pin that a QR code of Studio carries.
    func pair(qr text: String) -> Bool {
        guard let parsed = PinStore.parseQr(text) else { return false }
        let hosts = [installation.endpoints.away, installation.endpoints.home].compactMap { endpoint -> String? in
            guard let endpoint, let url = URL(string: endpoint.origin) else { return nil }
            return url.host
        }
        for host in (parsed.host.map { [$0] } ?? hosts) { pins.add(parsed.pin, for: host) }
        return true
    }

    func forgetPins() {
        for endpoint in [installation.endpoints.home, installation.endpoints.away] {
            if let endpoint, let host = URL(string: endpoint.origin)?.host { pins.clear(for: host) }
        }
    }
}
