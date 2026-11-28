// The three levels of a battery's states, and a module that does not read three of its cells (invented figures).
import XCTest
@testable import ArmorCore

final class BatteryStatesTests: XCTestCase {
    func testANoticeAProtectionAndAFault() {
        XCTAssertEqual(BatteryState(column: "voltage", word: "High").level, 1)
        XCTAssertEqual(BatteryState(column: "system", word: "High").level, 2)
        XCTAssertEqual(BatteryState(column: "voltage", word: "NeverSeen").level, 2)
        XCTAssertEqual(BatteryState(column: "base", word: "SysError").level, 3)
    }

    func testCellsThatAreNotReadAreAFaultAndNotTheLowestCell() throws {
        let cells = (0..<15).map { (3...5).contains($0) ? "0" : "3.33" }.joined(separator: ",")
        let module = "{\"n\":1,\"present\":true,\"cells_v\":[\(cells)],\"cells_unread\":[3,4,5],\"manufacturer\":\"Pylon\",\"manufacturer_source\":\"reported\",\"flags\":[{\"column\":\"voltage\",\"word\":\"UV\",\"cell\":3}]}"
        let text = "{\"devices\":[{\"node_id\":\"n\",\"device\":\"b\",\"kind\":\"battery\",\"reading\":{\"modules\":1,\"stack\":[\(module)]}}]}"
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let reading = try XCTUnwrap(SolarParser.overview(json).devices.first?.battery)
        XCTAssertEqual(reading.stack.first?.manufacturer, "Pylon")
        let bank = SolarCells.bank(deviceModel: "pylontech-us2000", reading: reading, settings: SolarViewSettings())
        let view = try XCTUnwrap(bank.modules.first)
        XCTAssertEqual(view.trouble.unreadCells, [4, 5, 6])
        XCTAssertTrue(view.trouble.bmsFault)
        XCTAssertEqual(view.level, .fault)
        XCTAssertEqual(bank.minV ?? 0, 3.33, accuracy: 0.001)
    }

    func testAModuleThatDoesNotAnswerItsDataSheetIsSaidSo() throws {
        let told = "{\"n\":1,\"present\":true,\"cells_v\":[3.31,3.32],\"cycles\":12,\"soft_version\":\"V2.4\"}"
        let mute = "{\"n\":2,\"present\":true,\"cells_v\":[3.31,3.32]}"
        let text = "{\"devices\":[{\"node_id\":\"n\",\"device\":\"b\",\"kind\":\"battery\",\"reading\":{\"modules\":2,\"stack\":[\(told),\(mute)]}}]}"
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let reading = try XCTUnwrap(SolarParser.overview(json).devices.first?.battery)
        let bank = SolarCells.bank(deviceModel: "pylontech-us2000", reading: reading, settings: SolarViewSettings())
        XCTAssertEqual(bank.modules.map(\.trouble.noSheet), [false, true])
        XCTAssertFalse(SolarCells.sheetUnanswered(reading.stack[1], in: [reading.stack[1]]))
    }
}
