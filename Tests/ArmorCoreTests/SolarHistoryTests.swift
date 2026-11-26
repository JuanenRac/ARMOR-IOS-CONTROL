// The history behind the solar charts: what the server sends, the bank added up and the ends of the axis. Made-up figures.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import XCTest
@testable import ArmorCore

final class SolarHistoryTests: XCTestCase {
    func testTheNumbersOfASampleAreReadAndTextIsLeftOut() throws {
        let text = #"{"module":2,"every_s":60,"retention_days":30,"samples":[{"t":1000,"voltage_v":50.5,"cell1":3.3,"mode":"line","soc_percent":null},{"voltage_v":1}]}"#
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let history = SolarHistoryMath.parse(root)
        XCTAssertEqual(history.module, 2)
        XCTAssertEqual(history.everyS, 60)
        XCTAssertEqual(history.retentionDays, 30)
        XCTAssertEqual(history.samples, [HistorySample(t: 1000, values: ["voltage_v": 50.5, "cell1": 3.3])])
        XCTAssertNil(SolarHistoryMath.parse(["samples": [Any]()]).module)
    }

    func testAStackGetsItsPowerAndTheSpreadOfItsCells() {
        let out = SolarHistoryMath.derived([HistorySample(t: 1, values: ["voltage_v": 50, "current_a": -2, "cell_min_v": 3.30, "cell_max_v": 3.35])])[0].values
        XCTAssertEqual(out["power_w"], -100)
        XCTAssertEqual(out["delta_mv"], 50)
    }

    func testTheBankAddsOnlyTheStepsEveryStackReported() {
        let one = [HistorySample(t: 0, values: ["voltage_v": 50, "current_a": 1]), HistorySample(t: 60_000, values: ["voltage_v": 50, "current_a": 3])]
        let two = [HistorySample(t: 10_000, values: ["voltage_v": 52, "current_a": 2])]
        let bank = SolarHistoryMath.mergeBank([one, two, []], bucketMs: 60_000)
        XCTAssertEqual(bank.count, 1)
        XCTAssertEqual(bank.first?.values["current_a"], 3)
        XCTAssertEqual(bank.first?.values["voltage_v"], 51)
        XCTAssertEqual(bank.first?.values["power_w"], 154)
        XCTAssertEqual(SolarHistoryMath.mergeBank([[]], bucketMs: 60_000), [])
    }

    func testTheAxisEndsAreRoundAndAFarLevelIsNotDrawn() {
        let scale = SolarHistoryMath.scale([3.31, 3.34])
        XCTAssertTrue(scale.low <= 3.31 && scale.high >= 3.34 && scale.high - scale.low < 0.1)
        XCTAssertEqual(SolarHistoryMath.scale([]).high, 1)
        XCTAssertEqual(SolarHistoryMath.levelsInView([3.3, 3.5], [3.6, 2.0]), [3.6])
        XCTAssertEqual(SolarHistoryMath.bankBucketMs(60), 60_000)
        XCTAssertEqual(SolarHistoryMath.bankBucketMs(43_200), 4_320_000)
    }
}
