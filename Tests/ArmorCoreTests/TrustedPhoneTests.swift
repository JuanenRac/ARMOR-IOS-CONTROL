// ARMOR-IOS-CONTROL - the trusted phone: off by default, registered only when the person asked and the server offers it, a session renewed by signing a challenge, and forgotten when it is ended
// (the same cases as the Android app).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import XCTest
@testable import ArmorCore

final class TrustedPhoneTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private let issued = "0123456789abcdef01234567"

    private func make(enabled: Bool = true, signer: FakeSigner = FakeSigner(), api: FakeApi = FakeApi()) -> (TrustedPhone, FakeApi, FakeSigner, TrustedPhoneSettings) {
        let settings = TrustedPhoneSettings(MemoryStore())
        settings.enabled = enabled
        return (TrustedPhone(api: api, signer: signer, settings: settings, phoneName: { "Ana's iPhone" }), api, signer, settings)
    }

    func testItIsOffUntilThePersonTurnsItOnAndAskedNothingOfTheServer() async {
        let (phone, api, _, settings) = make(enabled: false)
        XCTAssertFalse(settings.enabled)
        XCTAssertFalse(phone.wanted())
        let result = await phone.register(origin, offered: true)
        XCTAssertEqual(result, .off)
        let renewed = await phone.renew(origin)
        XCTAssertFalse(renewed)
        XCTAssertTrue(api.calls.isEmpty)
        XCTAssertFalse(TrustedPhoneSettings(MemoryStore()).enabled)
    }

    func testItIsNotRegisteredWhenTheServerDoesNotOfferItOrThePhoneHasNoKey() async {
        let (phone, api, _, _) = make()
        let notOffered = await phone.register(origin, offered: false)
        XCTAssertEqual(notOffered, .unavailable)
        let (bare, _, signer, _) = make(signer: FakeSigner())
        signer.isAvailable = false
        let noKey = await bare.register(origin, offered: true)
        XCTAssertEqual(noKey, .unavailable)
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testRegisteringKeepsTheIdTheServerGaveAndDoesNotAskTwice() async {
        let (phone, api, _, settings) = make()
        let first = await phone.register(origin, offered: true)
        XCTAssertEqual(first, .done)
        XCTAssertEqual(settings.id(origin), issued)
        XCTAssertEqual(api.calls, ["trust-register:Ana's iPhone:BASE64KEY"])
        let second = await phone.register(origin, offered: true)
        XCTAssertEqual(second, .done)
        XCTAssertEqual(api.calls.count, 1)
        XCTAssertNil(settings.id("http://other.example"))
    }

    func testAnIdThatIsNotTwentyFourHexDigitsIsNotKept() async {
        let api = FakeApi()
        api.trustIssuedId = "../etc"
        let (phone, _, _, settings) = make(api: api)
        let result = await phone.register(origin, offered: true)
        XCTAssertEqual(result, .failed)
        XCTAssertNil(settings.id(origin))
    }

    func testTheServerAskingForProofOrRefusingIsTold() async {
        let proof = FakeApi()
        proof.trustRegisterError = ArmorApiError(message: "x", status: 403, body: "{\"code\":\"elevation_required\"}")
        let (askedPhone, _, _, _) = make(api: proof)
        let needs = await askedPhone.register(origin, offered: true)
        XCTAssertEqual(needs, .needsProof)
        let refused = FakeApi()
        refused.trustRegisterError = ArmorApiError(message: "x", status: 409, body: "{\"code\":\"too_many_devices\"}")
        let (refusedPhone, _, _, settings) = make(api: refused)
        let failed = await refusedPhone.register(origin, offered: true)
        XCTAssertEqual(failed, .failed)
        XCTAssertNil(settings.id(origin))
    }

    func testTheSessionIsRenewedBySigningTheChallengeOfThatPhoneOnly() async {
        let (phone, api, signer, settings) = make()
        _ = await phone.register(origin, offered: true)
        let renewed = await phone.renew(origin)
        XCTAssertTrue(renewed)
        XCTAssertEqual(signer.signed, ["armor-device-trust-v1|\(issued)|challenge-1"])
        XCTAssertEqual(api.calls.suffix(2), ["trust-challenge:\(issued)", "trust-session:\(issued):challenge-1:\(Data([1, 2, 3]).base64EncodedString())"])
        XCTAssertEqual(settings.id(origin), issued)
        XCTAssertEqual(trustedSignedText(id: "a", challenge: "b"), "armor-device-trust-v1|a|b")
    }

    func testAPhoneNotRegisteredHereAsksNothing() async {
        let (phone, api, _, _) = make()
        let renewed = await phone.renew(origin)
        XCTAssertFalse(renewed)
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testALockedPhoneKeepsItsIdAndTriesAgainLater() async {
        let (phone, _, signer, settings) = make()
        _ = await phone.register(origin, offered: true)
        signer.signature = nil
        let renewed = await phone.renew(origin)
        XCTAssertFalse(renewed)
        XCTAssertEqual(settings.id(origin), issued)
    }

    func testAServerThatNoLongerKnowsThePhoneMakesItForgetTheIdButNotWhenItCannotBeReached() async {
        let gone = FakeApi()
        let (phone, _, _, settings) = make(api: gone)
        _ = await phone.register(origin, offered: true)
        gone.trustChallengeError = ArmorApiError(message: "x", status: nil)
        let unreachable = await phone.renew(origin)
        XCTAssertFalse(unreachable)
        XCTAssertEqual(settings.id(origin), issued, "a server that could not be reached leaves everything as it is")
        gone.trustChallengeError = ArmorApiError(message: "x", status: 404, body: "{\"code\":\"unknown_device\"}")
        let ended = await phone.renew(origin)
        XCTAssertFalse(ended)
        XCTAssertNil(settings.id(origin))
    }

    func testEndingTheTrustTellsTheServerForgetsTheIdAndCanDropTheKey() async {
        let (phone, api, signer, settings) = make()
        _ = await phone.register(origin, offered: true)
        await phone.end(origin)
        XCTAssertEqual(api.calls.last, "trust-remove:\(issued)")
        XCTAssertNil(settings.id(origin))
        XCTAssertFalse(signer.forgotten)
        await phone.end(origin, dropKey: true)
        XCTAssertTrue(signer.forgotten)
    }

    func testTheServerOptionIsReadFromTheCapabilitiesOfTheSession() throws {
        let on = try Json.object(Data(#"{"user":{"role":"admin"},"capabilities":{"security":{"client.trusted_devices":true}}}"#.utf8))
        XCTAssertTrue(SessionFacts.parse(on).trustedDevices)
        let off = try Json.object(Data(#"{"user":{"role":"admin"},"capabilities":{"security":{"client.device_lock":"user"}}}"#.utf8))
        XCTAssertFalse(SessionFacts.parse(off).trustedDevices)
        XCTAssertFalse(SessionFacts().trustedDevices)
    }

    // MARK: with the controller

    private func controller(_ api: FakeApi, enabled: Bool = true) -> (ArmorController, TrustedPhoneSettings, SessionVault) {
        let (made, _, _, _, vault) = makeController(api: api)
        let settings = TrustedPhoneSettings(MemoryStore())
        settings.enabled = enabled
        made.trusted = TrustedPhone(api: api, signer: FakeSigner(), settings: settings, phoneName: { "iPhone" })
        return (made, settings, vault)
    }

    func testAPhoneWithNothingKeptOpensTheSessionBySigning() async {
        let api = FakeApi()
        api.facts = SessionFacts(role: "admin", deviceLock: "user", trustedDevices: true)
        let (made, settings, vault) = controller(api)
        settings.setId(origin, issued)
        let restored = await made.restore(origin: origin)
        XCTAssertTrue(restored)
        XCTAssertTrue(made.state.signedIn)
        XCTAssertEqual(vault.loadSession(origin: origin)?.value, "renewed", "the session the server opened is the one that is kept")
    }

    func testAPhoneWithNothingKeptAndNoTrustStaysSignedOut() async {
        let (made, _, _) = controller(FakeApi(), enabled: false)
        let restored = await made.restore(origin: origin)
        XCTAssertFalse(restored)
        XCTAssertFalse(made.state.signedIn)
    }

    func testARefusedKeptSessionIsRenewedBySigningBeforeGivingUp() async {
        let api = FakeApi()
        api.facts = SessionFacts(role: "admin", deviceLock: "user", trustedDevices: true)
        let (made, settings, vault) = controller(api)
        settings.setId(origin, issued)
        vault.saveSession(SessionCookie(name: "armor_studio_sid", value: "old"), origin: origin)
        api.sessionRefused = true
        let restored = await made.restore(origin: origin)
        XCTAssertTrue(restored)
        XCTAssertTrue(api.calls.contains("trust-challenge:\(issued)"))
    }

    func testARefusedSessionWhileInUseIsRenewedOnceAndNotForever() async throws {
        let api = FakeApi()
        api.facts = SessionFacts(role: "admin", deviceLock: "user", trustedDevices: true)
        let (made, settings, _) = controller(api)
        _ = try await made.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        settings.setId(origin, issued)
        api.sessionRefused = true
        _ = await made.refresh()
        XCTAssertTrue(made.state.signedIn, "renewed by signing")
        XCTAssertEqual(api.calls.filter { $0.hasPrefix("trust-session") }.count, 1)
        // a server that opens a session and still refuses is tried once, then the person signs in
        api.sessionRefused = true
        api.trustSessionError = ArmorApiError(message: "x", status: 401)
        _ = await made.refresh()
        XCTAssertFalse(made.state.signedIn)
    }

    func testRegisteringAfterSignInNeedsTheOptionOfTheServer() async throws {
        let off = FakeApi()
        off.facts = SessionFacts(role: "admin", deviceLock: "user", trustedDevices: false)
        let (closed, _, _) = controller(off)
        _ = try await closed.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        let refused = await closed.trustThisPhone()
        XCTAssertEqual(refused, .unavailable)
        XCTAssertFalse(off.calls.contains { $0.hasPrefix("trust-register") })

        let on = FakeApi()
        on.facts = SessionFacts(role: "admin", deviceLock: "user", trustedDevices: true)
        let (open, settings, _) = controller(on)
        _ = try await open.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        let done = await open.trustThisPhone()
        XCTAssertEqual(done, .done)
        XCTAssertEqual(settings.id(origin), issued)
    }

    func testSigningOutEndsTheTrustWhileTheSessionStillStands() async throws {
        let api = FakeApi()
        api.facts = SessionFacts(role: "admin", deviceLock: "user", trustedDevices: true)
        let (made, settings, _) = controller(api)
        _ = try await made.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        _ = await made.trustThisPhone()
        await made.signOut()
        let calls = api.calls
        let removed = calls.firstIndex(of: "trust-remove:\(issued)")
        let closed = calls.firstIndex(of: "close")
        XCTAssertNotNil(removed)
        XCTAssertNotNil(closed)
        if let removed, let closed { XCTAssertLessThan(removed, closed) }
        XCTAssertNil(settings.id(origin))
    }

    func testTheWordsOfTheSwitchAreInEveryLanguage() {
        let phrases = ["Teléfono de confianza", "Tu administrador no ha activado los teléfonos de confianza en este servidor.",
                       "El servidor no ha aceptado este teléfono como de confianza.", "Este servidor no ofrece teléfonos de confianza.", "Este teléfono ya es de confianza."]
        for language in ["en", "es", "de", "fr", "it", "ja", "zh", "pt"] {
            let translator = Translator(language: language)
            for phrase in phrases {
                XCTAssertFalse(translator.tr(phrase).isEmpty, "\(language) \(phrase)")
                if language != "es" { XCTAssertNotEqual(translator.tr(phrase), phrase, "\(language) \(phrase) is not translated") }
            }
        }
    }
}
