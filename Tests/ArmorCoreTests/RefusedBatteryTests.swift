// ARMOR-IOS-CONTROL - which battery stacks the server is refusing. Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import XCTest
@testable import ArmorCore

final class RefusedBatteryTests: XCTestCase {
    private func topic(_ name: String, _ errorAt: String?, _ okAt: String?, _ kind: String = "battery") -> JSON {
        var item: JSON = ["topic": name, "last_error": "balancing too high", "last_payload": "{\"kind\": \"\(kind)\"}"]
        if let errorAt { item["last_error_at"] = errorAt }
        if let okAt { item["last_ok_at"] = okAt }
        return item
    }

    func testOnlyTheStacksRefusedSinceTheLastReading() {
        let topics: [Any] = [
            topic("armor/solar/n1/stack/state", "2026-01-02T10:00:00Z", "2026-01-02T09:00:00Z"),
            topic("armor/solar/n1/old/state", "2026-01-02T08:00:00Z", "2026-01-02T09:00:00Z"),
            topic("armor/solar/n1/inv/state", "2026-01-02T10:00:00Z", nil, "inverter"),
            topic("armor/solar/n1/fine/state", nil, "2026-01-02T09:00:00Z"),
            topic("armor/alarm/n2/state", "2026-01-02T10:00:00Z", nil),
        ]
        XCTAssertEqual(RefusedBattery.fromIngest(["topics": topics]), [RefusedBattery(name: "n1 / stack", reason: "balancing too high")])
        XCTAssertEqual(RefusedBattery.fromIngest([:]), [])
    }
}
