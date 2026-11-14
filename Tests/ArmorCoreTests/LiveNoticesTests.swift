import XCTest
@testable import ArmorCore

final class LiveNoticesTests: XCTestCase {
    func testANoticeOfAKnownKindIsReadWithItsIdAndVersionAndNothingElseTravels() {
        for type in LiveNotices.types { XCTAssertEqual(LiveNotices.parse("{\"type\":\"\(type)\",\"id\":\"alm-00001\",\"version\":12}"), LiveNotice(type: type, id: "alm-00001", version: 12)) }
        XCTAssertEqual(LiveNotices.parse("{\"type\":\"alarm\",\"id\":\"a\",\"version\":1,\"detail\":\"not kept\"}"), LiveNotice(type: "alarm", id: "a", version: 1))
    }

    func testTheStateAnUnknownKindAMissingOrWrongFieldTextThatIsNotJsonAndAHugeMessageAreIgnored() {
        XCTAssertNil(LiveNotices.parse("{\"type\":\"state\",\"state\":{}}"))
        XCTAssertNil(LiveNotices.parse("{\"type\":\"weather\",\"id\":\"x\",\"version\":1}"))
        XCTAssertNil(LiveNotices.parse("{\"type\":\"alarm\",\"version\":1}"))
        XCTAssertNil(LiveNotices.parse("{\"type\":\"alarm\",\"id\":5,\"version\":1}"))
        XCTAssertNil(LiveNotices.parse("{\"type\":\"alarm\",\"id\":\"a\"}"))
        XCTAssertNil(LiveNotices.parse("{\"type\":\"alarm\",\"id\":\"a\",\"version\":\"1\"}"))
        XCTAssertNil(LiveNotices.parse("{\"type\":\"alarm\",\"id\":\"\(String(repeating: "x", count: 65))\",\"version\":1}"))
        XCTAssertNil(LiveNotices.parse("not json"))
        XCTAssertNil(LiveNotices.parse(nil))
        XCTAssertNil(LiveNotices.parse(String(repeating: "x", count: 2000)))
    }

    func testTheAddressOfTheChannelFollowsTheSchemeOfTheServer() {
        XCTAssertEqual(LiveNotices.url("http://192.168.0.180:18080")?.absoluteString, "ws://192.168.0.180:18080/api/v1/events")
        XCTAssertEqual(LiveNotices.url("https://armor.example.org/")?.absoluteString, "wss://armor.example.org/api/v1/events")
        XCTAssertNil(LiveNotices.url("ftp://host"))
        XCTAssertNil(LiveNotices.url(""))
    }

    func testTheWaitBeforeTheNextTryStartsAtTwoSecondsDoublesAndStopsAtAMinute() {
        XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 20].map(LiveNotices.retryDelay), [2, 4, 8, 16, 32, 60, 60, 60])
        XCTAssertEqual(LiveNotices.retryDelay(0), 2)
    }

    func testTheScreensAskSlowlyOnlyWhileANoticeArrivedWithinTheLastMinute() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(LiveNotices.pollDelay(base: 5, lastNotice: nil, now: now), 5)
        XCTAssertEqual(LiveNotices.pollDelay(base: 5, lastNotice: now.addingTimeInterval(-5), now: now), 30)
        XCTAssertEqual(LiveNotices.pollDelay(base: 10, lastNotice: now.addingTimeInterval(-60), now: now), 30)
        XCTAssertEqual(LiveNotices.pollDelay(base: 5, lastNotice: now.addingTimeInterval(-61), now: now), 5)
        XCTAssertEqual(LiveNotices.pollDelay(base: 5, lastNotice: now.addingTimeInterval(5), now: now), 5)
        XCTAssertEqual(LiveNotices.pollDelay(base: 45, lastNotice: now, now: now), 45, "a pace already slower is kept")
    }
}
