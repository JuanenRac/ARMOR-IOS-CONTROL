// ARMOR-IOS-CONTROL - the spoken turn: the phone listens to one phrase, sends it to the server as audio and shows the number of the challenge mode when the server asks for it.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
//
// OFF by default, and the only part of the app that ever opens the microphone. Until the person turns the switch on (More > Spoken command) nothing here records, asks for the permission or
// sends a sound: the Assistant keeps working with written commands and the keyboard's own dictation, which sends only text. With the switch on, one tap records up to ten seconds of 16 kHz
// mono sound, sends it with the voice token to `POST /api/v1/voice/turn` of the server and drops it; the sound is kept nowhere. When the security option `voice.silence_confirmation` is
// `challenge` the server answers a number that the person must say in the next turn; the phone shows it for nineteen seconds (as the wall panel does) and then removes it. Anything that is not
// exactly what the contract says - an answer that is not a voice reply, a number that is not two to six digits - shows nothing: the turn fails closed. Every decision is written to a short
// audit trail on the phone (no words, no sound). The voice token is the shared secret of the voice route: the person types it, and it is kept in the Keychain of this phone.
// This file is the same as SpokenTurn.kt of the Android app, rule for rule; the microphone itself (AVAudioEngine) is in the app, behind `TurnRecorder`.
import Foundation

/// The person's switch. Off until they turn it on.
public final class SpokenTurnSettings {
    private let store: KeyValueStore
    public init(_ store: KeyValueStore) { self.store = store }
    public var enabled: Bool {
        get { store.get("spoken_turn") == "1" }
        set { store.put("spoken_turn", newValue ? "1" : "0") }
    }
}

/// The voice token of the installation, in the Keychain. A token with spaces, control characters or more than 200 characters is not kept (it could not be a header value).
public final class VoiceTokenVault {
    public static let key = "voice_token"
    public static let maxLength = 200
    private let secrets: SecretStore
    public init(secrets: SecretStore) { self.secrets = secrets }

    public static func isValid(_ token: String) -> Bool {
        (8...maxLength).contains(token.unicodeScalars.count) && token.unicodeScalars.allSatisfy { (0x21...0x7E).contains($0.value) }
    }

    /// True when the token was kept. It is readable only while the phone is unlocked.
    @discardableResult
    public func save(_ token: String) -> Bool {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValid(clean) else { return false }
        secrets.write(Self.key, clean, tiedToUnlock: true)
        return true
    }

    /// The token, or nil when there is none or the phone is locked (what is kept is then left alone).
    public func load() -> String? {
        if case .value(let token) = secrets.read(Self.key), Self.isValid(token) { return token }
        return nil
    }

    public var has: Bool {
        if case .absent = secrets.read(Self.key) { return false }
        return true
    }

    public func clear() { secrets.remove(Self.key) }
}

/// The number of the challenge mode: two to six digits, nothing else.
public enum ChallengeNumber {
    /// The nineteen seconds the wall panel shows it for.
    public static let shownFor: TimeInterval = 19

    /// The number when `raw` is exactly two to six digits 0-9 (no sign, no space, no other script's digits), else nil.
    public static func parse(_ raw: String?) -> String? {
        guard let raw, (2...6).contains(raw.unicodeScalars.count), raw.unicodeScalars.allSatisfy({ (0x30...0x39).contains($0.value) }) else { return nil }
        return raw
    }
}

/// A number on the screen: it was shown at `shownAt` and is gone `ChallengeNumber.shownFor` seconds later.
public struct ShownChallenge: Equatable, Sendable {
    public let number: String
    public let shownAt: Date
    public init(number: String, shownAt: Date) { self.number = number; self.shownAt = shownAt }

    /// A clock that went back counts as expired.
    public func expired(_ now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(shownAt)
        return elapsed >= ChallengeNumber.shownFor || elapsed < 0
    }

