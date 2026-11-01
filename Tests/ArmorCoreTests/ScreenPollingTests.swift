import XCTest
@testable import ArmorCore

final class ScreenPollingTests: XCTestCase {
    func testTheFileShippedInThePackageGivesTheDefaults() {
        XCTAssertEqual(ScreenPolling.bundled(), ScreenPolling.defaults)
        XCTAssertEqual(ScreenPolling.defaults.batterySeconds, 2)
    }

    func testAPaceIsKeptBetweenTheMinimumAndTheMaximumOfTheFile() {
        let fast = ScreenPolling.parse(["solar_seconds": 0.1, "electrical_seconds": 9999, "battery_seconds": 3])
        XCTAssertEqual(fast.solarSeconds, 1)
        XCTAssertEqual(fast.electricalSeconds, 300)
        XCTAssertEqual(fast.batterySeconds, 3)
        let limited = ScreenPolling.parse(["minimum_seconds": 2, "maximum_seconds": 10, "solar_seconds": 1, "electrical_seconds": 60])
        XCTAssertEqual(limited.solarSeconds, 2)
        XCTAssertEqual(limited.electricalSeconds, 10)
    }

    func testAMissingValueTakesTheDefaultAndAMinimumBelowHalfASecondIsRaised() {
        XCTAssertEqual(ScreenPolling.parse([:]), ScreenPolling.defaults)
        XCTAssertEqual(ScreenPolling.parse(["minimum_seconds": 0, "solar_seconds": 0]).solarSeconds, 0.5)
    }
}
