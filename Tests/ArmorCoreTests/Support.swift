import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

func fixture(_ name: String) throws -> JSON {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else { throw ArmorApiError(message: "no fixture \(name)", status: nil) }
    return try Json.object(try Data(contentsOf: url))
}

func plain(_ code: String = "es") -> Translator { Translator(language: code, loader: { _ in [:] }) }

/// A phone whose lock answers what the test says and counts the questions.
final class FakeAuth: DeviceAuth, @unchecked Sendable {
    var kind: LockAvailability
    var answer: AuthResult
    private(set) var asked = 0
    init(_ kind: LockAvailability = .biometric, answer: AuthResult = .success) { self.kind = kind; self.answer = answer }
    func availability() -> LockAvailability { kind }
    func authenticate(title: String, subtitle: String) async -> AuthResult { asked += 1; return answer }
}

/// A server that refuses nothing and records the orders it gets; a test overrides what it needs.
class FakeApi: ArmorApi, @unchecked Sendable {
    var calls: [String] = []
    var modeError: ArmorApiError?
    var modeErrorOnce = false
    var facts = SessionFacts(role: "admin", deviceLock: "user")
    var statusMode = "disarmed"
    var historyEvents: [ArmorEvent] = []
    var cookie: SessionCookie? = SessionCookie(name: "armor_studio_sid", value: "abc")
    var signInResult: SignIn = .done
    var unreachable = Set<String>()
    var jar: SessionCookie?

    func reach(_ origin: String) throws {
        if unreachable.contains(origin) { throw ArmorApiError(message: "timeout", status: nil) }
    }
    func status(_ origin: String) async throws -> ArmorSnapshot { calls.append("status"); return ArmorSnapshot(mode: statusMode) }
    func history(_ origin: String, limit: Int, before: Int?, after: Int?) async throws -> [ArmorEvent] { calls.append("history"); return historyEvents }
    func preflight(_ origin: String) async throws -> Preflight { Preflight(ready: true, issues: []) }
    func setMode(_ origin: String, mode: String, pin: String?) async throws {
        calls.append("mode:\(mode):\(pin ?? "-")")
        if let error = modeError { if modeErrorOnce { modeError = nil }; throw error }
        statusMode = mode
    }
    func alarms(_ origin: String) async throws -> (active: [Alarm], recent: [Alarm]) { calls.append("alarms"); return ([], []) }
    func acknowledgeAlarm(_ origin: String, id: String) async throws { calls.append("ack:\(id)") }
    func acknowledgeAllAlarms(_ origin: String) async throws { calls.append("ackall") }
    func alarmPanels(_ origin: String) async throws -> [AlarmPanelView] { [] }
    func armProfiles(_ origin: String) async throws -> [ArmProfileView] { [] }
    func alarmCommandsEnabled(_ origin: String) async throws -> Bool { true }
    func sendAlarmCommand(_ origin: String, node: String, mode: String?, force: Bool, pin: String?, profile: String?) async throws {
        calls.append("panel:\(node):\(mode ?? "disarm"):\(pin ?? "-")")
    }
    func silenceAlarmSiren(_ origin: String, node: String, pin: String?) async throws { calls.append("silence:\(node)") }
    func devices(_ origin: String) async throws -> [SiteDevice] { [] }
    func commandDevice(_ origin: String, id: String, command: String, confirm: Bool) async throws { calls.append("device:\(id):\(command)") }
    func cameraViews(_ origin: String) async throws -> [CameraView] { [] }
    func cameraStatus(_ origin: String) async throws -> [CameraHealth] { [] }
    func streamTicket(_ origin: String, cameraId: String, quality: String) async throws -> String { origin + "/api/v1/cameras/\(cameraId)/stream?ticket=t" }
    func snapshot(_ origin: String, cameraId: String) async throws {}
    func ptz(_ origin: String, cameraId: String, command: String) async throws {}
    func voiceAvailable(_ origin: String) async throws -> Bool { true }
    func voiceCommand(_ origin: String, text: String, language: String, confirmation: String?) async throws -> VoiceReply {
        calls.append("voice:\(text):\(language):\(confirmation ?? "-")")
        return VoiceReply(accepted: true, executed: confirmation != nil, intent: "arm", outcome: confirmation == nil ? "confirmation-needed" : "accepted", speech: "ok",
                          confirmationToken: confirmation == nil ? "tok" : nil)
    }
    func signIn(_ origin: String, username: String, password: String) async throws -> SignIn { try reach(origin); calls.append("signin:\(username)"); return signInResult }
    func completeSignIn(_ origin: String, challenge: String, code: String) async throws { calls.append("totp:\(challenge):\(code)") }
    func sessionFacts(_ origin: String) async throws -> SessionFacts { try reach(origin); return facts }
    func closeSession(_ origin: String) async throws { calls.append("close") }
    func elevate(_ origin: String, password: String, code: String) async throws { calls.append("elevate:\(password):\(code)") }
    func sessionCookie(_ origin: String) -> SessionCookie? { jar ?? cookie }
    func restoreSessionCookie(_ origin: String, _ cookie: SessionCookie) { jar = cookie; calls.append("restore") }
    func forgetSession(_ origin: String) { jar = nil; cookie = nil; calls.append("forget") }
    func registerPush(_ origin: String, token: String) async throws {}
    func unregisterPush(_ origin: String, token: String) async throws {}
}

func makeController(api: FakeApi = FakeApi(), auth: FakeAuth = FakeAuth(), language: String = "es") -> (ArmorController, FakeApi, FakeAuth, LockSettings, SessionVault) {
    let prefs = MemoryStore()
    let settings = LockSettings(prefs)
    let policy = LockPolicy(settings: settings, availability: { auth.availability() }, clock: { 0 })
    let translator = plain(language)
    let gate = LockGate(policy: policy, auth: auth, translator: translator)
    let vault = SessionVault(secrets: MemorySecrets(), prefs: prefs)
    return (ArmorController(api: api, vault: vault, gate: gate, lockSettings: settings, translator: translator), api, auth, settings, vault)
}