    public func remaining(_ now: Date) -> TimeInterval { expired(now) ? 0 : ChallengeNumber.shownFor - now.timeIntervalSince(shownAt) }
}

/// What the server answers to a spoken turn, read as strictly as the shared contract (`voice_turn_result`): the two texts, and optionally the spoken answer, the note that it was left out
/// and the number of the challenge. Any other member, a member of another type or a number that is not two to six digits makes the whole answer invalid.
public struct VoiceTurnResult: Equatable, Sendable {
    public let heard: String
    public let reply: String
    public let challenge: String?

    public static func parse(_ root: JSON) -> VoiceTurnResult? {
        let allowed: Set<String> = ["heard", "reply", "audio", "audio_omitted", "challenge"]
        guard Set(root.keys).isSubset(of: allowed),
              let heard = root["heard"] as? String, let reply = root["reply"] as? String,
              heard.unicodeScalars.count <= 2000, reply.unicodeScalars.count <= 2000 else { return nil }
        if let audio = root["audio"] { guard let text = audio as? String, text.utf8.count <= 1_400_000 else { return nil } }
        if let omitted = root["audio_omitted"] { guard (omitted as? String) == "too_large" else { return nil } }
        var challenge: String?
        if let raw = root["challenge"] {
            guard let text = raw as? String, let number = ChallengeNumber.parse(text) else { return nil }
            challenge = number
        }
        return VoiceTurnResult(heard: heard, reply: reply, challenge: challenge)
    }
}

/// What came of one spoken turn.
public enum SpokenTurnOutcome: Equatable, Sendable {
    /// The switch is off: nothing was recorded or sent.
    case off
    /// No voice token was entered (or the phone is locked and cannot give it).
    case noToken
    /// The person refused the microphone permission: nothing was recorded.
    case permissionDenied
    /// Nothing, or half a sample, was recorded.
    case nothingHeard
    /// The server answered something that is not a voice reply, or a number that is not two to six digits: nothing is shown.
    case malformed
    /// The server refused or did not answer; `code` is its error code when it gave one.
    case failed(code: String?)
    case answered(heard: String, reply: String, challenge: ShownChallenge?)
}

/// The microphone, behind a protocol so the rules can be tested without a phone.
public protocol TurnRecorder: AnyObject {
    /// Whether the phone lets the app record. When the person has not been asked yet this asks them (the system's own dialog), so it is called only after the switch and the token were checked.
    func requestPermission() async -> Bool
    /// Records 16 kHz mono 16-bit little-endian sound until `shouldStop` is true or the longest turn is reached; empty when it could not start.
    func record(shouldStop: @escaping @Sendable () -> Bool) async -> Data
}

/// The short audit trail of the spoken turn on the phone: the last events, with their time and nothing that was said.
public protocol TurnAudit: AnyObject {
    func record(_ event: String)
}

public final class StoreTurnAudit: TurnAudit {
    public static let key = "spoken_turn_audit"
    public static let maxEntries = 50
    private let store: KeyValueStore
    private let clock: () -> Int
    public init(_ store: KeyValueStore, clock: @escaping () -> Int = { Int(Date().timeIntervalSince1970 * 1000) }) { self.store = store; self.clock = clock }

