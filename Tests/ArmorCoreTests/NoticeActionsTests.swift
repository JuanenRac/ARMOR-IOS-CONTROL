import XCTest
@testable import ArmorCore

final class NoticeActionsTests: XCTestCase {
    func testOnlyIdsOfTheServerAreActedOn() {
        for good in ["alm-00001", "a1", "ALM_7"] { XCTAssertTrue(NoticeActions.validAlarmId(good), good) }
        for bad in ["", "a b", "../x", "x/y", String(repeating: "x", count: 65), "a;b", "a\u{0}b"] { XCTAssertFalse(NoticeActions.validAlarmId(bad), bad) }
    }

    func testANoticeWithAKnownAlarmCarriesTheCategoryAndTheIdAndNothingElseDoes() {
        XCTAssertEqual(NoticeActions.category(alarmId: "alm-1"), NoticeActions.categoryId)
        XCTAssertEqual(NoticeActions.userInfo(alarmId: "alm-1"), ["alarm_id": "alm-1"])
        XCTAssertNil(NoticeActions.category(alarmId: nil))
        XCTAssertNil(NoticeActions.category(alarmId: "../x"))
        XCTAssertEqual(NoticeActions.userInfo(alarmId: nil), [:])
        XCTAssertEqual(NoticeActions.userInfo(alarmId: "a b"), [:])
    }

    func testTheIdIsReadBackOnlyWhenItIsOneTheAppMayActOn() {
        XCTAssertEqual(NoticeActions.alarmId(from: ["alarm_id": "alm-1"]), "alm-1")
        XCTAssertNil(NoticeActions.alarmId(from: ["alarm_id": "a b"]))
        XCTAssertNil(NoticeActions.alarmId(from: ["alarm_id": 5]))
        XCTAssertNil(NoticeActions.alarmId(from: [:]))
    }

    func testTheEventOfAnAlarmKnowsItsAlarmAndTheNoticeCarriesIt() throws {
        let json: [String: Any] = ["id": 7, "type": "alarm", "source": "smoke-1", "state": "raised", "severity": "critical", "code": "smoke", "source_type": "device", "alarm_id": "alm-00007", "at": "2030-01-01T00:00:00Z"]
        let event = try XCTUnwrap(ArmorEvent.parse(json))
        XCTAssertEqual(event.alarmId, "alm-00007")
        let notice = try XCTUnwrap(AlarmPolicy.notices([event], armed: true, Translator(language: "es")).first)
        XCTAssertEqual(notice.alarmId, "alm-00007")
        var withoutId = json; withoutId["alarm_id"] = nil
        let plain = try XCTUnwrap(AlarmPolicy.notices([try XCTUnwrap(ArmorEvent.parse(withoutId))], armed: true, Translator(language: "es")).first)
        XCTAssertNil(plain.alarmId)
    }
}
