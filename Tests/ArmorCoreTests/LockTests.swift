import XCTest
@testable import ArmorCore

final class LockTests: XCTestCase {
    private func make(_ phone: LockAvailability, now: @escaping () -> Double = { 0 }) -> (LockPolicy, LockSettings) {
        let settings = LockSettings(MemoryStore())
        return (LockPolicy(settings: settings, availability: { phone }, clock: now), settings)
    }
    private func gate(_ auth: FakeAuth, _ policy: LockPolicy) -> LockGate { LockGate(policy: policy, auth: auth, translator: plain()) }

    func testOnByDefaultOnlyWithFaceOrFingerprint() {
        XCTAssertTrue(make(.biometric).0.sensitiveRequired())
        XCTAssertFalse(make(.deviceCredential).0.sensitiveRequired())
        XCTAssertFalse(make(.none).0.sensitiveRequired())
    }
    func testAPhoneWithNoLockIsNeverAskedForAnything() {
        let (policy, settings) = make(.none)
        settings.setSensitive(true); settings.openApp = true; settings.server = .always
        XCTAssertFalse(policy.promptNeeded())
        XCTAssertFalse(policy.openRequired())
        XCTAssertTrue(policy.status().unmet)
    }
    func testThePersonCanTurnItOnWithOnlyAPasscode() {
        let (policy, settings) = make(.deviceCredential)
        settings.setSensitive(true)
        XCTAssertTrue(policy.sensitiveRequired())
    }
    func testTheServerRaisesButNeverLowers() {
        let (policy, settings) = make(.biometric)
        settings.setSensitive(false)
        XCTAssertFalse(policy.sensitiveRequired())
        settings.server = .sensitive
        XCTAssertTrue(policy.sensitiveRequired())
        XCTAssertFalse(policy.openRequired())
        settings.server = .always
        XCTAssertTrue(policy.openRequired())
        let status = policy.status()
        XCTAssertTrue(status.sensitiveForced)
        XCTAssertTrue(status.openForced)
        settings.server = .user
        settings.setSensitive(true)
        XCTAssertTrue(policy.sensitiveRequired())
    }
    func testServerWordsAreParsedSafely() {
        XCTAssertEqual(ServerLock.parse("sensitive"), .sensitive)
        XCTAssertEqual(ServerLock.parse("always"), .always)
        XCTAssertEqual(ServerLock.parse("whatever"), .user)
        XCTAssertEqual(ServerLock.parse(nil), .user)
    }
    func testOneUnlockingCountsForTheGraceTime() {
        var now = 0.0
        let (policy, settings) = make(.biometric, now: { now })
        XCTAssertEqual(settings.graceSeconds, 30)
        XCTAssertTrue(policy.promptNeeded())
        policy.unlocked()
        now = 29_000
        XCTAssertFalse(policy.promptNeeded())
        now = 31_000
        XCTAssertTrue(policy.promptNeeded())
    }
    func testGraceZeroAsksEveryTime() {
        let (policy, settings) = make(.biometric)
        settings.graceSeconds = 0
        policy.unlocked()
        XCTAssertTrue(policy.promptNeeded())
        settings.graceSeconds = 77   // not one of the choices
        XCTAssertEqual(settings.graceSeconds, 30)
    }
    func testTheAppLocksAgainAfterTheTimeAway() {
        var now = 0.0
        let (policy, settings) = make(.biometric, now: { now })
        settings.openApp = true
        policy.left(); now = 10_000
        XCTAssertFalse(policy.returned())
        policy.left(); now = 40_000
        XCTAssertTrue(policy.returned())
        XCTAssertFalse(policy.returned())
    }
    func testLeavingForThePhonesOwnQuestionIsNotLeaving() {
        var now = 0.0
        let (policy, settings) = make(.biometric, now: { now })
        settings.openApp = true
        policy.prompting = true
        policy.left(); now = 99_000
        XCTAssertFalse(policy.returned())
    }
    func testGateAsksOnceForTwoOrdersAtOnce() async {
        let auth = FakeAuth(.biometric)
        let (policy, _) = make(.biometric)
        let lock = gate(auth, policy)
        async let a = lock.allow(reason: "x")
        async let b = lock.allow(reason: "y")
        let (ra, rb) = await (a, b)
        XCTAssertTrue(ra && rb)
        XCTAssertEqual(auth.asked, 1)
    }
    func testGateRefusesWhenTheQuestionIsCancelledOrFails() async {
        for answer in [AuthResult.cancelled, .failed("locked out")] {
            let auth = FakeAuth(.biometric, answer: answer)
            let (policy, _) = make(.biometric)
            let allowed = await gate(auth, policy).allow(reason: "x")
            XCTAssertFalse(allowed)
        }
    }
    func testGateLetsAnUnavailablePhoneThrough() async {
        let auth = FakeAuth(.biometric, answer: .unavailable)
        let (policy, _) = make(.biometric)
        let allowed = await gate(auth, policy).allow(reason: "x")
        XCTAssertTrue(allowed)
    }
}
