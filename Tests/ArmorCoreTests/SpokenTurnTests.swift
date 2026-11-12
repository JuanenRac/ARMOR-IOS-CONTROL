import XCTest
@testable import ArmorCore

/// A microphone that counts how often it was asked and gives a fixed sound.
private final class CountingRecorder: TurnRecorder, @unchecked Sendable {
    var granted = true
    var sound = Data(count: 6_400)
    var permissionCalls = 0
    var recordCalls = 0
    func requestPermission() async -> Bool { permissionCalls += 1; return granted }
    func record(shouldStop: @escaping @Sendable () -> Bool) async -> Data { recordCalls += 1; return sound }
}

private final class ListAudit: TurnAudit {
    var events: [String] = []
    func record(_ event: String) { events.append(event) }
}

/// What the closure sent to the server saw and what it answers.
private final class Wire: @unchecked Sendable {
    var sent = 0
    var sentSize = -1
    var answer: () throws -> JSON = { ["heard": "silencia la alarma", "reply": "Dime el número del panel"] }
}

final class SpokenTurnTests: XCTestCase {
    private let store = MemoryStore()
    private let secrets = MemorySecrets()
    private var settings: SpokenTurnSettings!
    private var tokens: VoiceTokenVault!
    private let recorder = CountingRecorder()
    private let audit = ListAudit()
    private let wire = Wire()
    private var now = Date(timeIntervalSince1970: 1_000)
    private var controller: SpokenTurnController!

    override func setUp() {
        settings = SpokenTurnSettings(store)
        tokens = VoiceTokenVault(secrets: secrets)
        let wire = self.wire
        controller = SpokenTurnController(settings: settings, tokens: tokens, recorder: recorder, send: { _, pcm, _, _ in
            wire.sent += 1; wire.sentSize = pcm.count; return try wire.answer()
        }, audit: audit, clock: { [unowned self] in self.now })
    }

    private func ready() { settings.enabled = true; XCTAssertTrue(tokens.save("a-voice-token-1234")) }

    func testTheSwitchIsOffUntilThePersonTurnsItOn() {
        XCTAssertFalse(settings.enabled)
        settings.enabled = true
        XCTAssertTrue(SpokenTurnSettings(store).enabled)
        settings.enabled = false
        XCTAssertFalse(SpokenTurnSettings(store).enabled)
    }

    func testWithTheSwitchOffTheMicrophoneIsNeverOpenedThePermissionNeverAskedAndNothingIsSent() async {
        _ = tokens.save("a-voice-token-1234")
        let outcome = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(outcome, .off)
        XCTAssertEqual(recorder.permissionCalls, 0)
        XCTAssertEqual(recorder.recordCalls, 0)
        XCTAssertEqual(wire.sent, 0)
        XCTAssertEqual(audit.events, ["blocked_switch_off"])
    }

    func testWithoutAVoiceTokenNothingIsRecordedAndThePermissionIsNotAsked() async {
        settings.enabled = true
        let outcome = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(outcome, .noToken)
        XCTAssertEqual(recorder.permissionCalls, 0)
        XCTAssertEqual(recorder.recordCalls, 0)
        XCTAssertEqual(audit.events, ["no_token"])
    }

    func testALockedPhoneThatCannotGiveTheTokenIsTreatedAsNoToken() async {
        ready()
        secrets.phoneLocked = true
        let outcome = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(outcome, .noToken)
        XCTAssertEqual(recorder.recordCalls, 0)
        XCTAssertTrue(tokens.has, "what is kept stays kept")
    }

    func testADeniedMicrophonePermissionEndsTheTurnBeforeAnythingIsRecordedOrSent() async {
        ready()
        recorder.granted = false
        let outcome = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(outcome, .permissionDenied)
        XCTAssertEqual(recorder.permissionCalls, 1)
        XCTAssertEqual(recorder.recordCalls, 0)
        XCTAssertEqual(wire.sent, 0)
        XCTAssertEqual(audit.events.last, "permission_denied")
        XCTAssertNotNil(SpokenTurnText.notice(.permissionDenied, Translator(language: "es", loader: { _ in [:] })))
    }

    func testATapOrHalfASampleIsNothingHeardAndIsNotSent() async {
        ready()
        for size in [0, 100, 3_199, 6_401] {
            recorder.sound = Data(count: size)
            let outcome = await controller.run(origin: "http://h", language: "es")
            XCTAssertEqual(outcome, .nothingHeard, "\(size) bytes")
        }
        XCTAssertEqual(wire.sent, 0)
    }

