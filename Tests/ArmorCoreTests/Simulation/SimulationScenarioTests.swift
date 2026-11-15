import Foundation
import XCTest
@testable import ArmorCore

/// The app from end to end with no hardware: the real controller and the real HTTP client against the twin of the server, and the twin of the watch in the place of WatchConnectivity.
/// Every scenario is deterministic (counted ids, a clock moved by hand) and covers a failure or a cut as well as the way it should go.
final class SimulationScenarioTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private var server: SimulatedServer { SimulatedServer.shared }

    override func setUp() { server.reset() }

    private func controller(_ auth: FakeAuth = FakeAuth()) -> ArmorController {
        let prefs = MemoryStore()
        let settings = LockSettings(prefs)
        let policy = LockPolicy(settings: settings, availability: { auth.availability() }, clock: { 0 })
        let translator = plain("en")
        let gate = LockGate(policy: policy, auth: auth, translator: translator)
        let vault = SessionVault(secrets: MemorySecrets(), prefs: prefs)
        return ArmorController(api: SimulatedServerProtocol.makeClient(), vault: vault, gate: gate, lockSettings: settings, translator: translator)
    }

    private func signedIn() async throws -> ArmorController {
        let phone = controller()
        let outcome = try await phone.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        XCTAssertEqual(outcome, .done)
        await phone.refresh()   // the first refresh only records where the history stands
        return phone
    }

    private func status(of error: Error) -> Int? { (error as? ArmorApiError)?.status }

    // MARK: sign in

    func testSignInReadsTheSessionOfTheTwin() async throws {
        let phone = try await signedIn()
        XCTAssertTrue(phone.state.signedIn)
        XCTAssertEqual(phone.state.facts.role, "admin")
        XCTAssertTrue(server.signedIn)
    }

    func testAWrongPasswordIsRefusedAndNothingIsOpened() async {
        let phone = controller()
        do { _ = try await phone.signIn(origin: origin, username: "ana", password: "nope", remember: false); XCTFail("must be refused") }
        catch { XCTAssertEqual(status(of: error), 401) }
        XCTAssertFalse(phone.state.signedIn)
        XCTAssertFalse(server.signedIn)
    }

    func testTheSecondFactorIsAskedAndAWrongCodeDoesNotOpenTheSession() async throws {
        server.requireSecondFactor("123456")
        let phone = controller()
        let outcome = try await phone.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        XCTAssertEqual(outcome, .needsCode(challenge: "sim-challenge"))
        do { try await phone.completeSignIn(origin: origin, challenge: "sim-challenge", code: "000000", username: "ana", password: nil); XCTFail("must be refused") }
        catch { XCTAssertEqual(status(of: error), 401) }
        XCTAssertFalse(phone.state.signedIn)
        try await phone.completeSignIn(origin: origin, challenge: "sim-challenge", code: "123456", username: "ana", password: nil)
        XCTAssertTrue(phone.state.signedIn)
    }

    // MARK: alarm to watch to server

    func testAnAlarmGoesToTheWatchAndATapOnTheWatchConfirmsItOnTheServer() async throws {
        let phone = try await signedIn()
        let watch = SimulatedWatch()
        let alarm = server.raiseAlarm(code: "intrusion", severity: "high")
        let notices = await phone.refresh()
        XCTAssertEqual(notices.count, 1)
        XCTAssertEqual(notices.first?.alarmId, alarm)
        XCTAssertEqual(phone.state.unseenAlarms, 1)

        for message in WatchRelay.messages(for: notices[0], enabled: true) { watch.send(path: WatchRelay.pathToWatch, payload: message) }
        XCTAssertTrue(watch.rejected.isEmpty, "the watch checks every message against the contract: \(watch.rejected)")
        XCTAssertEqual(watch.shown.count, 1)
        XCTAssertEqual(watch.shown.first?.severity, "warning")
        XCTAssertEqual(watch.shown.first?.needsAck, true)

        let tap = try XCTUnwrap(watch.tap(alarm))
        let found = try XCTUnwrap(WatchRelay.alarmToAcknowledge(enabled: true, text: tap))
        XCTAssertEqual(found.alarmId, alarm)
        try await phone.acknowledge(found.alarmId)
        XCTAssertTrue(server.alarms[0].acknowledged)
        XCTAssertEqual(phone.state.unseenAlarms, 0)
        XCTAssertEqual(server.count(of: "POST /api/v1/alarms/\(alarm)/acknowledge"), 1)
        // a second tap (a double press, a late delivery) is not acted on
        XCTAssertNil(WatchRelay.alarmToAcknowledge(enabled: true, text: tap))
    }

    func testNothingReachesTheWatchWhileTheOptionIsOff() async throws {
        let phone = try await signedIn()
        let watch = SimulatedWatch()
        server.raiseAlarm()
        let notices = await phone.refresh()
        XCTAssertEqual(notices.count, 1)
        for message in WatchRelay.messages(for: notices[0], enabled: false) { watch.send(path: WatchRelay.pathToWatch, payload: message) }
        XCTAssertTrue(watch.received.isEmpty)
        XCTAssertTrue(watch.shown.isEmpty)
    }

    func testACriticalAlertOutlivesALesserOneOnTheWatchAndBothExpire() async throws {
        let phone = try await signedIn()
        let watch = SimulatedWatch()
        server.raiseAlarm(code: "tamper", severity: "critical", node: "radar-1")
        server.raiseAlarm(code: "intrusion", severity: "high", node: "radar-2")
        for notice in await phone.refresh() {
            for message in WatchRelay.messages(for: notice, enabled: true) { watch.send(path: WatchRelay.pathToWatch, payload: message) }
        }
        XCTAssertEqual(watch.shown.map(\.severity), ["critical", "warning"], "the worst first")
        watch.clock = WatchRelay.otherTtlSeconds
        XCTAssertEqual(watch.shown.map(\.severity), ["critical"])
        XCTAssertNil(watch.tap("alm-00002"), "an expired alert cannot be confirmed")
        watch.clock = WatchRelay.criticalTtlSeconds
        XCTAssertTrue(watch.shown.isEmpty)
    }

    func testAnAlertSentWhileTheWatchIsOutOfRangeIsLostNotQueued() async throws {
        let phone = try await signedIn()
        let watch = SimulatedWatch()
        watch.linkUp = false
        server.raiseAlarm()
        for notice in await phone.refresh() {
            for message in WatchRelay.messages(for: notice, enabled: true) { watch.send(path: WatchRelay.pathToWatch, payload: message) }
        }
        XCTAssertEqual(watch.lost, 2)
        watch.linkUp = true
        XCTAssertTrue(watch.shown.isEmpty)
        XCTAssertNil(watch.tap("alm-00001"))
    }

    func testTurningTheOptionOffClearsTheWatch() async throws {
        let phone = try await signedIn()
        let watch = SimulatedWatch()
        server.raiseAlarm()
        for notice in await phone.refresh() {
            for message in WatchRelay.messages(for: notice, enabled: true) { watch.send(path: WatchRelay.pathToWatch, payload: message) }
        }
        XCTAssertEqual(watch.shown.count, 1)
        watch.send(path: WatchRelay.pathToWatch, payload: WatchRelay.relayMessage(false))
        XCTAssertTrue(watch.shown.isEmpty)
        XCTAssertFalse(watch.relayOn)
    }

    func testTheWatchRefusesWhatBreaksTheContract() {
        let watch = SimulatedWatch()
        watch.send(path: WatchRelay.pathToWatch, payload: WatchRelay.relayMessage(true))
        watch.send(path: WatchRelay.pathToWatch, payload: #"{"type":"alert","protocolVersion":2,"alertId":"a","severity":"info","title":"t","text":"x","needsAck":false,"ttlSeconds":10}"#)
        watch.send(path: WatchRelay.pathToWatch, payload: #"{"type":"alert","protocolVersion":1,"alertId":"a","severity":"loud","title":"t","text":"x","needsAck":false,"ttlSeconds":10}"#)
        watch.send(path: WatchRelay.pathToWatch, payload: #"{"type":"alert","protocolVersion":1,"alertId":"a","severity":"info","title":"","text":"x","needsAck":false,"ttlSeconds":10}"#)
        watch.send(path: WatchRelay.pathToWatch, payload: "not json")
        watch.send(path: "/other", payload: WatchRelay.relayMessage(true))
        XCTAssertEqual(watch.rejected, ["shape", "alert", "alert", "shape", "path"])
        XCTAssertTrue(watch.shown.isEmpty)
    }

    // MARK: cuts and failures

    func testACutLineIsReportedAndTheHistoryIsNotLostWhenItComesBack() async throws {
        let phone = try await signedIn()
        server.cutLine(true)
        server.raiseAlarm()
        let during = await phone.refresh()
        XCTAssertTrue(during.isEmpty)
        XCTAssertTrue(phone.state.lastRefreshFailed)
        do { try await phone.acknowledge("alm-00001"); XCTFail("an order cannot cross a cut line") } catch { XCTAssertNil(status(of: error)) }
        XCTAssertFalse(server.alarms[0].acknowledged)
        server.cutLine(false)
        let after = await phone.refresh()
        XCTAssertEqual(after.count, 1, "what happened while the line was cut is announced when it returns")
        XCTAssertFalse(phone.state.lastRefreshFailed)
    }

    func testAnExpiredSessionLeavesThePhoneSignedOutAndSignInOpensItAgain() async throws {
        let phone = try await signedIn()
        server.expireSession()
        let notices = await phone.refresh()
        XCTAssertTrue(notices.isEmpty)
        XCTAssertFalse(phone.state.signedIn)
        XCTAssertTrue(phone.state.lastRefreshFailed)
        _ = try await phone.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        XCTAssertTrue(phone.state.signedIn)
    }

    func testAServerErrorOnAnOrderIsPassedOnNotSwallowed() async throws {
        let phone = try await signedIn()
        server.fail("POST /api/v1/mode", status: 500, body: #"{"error":"boom"}"#)
        do { try await phone.arm(); XCTFail("the error must reach the caller") } catch { XCTAssertEqual(status(of: error), 500) }
        XCTAssertEqual(server.mode, "disarmed")
        try await phone.arm()   // the failure was one only
        XCTAssertEqual(server.mode, "armed")
        XCTAssertTrue(phone.state.snapshot.armed)
    }

    func testTheAcknowledgementOfAnAlarmTheServerDoesNotKnowIsRefused() async throws {
        let phone = try await signedIn()
        do { try await phone.acknowledge("alm-99999"); XCTFail("must be refused") } catch { XCTAssertEqual(status(of: error), 404) }
    }

    func testAViewerCannotChangeTheStateOfTheSystem() async throws {
        server.setRole("viewer")
        let phone = try await signedIn()
        do { try await phone.arm(); XCTFail("a viewer only reads") } catch { XCTAssertTrue(error is ControllerError) }
        XCTAssertEqual(server.count(of: "POST /api/v1/mode"), 0)
    }

    // MARK: arming and the PIN

    func testArmingAndDisarmingWithThePinAndTheLockAfterThreeWrongOnes() async throws {
        let phone = try await signedIn()
        try await phone.arm()
        XCTAssertEqual(server.mode, "armed")
        for _ in 0..<3 {
            do { try await phone.disarm(pin: "0000"); XCTFail("a wrong PIN") } catch { XCTAssertEqual((error as? ArmorApiError)?.code, "wrong_pin") }
        }
        do { try await phone.disarm(pin: "1234"); XCTFail("locked") } catch { XCTAssertEqual((error as? ArmorApiError)?.code, "pin_locked") }
        XCTAssertEqual(server.mode, "armed")
    }

    func testDisarmingWithTheRightPinWorks() async throws {
        let phone = try await signedIn()
        try await phone.arm()
        try await phone.disarm(pin: "1234")
        XCTAssertEqual(server.mode, "disarmed")
        XCTAssertFalse(phone.state.snapshot.armed)
    }

    // MARK: push

    func testRegisteringForPushTwiceKeepsOneTokenWithItsLanguage() async throws {
        let api = SimulatedServerProtocol.makeClient()
        _ = try await api.signIn(origin, username: "ana", password: "pw")
        try await api.registerPush(origin, token: "tok-1", language: "pt")
        try await api.registerPush(origin, token: "tok-1", language: "pt")   // 409 is accepted: it is registered already
        XCTAssertEqual(server.pushTokens, ["tok-1": "pt"])
        try await api.unregisterPush(origin, token: "tok-1")
        XCTAssertTrue(server.pushTokens.isEmpty)
    }

    func testAnOrderBeforeSigningInIsRefusedByTheServer() async {
        let api = SimulatedServerProtocol.makeClient()
        do { _ = try await api.status(origin); XCTFail("needs a session") } catch { XCTAssertEqual(status(of: error), 401) }
    }
}
