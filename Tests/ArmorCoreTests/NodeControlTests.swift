import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// Controlling the nodes from the phone: what the server answers is read as it is, what is typed again is what the server asks for, and the words are the ones of the Android app.
final class NodeControlTests: XCTestCase {
    private let t = plain()

    private func object(_ text: String) -> JSON { (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? JSON ?? [:] }

    private let started = """
    {"id":"a1b2c3d4e5f60718","scope":"node","operation":"restart","mode":"now","actor":"ana","created_at":"2026-01-01T10:00:00Z","updated_at":"2026-01-01T10:00:05Z","state":"running",
     "nodes":[{"node_id":"radar-1","family":"radar","stage":"acknowledged","restart_in_s":2,"firmware_before":"0.7.7"}]}
    """

    func testAnOrderIsReadWithTheLineOfEachNode() {
        let operation = NodeControlParser.operation(object(started))
        XCTAssertEqual([operation.id, operation.scope, operation.operation, operation.mode, operation.state], ["a1b2c3d4e5f60718", "node", "restart", "now", "running"])
        XCTAssertTrue(operation.active)
        let line = operation.nodes[0]
        XCTAssertEqual(operation.nodes.count, 1)
        XCTAssertEqual([line.nodeId, line.family, line.stage, line.firmwareBefore], ["radar-1", "radar", "acknowledged", "0.7.7"])
        XCTAssertFalse(line.finished)
        XCTAssertNil(line.untilS)
        let done = NodeControlParser.operation(object("""
        {"id":"x1","scope":"all","operation":"pause","state":"done","duration_s":600,"nodes":[
          {"node_id":"alarm-1","family":"alarm","stage":"applied","state":"paused","until_s":590,"maintenance":false},
          {"node_id":"solar-1","family":"solar","stage":"refused","refusal":"busy_battery"},
          {"node_id":"radar-1","family":"radar","stage":"applied","state":"paused","diagnostics":{"firmware":"0.7.8","uptime_s":120}}]}
        """))
        XCTAssertFalse(done.active)
        XCTAssertEqual(done.durationS, 600)
        XCTAssertEqual(done.nodes.map { $0.finished }, [true, true, true])
        XCTAssertEqual(done.nodes[0].untilS, 590)
        XCTAssertEqual(done.nodes[1].refusal, "busy_battery")
        XCTAssertEqual(done.nodes[2].diagnostics["uptime_s"], "120")
    }

    func testTheListIsReadAndAnEntryWithoutAnIdIsLeftOut() {
        let list = NodeControlParser.list(object("{\"operations\":[\(started),{\"state\":\"done\"}]}"))
        XCTAssertEqual(list.map { $0.id }, ["a1b2c3d4e5f60718"])
        XCTAssertEqual(NodeControlParser.list([:]).count, 0)
    }

    func testTheHealthOfANodeCarriesWhatItsControlSays() {
        let overview = NodeHealthParser.overview(object("""
        {"nodes":[{"node_id":"alarm-1","family":"alarm","firmware":"0.4.2","status":"ok","report":{"uptime_s":5},"control":{"state":"standby","maintenance":true}},
                  {"node_id":"radar-1","family":"radar","firmware":"0.7.8","status":"ok","report":{"uptime_s":5}}]}
        """))
        XCTAssertEqual(overview.nodes.map { $0.controlState }, ["standby", ""])
        XCTAssertEqual(overview.nodes.map { $0.maintenance }, [true, false])
        XCTAssertEqual(NodeControlText.stateName("standby", maintenance: true, t), "En espera (sigue conectado) · en mantenimiento")
        XCTAssertEqual(NodeControlText.stateName("", maintenance: false, t), "")
    }

    func testTheContractHasTheEightOperationsAndNoneThatErasesOrSleeps() {
        XCTAssertEqual(NodeControlParser.operations, ["restart", "pause", "resume", "standby", "identify", "diagnostics", "maintenance_on", "maintenance_off"])
        for not in ["factory_reset", "erase", "wipe", "deep_sleep", "sleep", "wake"] { XCTAssertFalse(NodeControlParser.operations.contains(not), not) }
    }

    func testWhatIsTypedAgainIsTheNodeNameForOneNodeAndTheWordForAll() {
        XCTAssertEqual(NodeControlParser.confirmation(operation: "restart", nodeId: "radar-1"), "radar-1")
        XCTAssertEqual(NodeControlParser.confirmation(operation: "restart", nodeId: nil), "RESTART")
        XCTAssertEqual(NodeControlParser.confirmation(operation: "pause", nodeId: nil), "PAUSE")
        XCTAssertEqual(NodeControlParser.confirmation(operation: "standby", nodeId: nil), "STANDBY")
        for op in ["resume", "identify", "diagnostics", "maintenance_on", "maintenance_off"] {
            XCTAssertNil(NodeControlParser.confirmation(operation: op, nodeId: "radar-1"), op)
            XCTAssertNil(NodeControlParser.confirmation(operation: op, nodeId: nil), op)
        }
    }

    func testADurationIsOnlyForTheOperationsThatTakeOneAndInsideTheirRange() {
        for typed in ["", "60", "3600"] { XCTAssertTrue(NodeControlParser.durationOk(operation: "pause", typed: typed), typed) }
        for typed in ["59", "3601", "abc"] { XCTAssertFalse(NodeControlParser.durationOk(operation: "pause", typed: typed), typed) }
        XCTAssertTrue(NodeControlParser.durationOk(operation: "restart", typed: ""))
        XCTAssertFalse(NodeControlParser.durationOk(operation: "restart", typed: "30"))
        XCTAssertEqual(NodeControlParser.duration(operation: "identify", typed: " 30 "), 30)
        XCTAssertNil(NodeControlParser.duration(operation: "identify", typed: "4"))
        XCTAssertNil(NodeControlParser.duration(operation: "identify", typed: ""))
        XCTAssertNil(NodeControlParser.duration(operation: "restart", typed: "30"))
        XCTAssertEqual(NodeControlParser.durations["maintenance_on"]?.max, 28_800)
    }

    func testEveryWordHasATextAndAWarningNamesWhatItLeavesUndone() {
        for op in NodeControlParser.operations { XCTAssertNotEqual(NodeControlText.operationName(op, t), op, op) }
        for stage in ["pending", "armed", "sent", "acknowledged", "applied", "offline", "back", "refused", "no_answer", "not_back"] { XCTAssertNotEqual(NodeControlText.stageName(stage, t), stage, stage) }
        for code in ["invalid_request", "unknown_node", "busy", "node_unavailable", "no_nodes", "already_in_state", "rate_limited", "mqtt_unavailable", "too_many_nodes", "busy_update", "busy_upload", "busy_slot_copy", "busy_battery", "already_restarting", "not_armed", "unavailable"] {
            XCTAssertNotEqual(NodeControlText.refusal(code, t), code, code)
        }
        XCTAssertTrue(NodeControlText.warning(operation: "standby", all: false, mode: "now", guards: true, t)!.hasPrefix("Atención"))
        XCTAssertFalse(NodeControlText.warning(operation: "standby", all: false, mode: "now", guards: false, t)!.hasPrefix("Atención"))
        XCTAssertNotEqual(NodeControlText.warning(operation: "restart", all: true, mode: "rolling", guards: false, t), NodeControlText.warning(operation: "restart", all: true, mode: "now", guards: false, t))
        XCTAssertNil(NodeControlText.warning(operation: "unknown", all: false, mode: "now", guards: false, t))
        XCTAssertEqual(NodeControlText.errorText(ArmorApiError(message: "x", status: 409, body: "{\"code\":\"busy\"}"), t), NodeControlText.refusal("busy", t))
    }

    func testTheCallsAreTheOnesTheServerHas() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api: ArmorApi = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        let origin = "http://192.168.0.180:8080"
        StubProtocol.routes["POST /api/v1/nodes/radar 1/control"] = (202, started)
        let one = try await api.nodeControl(origin, nodeId: "radar 1", operation: "restart", confirm: "radar 1", durationS: nil)
        XCTAssertEqual(one.id, "a1b2c3d4e5f60718")
        let first = try XCTUnwrap(StubProtocol.bodies.last)
        XCTAssertTrue(first.contains("\"operation\":\"restart\"") && first.contains("\"confirm\":\"radar 1\"") && !first.contains("duration_s"))
        StubProtocol.routes["POST /api/v1/nodes/control"] = (202, started)
        _ = try await api.nodesControl(origin, operation: "pause", mode: "now", confirm: "PAUSE", durationS: 600)
        let second = try XCTUnwrap(StubProtocol.bodies.last)
        for piece in ["\"operation\":\"pause\"", "\"mode\":\"now\"", "\"confirm\":\"PAUSE\"", "\"duration_s\":600"] { XCTAssertTrue(second.contains(piece), piece) }
        StubProtocol.routes["GET /api/v1/nodes/control/operations"] = (200, "{\"operations\":[\(started)]}")
        let list = try await api.nodeControlOperations(origin)
        XCTAssertEqual(list.map { $0.id }, ["a1b2c3d4e5f60718"])
        StubProtocol.routes["GET /api/v1/nodes/control/operations/a1b2c3d4e5f60718"] = (200, started)
        let fresh = try await api.nodeControlOperation(origin, id: "a1b2c3d4e5f60718")
        XCTAssertEqual(fresh.operation, "restart")
    }
}
