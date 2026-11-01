import XCTest
@testable import ArmorCore

final class AlarmRouteTests: XCTestCase {
    func testEachSourceOpensTheScreenThatHandlesIt() {
        XCTAssertEqual(AlarmRoute.of(sourceType: "camera", code: "x"), .cameras)
        XCTAssertEqual(AlarmRoute.of(sourceType: "device", code: "x"), .devices)
        XCTAssertEqual(AlarmRoute.of(sourceType: "electrical", code: "grid_lost"), .electrical)
        XCTAssertEqual(AlarmRoute.of(sourceType: "network", code: "x"), .network)
        XCTAssertEqual(AlarmRoute.of(sourceType: "alarm", code: "x"), .alarmPanels)
        XCTAssertEqual(AlarmRoute.of(sourceType: "node", code: "x"), .radar)
        XCTAssertEqual(AlarmRoute.of(sourceType: "mystery", code: "x"), .alarms)
    }

    func testSolarAlarmsAboutABatteryOpenTheBatteriesAndTheOthersTheInverters() {
        XCTAssertEqual(AlarmRoute.of(sourceType: "solar", code: "solar_battery_low"), .batteries)
        XCTAssertEqual(AlarmRoute.of(sourceType: "solar", code: "PYLON_protect"), .batteries)
        XCTAssertEqual(AlarmRoute.of(sourceType: "solar", code: "solar_inverter_fault"), .solar)
    }
}
