import XCTest
@testable import ArmorCore

/// Every cell of a battery reaches the screen and is judged: the fifteen of a Pylontech 48 V module and the sixteen of a 51.2 V one.
final class SolarCellsTests: XCTestCase {
    private let settings = SolarViewSettings()

    private func volts(_ count: Int, _ change: [Int: Double] = [:]) -> [Double] { (1...count).map { change[$0] ?? (3.3 + Double($0) / 1000) } }

    private func module(_ n: Int, _ cells: [Double], _ extra: String = "") -> String {
        let list = cells.map { String(format: "%.3f", $0) }.joined(separator: ",")
        return "{\"n\":\(n),\"present\":true,\"cells_v\":[\(list)]\(extra)}"
    }

    private func battery(_ model: String, _ modules: [String]) throws -> SolarBatteryReading {
        let text = "{\"devices\":[{\"node_id\":\"n\",\"device\":\"b\",\"kind\":\"battery\",\"registered\":{\"model\":\"\(model)\"},\"reading\":{\"modules\":\(modules.count),\"stack\":[\(modules.joined(separator: ","))]}}]}"
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? JSON)
        return try XCTUnwrap(SolarParser.overview(json).devices.first?.battery)
    }

    func testTheFifteenAndSixteenCellsOfEveryModuleOfAFullStackAreAllKept() throws {
        for count in [15, 16] {
            let reading = try battery("pylontech-us3000", (1...8).map { module($0, volts(count)) })
            let bank = SolarCells.bank(deviceModel: "pylontech-us3000", reading: reading, settings: settings)
            XCTAssertEqual(bank.modules.count, 8)
            for view in bank.modules {
                XCTAssertEqual(view.cells.map(\.number), Array(1...count))
                XCTAssertTrue(view.cells[0].lowest)
                XCTAssertTrue(view.cells[count - 1].highest)
            }
            XCTAssertEqual(bank.level, .ok)
            XCTAssertEqual(bank.spreadMv, count - 1)
        }
    }

    func testACellOutOfRangeOrMarkedAbnormalIsToldByItsNumber() throws {
        let reading = try battery("pylontech-us2000", [module(1, volts(15, [10: 2.60, 15: 3.62]), ",\"soh_abnormal\":[12]")])
        let view = try XCTUnwrap(SolarCells.bank(deviceModel: "pylontech-us2000", reading: reading, settings: settings).modules.first)
        XCTAssertEqual(view.cells[9].level, .fault)
        XCTAssertEqual(view.cells[14].level, .warn)
        XCTAssertEqual(view.cells[12].level, .fault)
        XCTAssertEqual(view.trouble.abnormalCells, [13])
        XCTAssertEqual(view.trouble.outOfRangeCells, [10, 15])
        XCTAssertEqual(view.trouble.spreadMv, 1020)
        XCTAssertEqual(view.level, .fault)
    }

    func testAFaultStateHeatColdAndMissingCellsAreNotLost() throws {
        let reading = try battery("pylontech-us2000", [
            module(1, volts(15), ",\"state\":\"Alarm\""),
            module(2, volts(15), ",\"temperature_c\":61"),
            module(3, volts(15), ",\"state\":\"Charge\",\"temperatures_c\":[-3]"),
            module(4, volts(9), ",\"cell_count\":15"),
            module(5, volts(15), ",\"state\":\"Dischg\",\"temperatures_c\":[-3]"),
        ])
        let bank = SolarCells.bank(deviceModel: "pylontech-us2000", reading: reading, settings: settings)
        XCTAssertEqual(bank.modules.map(\.level), [.fault, .warn, .warn, .warn, .ok])
        XCTAssertEqual(bank.modules[3].trouble.missingCells, 6)
        XCTAssertEqual(bank.faultModules, 1)
        XCTAssertEqual(bank.warnModules, 3)
    }

    func testTheAbsoluteVoltageIsJudgedOnlyForLithiumIronPhosphate() throws {
        XCTAssertTrue(SolarCells.isLfp(deviceModel: "pylontech-us5000", readingModel: ""))
        XCTAssertTrue(SolarCells.isLfp(deviceModel: "", readingModel: "US3000C"))
        XCTAssertFalse(SolarCells.isLfp(deviceModel: "ant-bms-14s-100", readingModel: "ANT-BMS"))
        XCTAssertFalse(SolarCells.isLfp(deviceModel: "other", readingModel: ""))
        let reading = try battery("ant-bms", [module(1, Array(repeating: 4.10, count: 14))])
        XCTAssertEqual(SolarCells.bank(deviceModel: "ant-bms", reading: reading, settings: settings).level, .ok)
    }

    func testTheShippedSettingsAreTheDefaultsAndTheBlinkNeverGoesFasterThanTwiceASecond() {
        XCTAssertEqual(SolarViewSettings.bundled(), SolarViewSettings())
        XCTAssertEqual(SolarViewSettings.parse(Data("{\"blink_period_ms\":50}".utf8)).blinkPeriodMs, 500)
        XCTAssertEqual(SolarViewSettings.parse(Data("not json".utf8)), SolarViewSettings())
    }
}
