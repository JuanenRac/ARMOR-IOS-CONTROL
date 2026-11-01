import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// The calls for solar equipment, the electrical network, the battery maintenance and the reports, made through the protocol the screens use.
final class EquipmentClientTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private var api: ArmorApi!

    override func setUp() {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
    }

    func testSolarIsReadFromItsPathThroughTheProtocol() async throws {
        StubProtocol.routes["GET /api/v1/solar"] = (200, #"{"devices":[{"node_id":"n","device":"d","kind":"inverter","reading":{"mode":"line"}}],"totals":{"inverters":1,"pv_w":500}}"#)
        let overview = try await api.solar(origin)
        XCTAssertEqual(overview.devices.count, 1)
        XCTAssertEqual(overview.totals.pvW, 500)
    }

    func testTheElectricalNetworkIsReadFromItsPath() async throws {
        StubProtocol.routes["GET /api/v1/electrical/readings"] = (200, #"{"nodes":[{"node_id":"e1","reading":{"channels":[{"id":"grid","power_w":100}]}}],"totals":{"grid_w":100}}"#)
        let overview = try await api.electrical(origin)
        XCTAssertEqual(overview.nodes.first?.channels.first?.powerW, 100)
        XCTAssertEqual(overview.totals.gridW, 100)
    }

    func testARefusedSolarReadKeepsItsStatus() async {
        StubProtocol.routes["GET /api/v1/solar"] = (403, #"{"error":"forbidden"}"#)
        do { _ = try await api.solar(origin); XCTFail("must refuse") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 403) } catch { XCTFail("\(error)") }
    }

    func testTheListOfBatteryOperationsIsRead() async throws {
        StubProtocol.routes["GET /api/v1/solar/battery-ops"] = (200, #"{"enabled":true,"operations":[{"id":"op1","stage":"done"}]}"#)
        let overview = try await api.batteryOperations(origin)
        XCTAssertTrue(overview.enabled)
        XCTAssertEqual(overview.operations.map(\.id), ["op1"])
    }

    func testArmingAnOutputSendsTheOutputAndTheStateAndTheSerial() async throws {
        StubProtocol.routes["POST /api/v1/solar/battery-ops"] = (202, #"{"id":"op2","stage":"arming","op":"output_set"}"#)
        let operation = try await api.batteryArm(origin, node: "gw1", port: 2, op: "output_set", output: "cfet", state: "off", serial: "ABCDEFGHIJ")
        XCTAssertEqual(operation.id, "op2")
        XCTAssertEqual(operation.stage, "arming")
        let body = try XCTUnwrap(StubProtocol.bodies.last)
        for piece in ["\"node\":\"gw1\"", "\"port\":2", "\"op\":\"output_set\"", "\"output\":\"cfet\"", "\"state\":\"off\"", "\"serial\":\"ABCDEFGHIJ\""] { XCTAssertTrue(body.contains(piece), piece) }
    }

    func testArmingAnotherOperationSendsNoParameters() async throws {
        StubProtocol.routes["POST /api/v1/solar/battery-ops"] = (202, #"{"id":"op3","stage":"arming"}"#)
        _ = try await api.batteryArm(origin, node: "gw1", port: 1, op: "set_clock", output: "cfet", state: "off", serial: "NOSERIAL")
        let body = try XCTUnwrap(StubProtocol.bodies.last)
        XCTAssertTrue(body.contains("\"params\":{}"))
        XCTAssertFalse(body.contains("cfet"))
    }

    func testAnOperationIsReadExecutedAndCancelledByItsIdentifier() async throws {
        StubProtocol.routes["GET /api/v1/solar/battery-ops/op1"] = (200, #"{"id":"op1","stage":"running"}"#)
        StubProtocol.routes["POST /api/v1/solar/battery-ops/op1/execute"] = (202, #"{"id":"op1","stage":"starting"}"#)
        StubProtocol.routes["POST /api/v1/solar/battery-ops/op1/cancel"] = (202, #"{"id":"op1","stage":"withdrawn"}"#)
        let read = try await api.batteryOperation(origin, id: "op1")
        XCTAssertEqual(read.stage, "running")
        let executed = try await api.batteryExecute(origin, id: "op1", serial: "ABCDEFGHIJ")
        XCTAssertEqual(executed.stage, "starting")
        XCTAssertTrue(try XCTUnwrap(StubProtocol.bodies.last).contains("\"serial\":\"ABCDEFGHIJ\""))
        let cancelled = try await api.batteryCancel(origin, id: "op1")
        XCTAssertEqual(cancelled.stage, "withdrawn")
    }

    func testAnIdentifierCannotClimbOutOfThePath() async {
        let result = try? await api.batteryOperation(origin, id: "x/../../status")
        XCTAssertNil(result)
        XCTAssertEqual(StubProtocol.seen.count, 1)
        XCTAssertTrue(StubProtocol.seen.first?.url?.absoluteString.hasSuffix("/api/v1/solar/battery-ops/x%2F..%2F..%2Fstatus") == true)
    }

    func testTheReportsReachTheRealClientThroughTheProtocol() async throws {
        StubProtocol.routes["GET /api/v1/summary/daily"] = (200, #"{"date":"2026-03-05","language":"en","text":"Quiet day.","summary":{"totals":{"events":2}}}"#)
        let summary = try await api.dailySummary(origin, date: "2026-03-05", language: "en")
        XCTAssertEqual(summary.text, "Quiet day.")
        XCTAssertEqual(summary.events, 2)
    }

    func testAServerWithoutTheseCallsRefusesInsteadOfAnsweringNothing() async {
        let fake = FakeApi()
        do { _ = try await fake.solar(origin); XCTFail("must refuse") } catch let error as ArmorApiError { XCTAssertNil(error.status) } catch { XCTFail("\(error)") }
        do { _ = try await fake.batteryCancel(origin, id: "a"); XCTFail("must refuse") } catch is ArmorApiError {} catch { XCTFail("\(error)") }
    }
}
