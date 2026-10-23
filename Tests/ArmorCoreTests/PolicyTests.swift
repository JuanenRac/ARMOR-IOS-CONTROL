import XCTest
@testable import ArmorCore

final class PolicyTests: XCTestCase {
    private let t = plain()
    private func event(_ id: Int, _ type: String, to: String? = nil, subject: String = "n1", code: String? = nil, source: String? = nil, severity: String? = nil) -> ArmorEvent {
        ArmorEvent(id: id, at: "", type: type, subject: subject, from: nil, to: to, targets: 2, mode: nil, severity: severity, code: code, sourceType: source)
    }
    func testFirstCallOnlyRecordsABaseline() {
        let seen = SeenEvents()
        XCTAssertTrue(seen.fresh([event(5, "node"), event(7, "node")]).isEmpty)
        XCTAssertEqual(seen.last, 7)
        XCTAssertEqual(seen.fresh([event(7, "node"), event(9, "node"), event(8, "node")]).map(\.id), [8, 9])
        XCTAssertTrue(seen.fresh([event(9, "node")]).isEmpty)
    }
    func testNoticesForAlertsCamerasAndDevices() {
        let events = [
            event(3, "alert", to: "high"),
            event(1, "camera", to: "offline", subject: "cam1"),
            event(2, "alarm", to: "raised", code: "smoke", source: "device", severity: "critical"),
            event(4, "alarm", to: "raised", code: "intrusion", source: "node"),
        ]
        let notices = AlarmPolicy.notices(events, armed: true, t)
        XCTAssertEqual(notices.map(\.id), [1, 2, 3])
        XCTAssertEqual(notices[1].severity, "critical")
        XCTAssertEqual(notices[1].title, "ALARMA CRÍTICA")
    }
    func testNodesOnlyWakeYouWhileArmed() {
        let e = [event(1, "node", to: "offline"), event(2, "node", to: "stale")]
        XCTAssertEqual(AlarmPolicy.notices(e, armed: true, t).count, 2)
        XCTAssertTrue(AlarmPolicy.notices(e, armed: false, t).isEmpty)
    }
    func testDuressIsNeverAnnounced() {
        XCTAssertTrue(AlarmPolicy.notices([event(1, "alarm", to: "raised", code: "duress_disarm", source: "alarm")], armed: true, t).isEmpty)
    }
    func testDescribeLines() {
        XCTAssertEqual(AlarmPolicy.describe(ArmorEvent(id: 1, at: "", type: "mode", subject: "", from: nil, to: nil, targets: nil, mode: "armed"), t), "Sistema ARMADO")
        XCTAssertEqual(AlarmPolicy.describe(event(2, "node", to: "stale"), t), "n1: en silencio")
    }
    func testAlarmTextCoversTheCodesOfTheServer() {
        for code in ["intrusion", "node_down", "smoke", "alarm_sounding", "duress_disarm", "solar_fault", "network_port_opened"] {
            XCTAssertNotEqual(AlarmText.text(code, t), code, code)
        }
        XCTAssertEqual(AlarmText.text("something_new", t), "something_new")
    }
}
