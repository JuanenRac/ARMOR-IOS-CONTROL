import XCTest
@testable import ArmorCore

final class BatteryTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    func testAnOperationUnderWayIsReadWithItsProgress() {
        let op = BatteryParser.operation(json("""
        {"id":"op1","node":"n1","port":3,"op":"set_clock","stage":"running","atomic":true,"packets_sent":5,"packets_total":20,"steps_done":1,"steps_total":4,
         "battery":{"model":"US5000","serial":"ABCDEFGHIJ","soft_version":"v1"},"diff":[{"label":"Hora","before":"a","after":"b"}],"restore":{}}
        """))
        XCTAssertEqual([op.id, op.node, op.op, op.stage], ["op1", "n1", "set_clock", "running"])
        XCTAssertEqual(op.port, 3)
        XCTAssertTrue(op.active)
        XCTAssertTrue(op.atomic)
        XCTAssertEqual(op.percent, 25)
        XCTAssertEqual(op.model, "US5000")
        XCTAssertEqual(op.serial, "ABCDEFGHIJ")
        XCTAssertEqual(op.diff, [BatteryDiff(label: "Hora", before: "a", after: "b")])
        XCTAssertTrue(op.restorable)
    }

    func testTheProgressFallsBackToStepsAndAFinishedOperationIsComplete() {
        XCTAssertEqual(BatteryParser.operation(json(#"{"id":"a","stage":"running","steps_done":1,"steps_total":4}"#)).percent, 25)
        XCTAssertEqual(BatteryParser.operation(json(#"{"id":"a","stage":"armed"}"#)).percent, 0)
        let done = BatteryParser.operation(json(#"{"id":"a","stage":"done","packets_sent":1,"packets_total":9}"#))
        XCTAssertEqual(done.percent, 100)
        XCTAssertFalse(done.active)
        XCTAssertFalse(done.restorable)
    }

    func testTheListKeepsOnlyOperationsWithAnIdentifier() {
        let overview = BatteryParser.overview(json(#"{"enabled":true,"operations":[{"id":"a","stage":"done"},{"id":" "},{"stage":"x"}]}"#))
        XCTAssertTrue(overview.enabled)
        XCTAssertEqual(overview.operations.map(\.id), ["a"])
        XCTAssertFalse(BatteryParser.overview([:]).enabled)
    }

    func testTheGatewayNodesAreTheOnesWhoseBatteriesReport() {
        let solar = SolarParser.overview(json("""
        {"devices":[{"node_id":"b-node","device":"x","kind":"battery","reading":{}},{"node_id":"a-node","device":"y","kind":"battery","reading":{}},
                    {"node_id":"a-node","device":"z","kind":"battery","reading":{}},{"node_id":"c-node","device":"i","kind":"inverter","reading":{}}]}
        """))
        XCTAssertEqual(BatteryParser.nodes(solar), ["a-node", "b-node"])
        XCTAssertEqual(BatteryParser.nodes(nil), [])
    }

    func testASerialNumberIsAsTheNodeTakesIt() {
        for good in ["NOSERIAL", "ABCDEFGHIJ", "abc_def-1234", String(repeating: "A", count: 24)] { XCTAssertTrue(BatteryParser.serialLooksRight(good), good) }
        for bad in ["", "ABC", "AB CDEFGHIJK", String(repeating: "A", count: 25), "ABCDEFGHI!", "noserial"] { XCTAssertFalse(BatteryParser.serialLooksRight(bad), bad) }
    }

    func testThePhoneOffersOnlyTheSimpleOperations() {
        XCTAssertEqual(BatteryParser.phoneOperations.count, 9)
        XCTAssertTrue(BatteryParser.phoneOperations.contains("output_set"))
        XCTAssertEqual(BatteryParser.outputs, ["cfet", "dfet", "buzz", "heat"])
    }

    func testEveryOperationStageAndRiskHasWordsAndAnUnknownOneHasTheGeneralPhrase() {
        let t = plain("es")
        for op in BatteryParser.phoneOperations { XCTAssertFalse(BatteryText.operationName(op, t).isEmpty, op) }
        XCTAssertEqual(Set(BatteryParser.phoneOperations.map { BatteryText.operationName($0, t) }).count, 9)
        XCTAssertEqual(BatteryText.operationName("something", t), "Otra operación (en Studio)")
        XCTAssertEqual(BatteryText.stageName("armed", t), "Lista para hacer")
        XCTAssertEqual(BatteryText.stageName("withdrawn", t), "Retirada")
        XCTAssertEqual(BatteryText.riskName("medium", t), "medio")
        XCTAssertEqual(BatteryText.riskName("irreversible", t), "no se puede deshacer")
        XCTAssertEqual(BatteryText.outputName("buzz", t), "Zumbador")
    }

    func testARefusalIsToldInWordsThatSayWhatToDo() {
        let t = plain("es")
        XCTAssertTrue(BatteryText.refusalText("serial_mismatch", t).contains("número de serie"))
        XCTAssertTrue(BatteryText.refusalText("battery_write_disabled", t).contains("desactivada"))
        XCTAssertEqual(BatteryText.refusalText("disabled", t), BatteryText.refusalText("battery_write_disabled", t))
        XCTAssertEqual(BatteryText.refusalText("expired", t), "Prepara la operación de nuevo.")
        XCTAssertEqual(BatteryText.refusalText("???", t), "El nodo rechazó la operación.")
    }

    func testAnErrorOfTheServerIsToldByItsCode() {
        let t = plain("es")
        let busy = ArmorApiError(message: "x", status: 409, body: #"{"code":"busy"}"#)
        XCTAssertEqual(BatteryText.errorText(busy, t), BatteryText.refusalText("busy", t))
        XCTAssertEqual(BatteryText.errorText(NSError(domain: "x", code: 1), t), "No se pudo completar.")
    }

    func testTheResultOfAnOperationSaysWhetherItWorked() {
        let t = plain("es")
        func result(_ outcome: String) -> String { BatteryText.resultText(BatteryParser.operation(json("{\"id\":\"a\",\"stage\":\"done\",\"outcome\":\"\(outcome)\"}")), t) }
        XCTAssertTrue(result("ok").hasPrefix("Funcionó"))
        XCTAssertTrue(result("partial").contains("a medias"))
        XCTAssertTrue(result("retry").contains("volver a intentarlo"))
        XCTAssertTrue(result("rejected").contains("rechazó"))
        XCTAssertTrue(result("mismatch").contains("no coincide"))
    }
}
