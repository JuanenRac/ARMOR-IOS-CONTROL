import XCTest
@testable import ArmorCore

final class ControllerTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"

    private func signedIn(role: String = "admin", auth: FakeAuth = FakeAuth()) async throws -> (ArmorController, FakeApi, FakeAuth, LockSettings, SessionVault) {
        let api = FakeApi()
        api.facts = SessionFacts(role: role, deviceLock: "user")
        let made = makeController(api: api, auth: auth)
        _ = try await made.0.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        return made
    }

    func testSignInKeepsTheSessionAndTheServersLockRequirement() async throws {
        let api = FakeApi()
        api.facts = SessionFacts(role: "admin", deviceLock: "always")
        let (controller, _, _, settings, vault) = makeController(api: api)
        let outcome = try await controller.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        XCTAssertEqual(outcome, .done)
        XCTAssertTrue(controller.state.signedIn)
        XCTAssertEqual(settings.server, .always)
        XCTAssertEqual(vault.loadSession(origin: origin)?.value, "abc")
        XCTAssertNil(vault.rememberedLogin(origin: origin), "the password is not kept unless asked")
    }
    func testRememberMeKeepsTheLoginAndUntickingForgetsIt() async throws {
        let (controller, _, _, _, vault) = makeController()
        _ = try await controller.signIn(origin: origin, username: "ana", password: "pw", remember: true)
        XCTAssertEqual(vault.rememberedLogin(origin: origin)?.password, "pw")
        _ = try await controller.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        XCTAssertNil(vault.rememberedLogin(origin: origin))
    }
    func testSecondFactorFlow() async throws {
        let api = FakeApi()
        api.signInResult = .needsCode(challenge: "ch")
        let (controller, _, _, _, _) = makeController(api: api)
        let outcome = try await controller.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        XCTAssertEqual(outcome, .needsCode(challenge: "ch"))
        XCTAssertFalse(controller.state.signedIn)
        try await controller.completeSignIn(origin: origin, challenge: "ch", code: "123456", username: "ana", password: nil)
        XCTAssertTrue(controller.state.signedIn)
        XCTAssertTrue(api.calls.contains("totp:ch:123456"))
    }
    func testRestoreUsesTheKeptSessionAndDropsARefusedOne() async throws {
        let (controller, api, _, _, vault) = makeController()
        vault.saveSession(SessionCookie(name: "armor_studio_sid", value: "old"), origin: origin)
        let restored = await controller.restore(origin: origin)
        XCTAssertTrue(restored)
        XCTAssertTrue(api.calls.contains("restore"))

        final class Expired: FakeApi, @unchecked Sendable {
            override func sessionFacts(_ origin: String) async throws -> SessionFacts { throw ArmorApiError(message: "x", status: 401) }
        }
        let (other, _, _, _, vault2) = makeController(api: Expired())
        vault2.saveSession(SessionCookie(name: "armor_studio_sid", value: "old"), origin: origin)
        let again = await other.restore(origin: origin)
        XCTAssertFalse(again)
        XCTAssertNil(vault2.loadSession(origin: origin))
    }
    func testArmingAsksTheLockFirstAndDoesNothingIfRefused() async throws {
        let refusing = FakeAuth(.biometric, answer: .cancelled)
        let (controller, api, _, _, _) = try await signedIn(auth: refusing)
        do { try await controller.arm(); XCTFail("must not arm") } catch { XCTAssertEqual(error as? ControllerError, .lockRefused) }
        XCTAssertFalse(api.calls.contains { $0.hasPrefix("mode:") })
    }
    func testArmingAndDisarmingWithThePin() async throws {
        let (controller, api, auth, _, _) = try await signedIn()
        try await controller.arm()
        XCTAssertEqual(controller.state.snapshot.mode, "armed")
        try await controller.disarm(pin: "1234")
        XCTAssertTrue(api.calls.contains("mode:armed:-"))
        XCTAssertTrue(api.calls.contains("mode:disarmed:1234"))
        XCTAssertEqual(auth.asked, 1, "the second order is inside the grace time of the first")
    }
    func testAViewerCanOnlyLook() async throws {
        let (controller, api, auth, _, _) = try await signedIn(role: "viewer")
        do { try await controller.arm(); XCTFail("viewer armed") } catch { XCTAssertEqual(error as? ControllerError, .readOnly) }
        XCTAssertEqual(auth.asked, 0)
        XCTAssertFalse(api.calls.contains { $0.hasPrefix("mode:") })
    }
    func testNotSignedInDoesNothing() async {
        let (controller, api, _, _, _) = makeController()
        do { try await controller.arm(); XCTFail() } catch { XCTAssertEqual(error as? ControllerError, .notSignedIn) }
        XCTAssertTrue(api.calls.isEmpty)
    }
    func testElevationIsAskedOnceAndTheOrderRepeated() async throws {
        let (controller, api, _, _, _) = try await signedIn()
        api.modeError = ArmorApiError(message: "x", status: 403, body: #"{"code":"elevation_required"}"#)
        api.modeErrorOnce = true
        try await controller.arm(asker: { (password: "pw", code: "") })
        XCTAssertEqual(api.calls.filter { $0 == "mode:armed:-" }.count, 2)
        XCTAssertTrue(api.calls.contains("elevate:pw:"))
    }
    func testDecliningElevationStopsTheOrder() async throws {
        let (controller, api, _, _, _) = try await signedIn()
        api.modeError = ArmorApiError(message: "x", status: 403, body: #"{"code":"elevation_required"}"#)
        do { try await controller.arm(asker: { nil }); XCTFail() } catch { XCTAssertEqual(error as? ControllerError, .elevationDeclined) }
        XCTAssertEqual(api.calls.filter { $0 == "mode:armed:-" }.count, 1)
    }
    func testAWrongPinReachesTheScreenWithItsCode() async throws {
        let (controller, api, _, _, _) = try await signedIn()
        api.modeError = ArmorApiError(message: "x", status: 403, body: #"{"code":"wrong_pin"}"#)
        do { try await controller.disarm(pin: "0000"); XCTFail() } catch { XCTAssertEqual((error as? ArmorApiError)?.code, "wrong_pin") }
    }
    func testPanelOrders() async throws {
        let (controller, api, _, _, _) = try await signedIn()
        try await controller.armPanel("alarm-1", mode: "away", force: false, profile: nil)
        try await controller.disarmPanel("alarm-1", pin: "42")
        try await controller.silencePanel("alarm-1", pin: nil)
        try await controller.acknowledge("alm-1")
        try await controller.acknowledgeAll()
        XCTAssertEqual(api.calls.filter { $0.hasPrefix("panel:") || $0.hasPrefix("silence") || $0.hasPrefix("ack") },
                       ["panel:alarm-1:away:-", "panel:alarm-1:disarm:42", "silence:alarm-1", "ack:alm-1", "ackall"])
    }
    func testRefreshAnnouncesOnlyWhatIsNewAndNeverTheBaseline() async throws {
        let (controller, api, _, _, _) = try await signedIn()
        func raised(_ id: Int) -> ArmorEvent {
            ArmorEvent(id: id, at: "", type: "alarm", subject: "d1", from: nil, to: "raised", targets: nil, mode: nil, severity: "critical", code: "smoke", sourceType: "device")
        }
        api.historyEvents = [raised(5)]
        let first = await controller.refresh()
        XCTAssertTrue(first.isEmpty)
        api.historyEvents = [raised(5), raised(6)]
        let second = await controller.refresh()
        XCTAssertEqual(second.map(\.id), [6])
        let third = await controller.refresh()
        XCTAssertTrue(third.isEmpty)
    }
    func testTheAssistantConfirmationGoesBehindTheLock() async throws {
        let (controller, api, auth, _, _) = try await signedIn()
        let first = try await controller.ask("arma", confirmation: nil)
        XCTAssertEqual(auth.asked, 0)
        let second = try await controller.ask("arma", confirmation: first.confirmationToken)
        XCTAssertEqual(auth.asked, 1)
        XCTAssertTrue(second.executed)
        XCTAssertTrue(api.calls.contains("voice:arma:es:tok"))
    }
    func testSignOutForgetsEverythingHere() async throws {
        let (controller, api, _, _, vault) = try await signedIn()
        await controller.signOut()
        XCTAssertFalse(controller.state.signedIn)
        XCTAssertNil(vault.loadSession(origin: origin))
        XCTAssertTrue(api.calls.contains("close"))
        XCTAssertTrue(api.calls.contains("forget"))
    }
}
