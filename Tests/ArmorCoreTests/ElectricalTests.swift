import XCTest
@testable import ArmorCore

final class ElectricalTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    private let sample = """
    {"nodes":[
      {"node_id":"e1","stale":false,"reading":{"switching_enabled":false,
        "channels":[{"id":"grid","domain":"ac","label":"","voltage_v":231.2,"current_a":12.5,"power_w":2870,"energy_kwh":1234.56,"frequency_hz":50,"power_factor":0.98,"state":"closed","alarm":true},
                    {"id":"bus","domain":"dc","label":"Bus","power_w":null},{"label":"no id"}],
        "switches":[{"id":"ats","source_a":"grid","source_b":"","a_closed":true,"selected":"a","fault":"did_not_close"},{"label":"x"}]}},
      {"node_id":"e2"},{"reading":{}}],
     "totals":{"nodes":1,"channels":2,"stale":0,"grid_w":-300,"grid_kwh":12.5,"alarms":1}}
    """

    func testANodeIsReadWithItsChannelsAndItsSwitches() {
        let overview = ElectricalParser.overview(json(sample))
        XCTAssertEqual(overview.nodes.map(\.nodeId), ["e1"])
        let node = overview.nodes[0]
        XCTAssertEqual(node.switchingEnabled, false)
        XCTAssertEqual(node.channels.map(\.name), ["grid", "Bus"])
        let grid = node.channels[0]
        XCTAssertEqual(grid.powerW, 2870)
        XCTAssertEqual(grid.powerFactor, 0.98)
        XCTAssertEqual(grid.state, "closed")
        XCTAssertTrue(grid.alarm)
        XCTAssertNil(node.channels[1].powerW)
        XCTAssertNil(node.channels[1].state)
        XCTAssertEqual(node.channels[1].domain, "dc")
        XCTAssertEqual(node.switches.count, 1)
        XCTAssertEqual(node.switches[0].name, "ats")
        XCTAssertNil(node.switches[0].sourceB)
        XCTAssertEqual(node.switches[0].selected, "a")
        XCTAssertFalse(overview.isEmpty)
    }

    func testTheTotalsAreReadAndAnEmptyAnswerIsEmpty() {
        let totals = ElectricalParser.overview(json(sample)).totals
        XCTAssertEqual(totals.gridW, -300)
        XCTAssertEqual(totals.gridKwh, 12.5)
        XCTAssertEqual(totals.alarms, 1)
        let empty = ElectricalParser.overview([:])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertNil(empty.totals.gridW)
    }

    func testTheNumbersAreShownWithTheirUnits() {
        XCTAssertEqual(ElectricalText.watts(2870), "2.87 kW")
        XCTAssertEqual(ElectricalText.watts(420), "420 W")
        XCTAssertEqual(ElectricalText.watts(nil), "—")
        XCTAssertEqual(ElectricalText.volts(231.24), "231.2 V")
        XCTAssertEqual(ElectricalText.amps(12.5), "12.50 A")
        XCTAssertEqual(ElectricalText.kwh(1234.56), "1234.6 kWh")
        XCTAssertEqual(ElectricalText.kwh(nil), "—")
    }

    func testTheGridInputSaysWhichWayThePowerGoes() {
        let t = plain("es")
        XCTAssertEqual(ElectricalText.gridFlow(2870, t), "Consume 2.87 kW de la red")
        XCTAssertEqual(ElectricalText.gridFlow(-1200, t), "Cede 1.20 kW a la red")
        XCTAssertEqual(ElectricalText.gridFlow(2, t), "Sin consumo de red")
        XCTAssertEqual(ElectricalText.gridFlow(nil, t), "Sin dato")
    }

    func testASwitchSaysItsSourceItsStateAndItsFault() {
        let t = plain("es")
        let item = ElectricalParser.overview(json(sample)).nodes[0].switches[0]
        XCTAssertEqual(ElectricalText.switchSource(item, t), "Fuente A (grid)")
        XCTAssertEqual(ElectricalText.switchFault("did_not_close", t), "No cerró")
        XCTAssertNil(ElectricalText.switchFault("none", t))
        XCTAssertEqual(ElectricalText.switchState("closed", t), "Cerrado")
        XCTAssertEqual(ElectricalText.switchState("unknown", t), "Sin confirmar")
        XCTAssertNil(ElectricalText.switchState(nil, t))
        let none = ElectricalParser.overview(json("{\"nodes\":[{\"node_id\":\"e\",\"reading\":{\"switches\":[{\"id\":\"s\"}]}}]}")).nodes[0].switches[0]
        XCTAssertEqual(ElectricalText.switchSource(none, t), "Ninguna fuente")
        XCTAssertEqual(none.fault, "none")
    }
}