    func testATurnIsSentOnceAndTheAnswerIsRead() async {
        ready()
        wire.answer = { ["heard": "estado", "reply": "Todo en orden"] }
        let outcome = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(outcome, .answered(heard: "estado", reply: "Todo en orden", challenge: nil))
        XCTAssertEqual(wire.sent, 1)
        XCTAssertEqual(audit.events, ["sent", "answered"])
    }

    func testTheSoundIsCutAtTenSeconds() async {
        ready()
        recorder.sound = Data(count: 400_000)
        _ = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(wire.sentSize, SpokenTurnController.maxBytes)
    }

    func testTheNumberOfTheChallengeIsShownFromTheMomentItArrives() async {
        ready()
        wire.answer = { ["heard": "silencia", "reply": "Di el número que ves en el panel", "challenge": "4821"] }
        now = Date(timeIntervalSince1970: 5_000)
        let outcome = await controller.run(origin: "http://h", language: "es")
        guard case .answered(_, let reply, let challenge) = outcome else { return XCTFail("not answered: \(outcome)") }
        XCTAssertEqual(challenge, ShownChallenge(number: "4821", shownAt: Date(timeIntervalSince1970: 5_000)))
        XCTAssertFalse(reply.contains("4821"))
        XCTAssertEqual(audit.events.last, "answered_challenge")
    }

