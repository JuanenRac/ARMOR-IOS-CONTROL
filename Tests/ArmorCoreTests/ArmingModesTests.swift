import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// The arming modes of the server (Away, Home, Night): what it answers, what the app sends, how a refusal is read and what the controller does with it.
final class ArmingModesTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private let answer = #"""
    {"enabled":true,"current":"away","available":["disarmed","away","home","night"],"unassigned":["night"],"downgrade_pin_required":true,"schedule_enabled":false,"schedule_may_lower":false,
     "max_schedule":16,"revision":4,"updated_at":"x","updated_by":"admin",
     "modes":{"away":{},"home":{"defends":["zone:Hall","device:door-1"],"entry":["device:door-1"],"exit_delay_s":30},"night":{}},"schedule":[]}
    """#

    func testTheModesAreReadWithWhatEachOneDefendsAndWhatIsStillUnassigned() throws {
        let view = ArmingModesView.parse(try Json.object(Data(answer.utf8)))
        XCTAssertTrue(view.enabled)
        XCTAssertEqual(view.current, "away")
        XCTAssertEqual(view.armable, ["away", "home", "night"])
        XCTAssertEqual(view.unassigned, ["night"])
        XCTAssertEqual(view.defended, ["home": 2, "night": 0])
        XCTAssertTrue(view.downgradePinRequired)
    }
    func testAnOffServerAnOddAnswerOrNothingIsTheOldWayOfArmingAndDisarming() throws {
        XCTAssertFalse(ArmingModesView.parse([:]).enabled)
        XCTAssertEqual(ArmingModesView.parse([:]).armable, [])
        let odd = ArmingModesView.parse(try Json.object(Data(#"{"enabled":true,"current":"visiting","available":["away","party","home"],"unassigned":[""]}"#.utf8)))
        XCTAssertEqual(odd.current, "disarmed")
        XCTAssertEqual(odd.armable, ["away", "home"])
        XCTAssertEqual(odd.unassigned, [])
    }
    func testTheWordsNameTheModeAndWhatItDefends() throws {
        let t = plain("es")
        let view = ArmingModesView.parse(try Json.object(Data(answer.utf8)))
        XCTAssertEqual(ArmingText.name("away", t), "Modo fuera de casa")
        XCTAssertEqual(ArmingText.name("home", t), "Modo en casa")
        XCTAssertEqual(ArmingText.name("night", t), "Modo noche")
        XCTAssertEqual(ArmingText.defends(view, "away", t), "defiende todo")
        XCTAssertEqual(ArmingText.defends(view, "home", t), "2 marcados")
        XCTAssertEqual(ArmingText.defends(view, "night", t), "aún nada asignado")
        for code in ["modes_disabled", "no_zones_assigned", "wrong_pin", "pin_locked", "pin_not_set", "failed"] { XCTAssertFalse(ArmingText.refusal(code, t).isEmpty, code) }
        XCTAssertTrue(ArmingText.isAskable("no_zones_assigned"))
        XCTAssertTrue(ArmingText.isAskable("wrong_pin"))
        XCTAssertFalse(ArmingText.isAskable("modes_disabled"))
        XCTAssertFalse(ArmingText.isAskable("failed"))
    }
    func testTheStateCarriesTheModeInForceOnlyWhileTheServerAnnouncesOne() throws {
        XCTAssertEqual(ArmorSnapshot.parse(try Json.object(Data(#"{"mode":"armed","arming_mode":"night","revision":1,"nodes":{}}"#.utf8))).armingMode, "night")
        XCTAssertNil(ArmorSnapshot.parse(try Json.object(Data(#"{"mode":"armed","revision":1,"nodes":{}}"#.utf8))).armingMode)
    }
    func testEveryPhraseOfTheModesIsInEveryLanguage() throws {
        let phrases = ["Modo fuera de casa", "Modo en casa", "Modo noche", "defiende todo", "aún nada asignado", "%d marcados", "Modo de armado", "Hace falta el PIN", "Armar: %s", "Cambiar a %s",
                       "Nada asignado a %s", "Sistema armado: %s", "Ahora: %s", "Modo: %s", "No se pudo cambiar el modo.", "Ese modo no tiene nada asignado: no se armó.",
                       "Los modos de armado no están activados en el servidor."]
        for code in ["en", "de", "fr", "it", "ja", "zh", "pt"] {
            let table = try XCTUnwrap(Translator.bundled(code), code)
            for phrase in phrases { XCTAssertNotNil(table[phrase], "\(code): \(phrase)") }
        }
    }

    // MARK: the client

    private func client() -> ArmorApiClient {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
    }
    func testTheModesAreReadFromTheRouteOfTheContract() async throws {
        let api = client()
        StubProtocol.routes["GET /api/v1/alarm/modes"] = (200, answer)
        let view = try await api.armingModes(origin)
        XCTAssertTrue(view.enabled)
    }
    func testArmingInAModeSendsTheModeThePinAndTheConfirmationOnlyWhenGiven() async throws {
        let api = client()
        StubProtocol.routes["POST /api/v1/mode"] = (200, "{}")
        try await api.setArmingMode(origin, mode: "home", pin: nil, confirmUnassigned: false)
        try await api.setArmingMode(origin, mode: "night", pin: "1234", confirmUnassigned: true)
        let first = try Json.object(Data(StubProtocol.bodies[0].utf8)), second = try Json.object(Data(StubProtocol.bodies[1].utf8))
        XCTAssertEqual(first.str("mode"), "home"); XCTAssertFalse(first.has("pin")); XCTAssertFalse(first.has("confirm_unassigned"))
        XCTAssertEqual(second.str("mode"), "night"); XCTAssertEqual(second.str("pin"), "1234"); XCTAssertTrue(second.bool("confirm_unassigned"))
    }
    func testAModeThatIsNotAnArmedModeIsRefusedBeforeSending() async {
        let api = client()
        for mode in ["disarmed", "armed", "party"] {
            do { try await api.setArmingMode(origin, mode: mode, pin: nil, confirmUnassigned: false); XCTFail(mode) } catch {}
        }
        XCTAssertTrue(StubProtocol.seen.isEmpty)
    }
    func testTheRefusalsOfTheServerKeepTheirCode() async {
        let api = client()
        for (status, code) in [(409, "no_zones_assigned"), (403, "wrong_pin"), (429, "pin_locked"), (403, "pin_not_set"), (400, "modes_disabled")] {
            StubProtocol.routes["POST /api/v1/mode"] = (status, #"{"error":"x","code":"\#(code)"}"#)
            do { try await api.setArmingMode(origin, mode: "home", pin: nil, confirmUnassigned: false); XCTFail(code) }
            catch let error as ArmorApiError { XCTAssertEqual(error.code, code); XCTAssertEqual(error.status, status) }
            catch { XCTFail("\(error)") }
        }
    }

    // MARK: the controller

    private func signedIn(_ api: FakeApi = FakeApi()) async throws -> (ArmorController, FakeApi) {
        api.facts = SessionFacts(role: "admin", deviceLock: "user")
        let made = makeController(api: api)
        _ = try await made.0.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        return (made.0, api)
    }
    func testTheControllerReadsTheModesAndKeepsWhatItKnewAgainstAnOlderServer() async throws {
        let api = FakeApi()
        api.modes = ArmingModesView.parse(try Json.object(Data(answer.utf8)))
        let (controller, _) = try await signedIn(api)
        await controller.refresh()
        XCTAssertEqual(controller.state.armingModes?.enabled, true)
        api.armingModesAvailable = false
        await controller.refresh()
        XCTAssertEqual(controller.state.armingModes?.enabled, true, "an older server does not take back what was read")
    }
    func testArmingInAModeGoesBehindTheLockAndSendsWhatTheScreenAsks() async throws {
        let (controller, api) = try await signedIn()
        try await controller.armInMode("home", pin: nil, confirmUnassigned: false)
        try await controller.armInMode("night", pin: "42", confirmUnassigned: true)
        XCTAssertEqual(api.calls.filter { $0.hasPrefix("arming:") }, ["arming:home:-:false", "arming:night:42:true"])
    }
    func testAViewerCannotArmInAMode() async throws {
        let api = FakeApi()
        api.facts = SessionFacts(role: "viewer", deviceLock: "user")
        let made = makeController(api: api)
        _ = try await made.0.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        do { try await made.0.armInMode("home", pin: nil, confirmUnassigned: false); XCTFail() } catch ControllerError.readOnly {} catch { XCTFail("\(error)") }
        XCTAssertTrue(api.calls.filter { $0.hasPrefix("arming:") }.isEmpty)
    }
    func testTheRefusalOfTheServerReachesTheScreenWithItsCode() async throws {
        let api = FakeApi()
        api.armingError = ArmorApiError(message: "x", status: 409, body: #"{"code":"no_zones_assigned"}"#)
        api.armingErrorOnce = true
        let (controller, _) = try await signedIn(api)
        do { try await controller.armInMode("night", pin: nil, confirmUnassigned: false); XCTFail() } catch let error as ArmorApiError { XCTAssertEqual(error.code, "no_zones_assigned") }
        try await controller.armInMode("night", pin: nil, confirmUnassigned: true)
        XCTAssertEqual(api.calls.filter { $0.hasPrefix("arming:") }, ["arming:night:-:false", "arming:night:-:true"])
    }

    func testArmingInAModeFromDisarmedRunsTheSameCheckAsAPlainArm() {
        let blind = Preflight(ready: false, issues: [PreflightIssue(kind: "node", level: "block", code: "node_offline", id: "radar-1", detail: nil)])
        let none = Preflight(ready: true, issues: [])
        XCTAssertTrue(ArmingText.showsCheck(systemArmed: false, check: blind))
        XCTAssertFalse(ArmingText.showsCheck(systemArmed: false, check: none))
        XCTAssertFalse(ArmingText.showsCheck(systemArmed: false, check: nil))
        XCTAssertFalse(ArmingText.showsCheck(systemArmed: true, check: blind))
    }
}
