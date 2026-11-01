import XCTest
@testable import ArmorCore

final class SolarTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    private let sample = """
    {"devices":[
     {"node_id":"solar-1","device":"inv1","kind":"inverter","stale":false,"example":false,"received_at":"t","registered":{"name":"Casa","model":"axpert-mks"},
      "reading":{"mode":"line","grid_v":230.1,"grid_hz":50,"out_w":420,"load_percent":12,"battery_v":52.4,"battery_a":-3.5,"battery_percent":80,"pv_v":120,"pv_w":900,"pv2_w":300,"heatsink_c":41,
                 "warnings":["line_fail"," "],"units":[{"unit":0,"mode":"line","fault_code":"00","out_w":210},{"unit":1,"mode":"fault","fault_code":"05","out_w":210}],"total_out_w":420}},
     {"node_id":"solar-1","device":"bat1","kind":"battery","stale":true,
      "reading":{"modules":2,"model":"US5000","state":"charging","voltage_v":51.2,"current_a":10,"soc_percent":79.6,"alarm":false,"cycles":120,
                 "stack":[{"n":1,"present":true,"cells_v":[3.3,3.31,3.29,3.3],"model":"US5000","counters":{"bat_ov_times":755,"coc_times":0,"other":9},"soh_counts":[1,2],"soh_abnormal":[1]},{"n":2,"present":false}]},
      "day_cells":{"bank_delta_v":0.021,"modules":[{"n":1,"min":{"v":3.29,"cell":3,"at":1000},"max":{"v":3.31,"cell":2,"at":2000},"delta_v":0.02}]},
      "events":[{"n":1,"seen_at":5,"event":{"index":3,"time":"2026-01-01 10:00","voltage_state":"Normal","power_events":"","battery_events":"x","system_fault":""}},{"n":0,"event":{"time":"t"}}]},
     {"node_id":"","device":"x","kind":"inverter","reading":{}},
     {"node_id":"n","device":"d","kind":"mystery","reading":{}}
    ],
    "waiting":[{"node_id":"solar-2","device":"inv2","name":"","kind":"inverter","model":""},{"node_id":"","device":"z"}],
    "totals":{"inverters":1,"batteries":1,"stale":0,"pv_w":1200,"load_w":420,"battery_w":-512.5,"soc_percent":79.6,"grid_present":true,"mode":"line","energy_kwh":4.25}}
    """

    func testAnInverterIsReadWithItsSecondInputItsUnitsAndItsWarnings() throws {
        let overview = SolarParser.overview(json(sample))
        XCTAssertEqual(overview.devices.count, 2)
        let device = overview.devices[0]
        XCTAssertTrue(device.isInverter)
        XCTAssertEqual(device.name, "Casa")
        XCTAssertEqual(device.model, "axpert-mks")
        let r = try XCTUnwrap(device.inverter)
        XCTAssertEqual(r.mode, "line")
        XCTAssertEqual(r.gridV, 230.1)
        XCTAssertEqual(r.pvW, 900)
        XCTAssertEqual(r.pv2W, 300)
        XCTAssertNil(r.pv2V)
        XCTAssertEqual(r.warnings, ["line_fail"])
        XCTAssertEqual(r.units.count, 2)
        XCTAssertEqual(r.units[1].faultCode, "05")
        XCTAssertEqual(r.totalOutW, 420)
    }

    func testABatteryKeepsOnlyTheModulesThatAreThereItsCellsItsCountersAndItsDay() throws {
        let device = SolarParser.overview(json(sample)).devices[1]
        XCTAssertEqual(device.name, "bat1")
        XCTAssertTrue(device.stale)
        let r = try XCTUnwrap(device.battery)
        XCTAssertEqual(r.socPercent, 80)
        XCTAssertEqual(try XCTUnwrap(r.powerW), 512, accuracy: 0.001)
        XCTAssertEqual(r.stack.count, 1)
        XCTAssertEqual(r.stack[0].cellsV.count, 4)
        XCTAssertEqual(r.stack[0].counters["bat_ov_times"], 755)
        XCTAssertEqual(r.stack[0].sohAbnormal, [1])
        XCTAssertEqual(SolarText.abnormalCells(r.stack[0]), [2])
        let day = try XCTUnwrap(device.dayCells)
        XCTAssertEqual(day.bankDeltaV, 0.021, accuracy: 0.0001)
        XCTAssertEqual(day.modules[0].minCell, 3)
        XCTAssertEqual(day.modules[0].minAt, 1000)
        XCTAssertEqual(device.events.count, 1)
        XCTAssertEqual(device.events[0].event.index, 3)
        XCTAssertEqual(device.events[0].module, 1)
    }

    func testDevicesWithoutNodeOrOfAnUnknownKindAreLeftOutAndAWaitingOneTakesItsDeviceAsName() {
        let overview = SolarParser.overview(json(sample))
        XCTAssertEqual(overview.devices.map(\.id), ["solar-1/inv1", "solar-1/bat1"])
        XCTAssertEqual(overview.waiting.count, 1)
        XCTAssertEqual(overview.waiting[0].name, "inv2")
        XCTAssertFalse(overview.isEmpty)
    }

    func testTheTotalsAreReadAndAnEmptyAnswerReadsAsNothing() {
        let totals = SolarParser.overview(json(sample)).totals
        XCTAssertEqual(totals.pvW, 1200)
        XCTAssertEqual(totals.batteryW, -512.5)
        XCTAssertEqual(totals.socPercent, 80)
        XCTAssertTrue(totals.gridPresent)
        XCTAssertEqual(totals.mode, "line")
        XCTAssertEqual(totals.energyKwh, 4.25)
        XCTAssertNil(totals.capacityAh)
        let empty = SolarParser.overview([:])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertNil(empty.totals.batteryW)
        XCTAssertNil(empty.totals.mode)
    }

    func testTheProtectionCountersAreNamedAsTheConsolePrintsThemAndOnlyTheRaisedOnesShow() {
        XCTAssertEqual(SolarText.counterLabel("bat_ov_times"), "Bat OV Times")
        XCTAssertEqual(SolarText.counterLabel("coc2_times"), "COC2 Times")
        XCTAssertEqual(SolarText.raisedCounters(["bat_ov_times": 755, "coc_times": 1, "other_times": 9, "sc_times": 0]), "Bat OV Times 755 · COC Times 1")
        XCTAssertEqual(SolarText.raisedCounters([:]), "")
    }

    private func stack(_ models: [(Int, String)]) -> [SolarModule] {
        let modules = models.map { "{\"n\":\($0.0),\"present\":true,\"model\":\"\($0.1)\"}" }.joined(separator: ",")
        let device = SolarParser.device(json("{\"node_id\":\"n\",\"device\":\"d\",\"kind\":\"battery\",\"reading\":{\"modules\":\(models.count),\"stack\":[\(modules)]}}"))
        return device?.battery?.stack ?? []
    }

    func testTheGenerationOfAModelIgnoresCaseSpacesAndDashes() {
        XCTAssertEqual(SolarText.generation("US-5000"), 2)
        XCTAssertEqual(SolarText.generation("us2000b plus"), 1)
        XCTAssertEqual(SolarText.generation("Mystery"), 0)
    }

    func testMixingModelsGivesAWarningNeverABlock() {
        let mixed = SolarText.composition(stack([(1, "US2000"), (2, "US5000"), (9, "US3000")]))
        XCTAssertEqual(mixed.map(\.code), ["beyond8", "master"])
        XCTAssertEqual(mixed[0].modules, [9])
        XCTAssertEqual(mixed[1].modules, [2])
        let voltage = SolarText.composition(stack([(1, "UP2500"), (2, "US5000")]))
        XCTAssertEqual(voltage.map(\.code), ["voltage"])
        XCTAssertEqual(voltage[0].modules, [1])
        XCTAssertTrue(SolarText.composition(stack([(1, "US5000"), (2, "US5000")])).isEmpty)
        XCTAssertTrue(SolarText.composition(stack([(1, "Mystery"), (2, "US5000")])).isEmpty)
    }

    func testTheNamesOfTheModelsOfTheCatalogue() {
        XCTAssertEqual(SolarText.model("pylontech-us5000"), "Pylontech US5000")
        XCTAssertEqual(SolarText.model("ant-bms-16s-100a"), "ANT-BMS 16S · 100 A")
        XCTAssertEqual(SolarText.model("other"), "")
        XCTAssertEqual(SolarText.model(""), "")
        XCTAssertEqual(SolarText.model("weird"), "weird")
        XCTAssertEqual(SolarText.warning("line_fail"), "line fail")
    }

    func testTheNumbersAreShownWithTheirUnitsAndADashWhenMissing() {
        XCTAssertEqual(SolarText.watts(1500), "1.50 kW")
        XCTAssertEqual(SolarText.watts(-1500), "-1.50 kW")
        XCTAssertEqual(SolarText.watts(420.4), "420 W")
        XCTAssertEqual(SolarText.watts(nil), "—")
        XCTAssertEqual(SolarText.volts(52.456, 2), "52.46 V")
        XCTAssertEqual(SolarText.amps(-3.5), "-3.5 A")
        XCTAssertEqual(SolarText.hertz(50), "50.0 Hz")
        XCTAssertEqual(SolarText.celsius(41.4), "41 °C")
        XCTAssertEqual(SolarText.ah(24), "24.0 Ah")
        XCTAssertEqual(SolarText.cell(3.3124), "3.312")
        XCTAssertEqual(SolarText.percent(79.6 as Double?), "80 %")
        let none: Int? = nil
        XCTAssertEqual(SolarText.percent(none), "—")
        XCTAssertEqual(SolarText.percent(42 as Int?), "42 %")
    }

    func testTheSpreadOfTheCellsIsInMillivoltsAndNeedsTwoCells() {
        XCTAssertEqual(SolarText.cellSpreadMv([3.30, 3.31, 3.29]), 20)
        XCTAssertNil(SolarText.cellSpreadMv([3.3]))
        XCTAssertNil(SolarText.cellSpreadMv([]))
    }

    func testWhatTheBatteriesDoIsOnePhrase() {
        let t = plain("es")
        XCTAssertEqual(SolarText.batteryFlow(340, t), "Cargando · 340 W")
        XCTAssertEqual(SolarText.batteryFlow(-340, t), "Descargando · 340 W")
        XCTAssertEqual(SolarText.batteryFlow(5, t), "En reposo")
        XCTAssertEqual(SolarText.batteryFlow(nil, t), "Sin dato")
        XCTAssertEqual(SolarText.mode("battery", t), "Con la batería")
        XCTAssertEqual(SolarText.mode("nonsense", t), "Sin dato")
        XCTAssertEqual(SolarText.batteryState("charging", t), "Cargando")
    }

    func testTheReachOfACellToday() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        XCTAssertEqual(SolarText.reach(volts: 3.312, cell: 5, atMs: 50_520_000, cellWord: "celda", timeZone: utc), "3.312 V (celda 5, 14:02)")
    }

    func testTheLevelOfChargeSetsTheColour() {
        XCTAssertEqual(SolarText.socLevel(nil), "none")
        XCTAssertEqual(SolarText.socLevel(10), "alert")
        XCTAssertEqual(SolarText.socLevel(20), "warn")
        XCTAssertEqual(SolarText.socLevel(39), "warn")
        XCTAssertEqual(SolarText.socLevel(40), "ok")
    }

    func testTheStatusLineGivesTheSunAndTheConsumptionOrTheBatteriesAlone() {
        let t = plain("es")
        var totals = SolarTotals()
        totals.batteryW = 340
        XCTAssertEqual(SolarText.summary(totals, t), "Baterías: Cargando · 340 W")
        totals.inverters = 1; totals.pvW = 2400; totals.loadW = 1180
        XCTAssertEqual(SolarText.summary(totals, t), "2.40 kW de sol · 1.18 kW de consumo")
    }
}