    func testTheNumberExpiresAfterNineteenSecondsAndNotBefore() {
        let shown = ShownChallenge(number: "4821", shownAt: Date(timeIntervalSince1970: 10_000))
        func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 10_000 + seconds) }
        XCTAssertFalse(shown.expired(at(0)))
        XCTAssertFalse(shown.expired(at(18.999)))
        XCTAssertTrue(shown.expired(at(19)))
        XCTAssertTrue(shown.expired(at(60)))
        XCTAssertEqual(shown.remaining(at(0)), 19, accuracy: 0.001)
        XCTAssertEqual(shown.remaining(at(18.5)), 0.5, accuracy: 0.001)
        XCTAssertEqual(shown.remaining(at(19)), 0)
    }

    func testAClockThatGoesBackMakesTheNumberExpireInsteadOfLiveLonger() {
        XCTAssertTrue(ShownChallenge(number: "4821", shownAt: Date(timeIntervalSince1970: 10_000)).expired(Date(timeIntervalSince1970: 9_000)))
    }

    func testANumberThatIsNotTwoToSixPlainDigitsFailsClosed() async {
        ready()
        for bad in ["4", "1234567", "12a", "٣٤", "-12", " 12", "12 ", "12\n", "1.5", "", "０１２"] {
            wire.answer = { ["heard": "silencia", "reply": "x", "challenge": bad] }
            let outcome = await controller.run(origin: "http://h", language: "es")
            XCTAssertEqual(outcome, .malformed, "challenge '\(bad)'")
        }
        XCTAssertTrue(audit.events.contains("malformed_answer"))
        XCTAssertNotNil(SpokenTurnText.notice(.malformed, Translator(language: "es", loader: { _ in [:] })))
    }

    func testANumberThatIsNotAStringFailsClosed() async {
        ready()
        wire.answer = { ["heard": "a", "reply": "b", "challenge": 4821] }
        let number = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(number, .malformed)
        wire.answer = { ["heard": "a", "reply": "b", "challenge": NSNull()] }
        let null = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(null, .malformed)
    }

    func testAnAnswerThatIsNotAVoiceReplyFailsClosed() async {
        ready()
        let bad: [JSON] = [[:], ["heard": "a"], ["heard": 1, "reply": "b"], ["heard": "a", "reply": "b", "extra": 1], ["heard": "a", "reply": "b", "audio_omitted": "always"], ["heard": "a", "reply": "b", "audio": 5]]
        for answer in bad {
            wire.answer = { answer }
            let outcome = await controller.run(origin: "http://h", language: "es")
            XCTAssertEqual(outcome, .malformed, "\(answer)")
        }
        XCTAssertEqual(VoiceTurnResult.parse(["heard": "a", "reply": "b", "audio": "AAAA", "audio_omitted": "too_large"]), VoiceTurnResult(heard: "a", reply: "b", challenge: nil))
    }

    func testOnlyDigitsPassTheChallengeNumberReader() {
        XCTAssertEqual(ChallengeNumber.parse("48"), "48")
        XCTAssertEqual(ChallengeNumber.parse("123456"), "123456")
        XCTAssertNil(ChallengeNumber.parse(nil))
        XCTAssertNil(ChallengeNumber.parse("1"))
        XCTAssertNil(ChallengeNumber.parse("1234567"))
    }

    func testARefusalOfTheServerIsToldByItsCode() async {
        ready()
        let t = Translator(language: "es", loader: { _ in [:] })
        wire.answer = { throw ArmorApiError(message: "x", status: 401, body: #"{"error":"unauthorized"}"#) }
        let refused = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(refused, .failed(code: "unauthorized"))
        XCTAssertEqual(SpokenTurnText.notice(refused, t), "El servidor no acepta la clave de voz.")
        XCTAssertEqual(audit.events.last, "failed:unauthorized")
        wire.answer = { throw URLError(.timedOut) }
        let lost = await controller.run(origin: "http://h", language: "es")
        XCTAssertEqual(lost, .failed(code: nil))
        XCTAssertEqual(audit.events.last, "failed:network")
        XCTAssertNotNil(SpokenTurnText.notice(lost, t))
    }

    func testEveryOutcomeThatDidNotWorkHasWords() {
        let t = Translator(language: "es", loader: { _ in [:] })
        for outcome in [SpokenTurnOutcome.off, .noToken, .permissionDenied, .nothingHeard, .malformed, .failed(code: "x"), .failed(code: nil)] {
            XCTAssertFalse((SpokenTurnText.notice(outcome, t) ?? "").isEmpty, "\(outcome)")
        }
        XCTAssertNil(SpokenTurnText.notice(.answered(heard: "a", reply: "b", challenge: nil), t))
    }

    // MARK: the voice token

    func testAVoiceTokenIsKeptInTheKeychainAndReadBack() {
        XCTAssertFalse(tokens.has)
        XCTAssertTrue(tokens.save("  a-voice-token-1234  "))
        XCTAssertEqual(tokens.load(), "a-voice-token-1234")
        XCTAssertEqual(secrets.items[VoiceTokenVault.key]?.tied, true, "readable only while the phone is unlocked")
        tokens.clear()
        XCTAssertFalse(tokens.has)
        XCTAssertNil(tokens.load())
    }

    func testATokenThatCouldNotBeAHeaderValueIsNotKept() {
        for bad in ["", "short", "has space inside1", "tab\tinside1234", "new\nline12345", "ñandú-token-123", String(repeating: "x", count: 201)] {
            XCTAssertFalse(tokens.save(bad), bad)
        }
        XCTAssertFalse(tokens.has)
        XCTAssertTrue(tokens.save(String(repeating: "x", count: 200)))
    }

    // MARK: the audit trail

    func testTheAuditTrailKeepsTheLastFiftyEventsAndNoWords() {
        var tick = 0
        let trail = StoreTurnAudit(MemoryStore(), clock: { tick += 1; return tick })
        for index in 0..<60 { trail.record("event_\(index)") }
        let entries = trail.entries()
        XCTAssertEqual(entries.count, StoreTurnAudit.maxEntries)
        XCTAssertEqual(entries.first, "11|event_10")
        XCTAssertEqual(entries.last, "60|event_59")
        trail.record("heard: silencia\nla alarma, 1234")
        XCTAssertEqual(trail.entries().last, "61|heardsilencialaalarma1234")
        XCTAssertFalse(trail.entries().last!.contains(" "))
    }

    // MARK: the client: what goes on the wire

    func testTheClientSendsTheSoundRawWithTheVoiceTokenAndNotTheSession() async throws {
        let session = ArmorApiClient.makeSession()
        let client = ArmorApiClient(session: session, clientTag: "test")
        let request = try client.voiceTurnRequest("http://127.0.0.1:1", pcm: Data(repeating: 0x41, count: 1_000), language: "es", voiceToken: "a-voice-token-1234")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/voice/turn")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Armor-Voice-Token"), "a-voice-token-1234")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Armor-Language"), "es")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "audio/L16;rate=16000")
        XCTAssertEqual(request.httpBody?.count, 1_000)
    }
}