    public func record(_ event: String) {
        let clean = String(event.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == ":" }.map(Character.init)).prefix(40)
        store.put(Self.key, (entries() + ["\(clock())|\(clean)"]).suffix(Self.maxEntries).joined(separator: "\n"))
    }

    /// The trail, oldest first.
    public func entries() -> [String] { (store.get(Self.key) ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
}

/// What a turn needs from the server: the audio, the language and the voice token in, the JSON of the answer out.
public typealias TurnSender = @Sendable (_ origin: String, _ pcm: Data, _ language: String, _ voiceToken: String) async throws -> JSON

public final class SpokenTurnController {
    /// A tenth of a second: less than that is a tap, not a phrase.
    public static let minBytes = 3_200
    /// Ten seconds of 16 kHz 16-bit mono, well under the 15 seconds the server takes by default.
    public static let maxBytes = 320_000

    private let settings: SpokenTurnSettings
    private let tokens: VoiceTokenVault
    private let recorder: TurnRecorder
    private let send: TurnSender
    private let audit: TurnAudit
    private let clock: () -> Date

    public init(settings: SpokenTurnSettings, tokens: VoiceTokenVault, recorder: TurnRecorder, send: @escaping TurnSender, audit: TurnAudit, clock: @escaping () -> Date = Date.init) {
        self.settings = settings; self.tokens = tokens; self.recorder = recorder; self.send = send; self.audit = audit; self.clock = clock
    }

    /// One turn: checks the switch, the voice token and the permission - in that order, and the microphone is touched only after all three - records, sends and reads the answer.
    public func run(origin: String, language: String, shouldStop: @escaping @Sendable () -> Bool = { false }) async -> SpokenTurnOutcome {
        guard settings.enabled else { audit.record("blocked_switch_off"); return .off }
        guard let token = tokens.load() else { audit.record("no_token"); return .noToken }
        guard await recorder.requestPermission() else { return permissionRefused() }
        let sound = await recorder.record(shouldStop: shouldStop)
        guard sound.count >= Self.minBytes, sound.count % 2 == 0 else { audit.record("nothing_heard"); return .nothingHeard }
        let pcm = sound.count > Self.maxBytes ? sound.prefix(Self.maxBytes) : sound
        audit.record("sent")
        let json: JSON
        do { json = try await send(origin, Data(pcm), language, token) }
        catch {
            let code = Self.errorCode(error)
            audit.record("failed:" + String((code ?? "network").prefix(24)))
            return .failed(code: code)
        }
        guard let result = VoiceTurnResult.parse(json) else { audit.record("malformed_answer"); return .malformed }
        let shown = result.challenge.map { ShownChallenge(number: $0, shownAt: clock()) }
        audit.record(shown != nil ? "answered_challenge" : "answered")
        return .answered(heard: result.heard, reply: result.reply, challenge: shown)
    }

    /// The short code of a refusal: the voice routes answer `{"error":"unauthorized"}`, which ArmorApiError keeps as its detail; a `code` member wins when there is one.
    static func errorCode(_ error: Error) -> String? {
        guard let failure = error as? ArmorApiError else { return nil }
        if !failure.code.isEmpty { return failure.code }
        return failure.detail.range(of: #"^[a-z_]{1,40}$"#, options: .regularExpression) != nil ? failure.detail : nil
    }

    /// The system or the person refused the microphone after the person asked for a turn.
    public func permissionRefused() -> SpokenTurnOutcome { audit.record("permission_denied"); return .permissionDenied }
}

/// The words for what came of a turn (the conversation shows what was heard and said; this is for what did not work).
public enum SpokenTurnText {
    public static func notice(_ outcome: SpokenTurnOutcome, _ t: Translator) -> String? {
        switch outcome {
        case .off: return t.tr("La orden hablada está apagada: enciéndela en Ajustes.")
        case .noToken: return t.tr("Falta la clave de voz: escríbela en Ajustes.")
        case .permissionDenied: return t.tr("Sin permiso para el micrófono no puedo escucharte. Puedes escribir la orden.")
        case .nothingHeard: return t.tr("No he oído nada. Prueba otra vez.")
        case .malformed: return t.tr("La respuesta del servidor no es válida: no la muestro.")
        case .failed(let code):
            switch code {
            case "unauthorized": return t.tr("El servidor no acepta la clave de voz.")
            case "voice_unavailable": return t.tr("Este sistema no tiene instalado el asistente de voz.")
            case "voice_not_answering": return t.tr("El asistente de voz no responde ahora mismo.")
            default: return t.tr("No se pudo enviar la orden al servidor.")
            }
        case .answered: return nil
        }
    }
}
