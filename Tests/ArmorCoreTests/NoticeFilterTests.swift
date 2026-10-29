import XCTest
@testable import ArmorCore

final class NoticeFilterTests: XCTestCase {
    private func notice(_ severity: String, _ kind: String) -> AlarmNotice { AlarmNotice(id: 1, title: "t", text: "x", severity: severity, kind: kind) }

    func testByDefaultEveryNoticeShowsAsBefore() {
        let settings = NoticeSettings()
        for kind in NoticeKinds.choices + [NoticeKinds.system] {
            for severity in ["critical", "high", "warning"] { XCTAssertEqual(settings.decide(notice(severity, kind)), .show) }
        }
    }

    func testSilencingEverythingHidesEveryNoticeTheCriticalOnesToo() {
        let settings = NoticeSettings(muted: true)
        XCTAssertEqual(settings.decide(notice("critical", "alarm.device")), .hide)
        XCTAssertEqual(settings.decide(notice("warning", "camera")), .hide)
    }

    func testASeverityOrAKindSwitchedOffHidesTheNoticeButNeverACriticalOne() {
        let settings = NoticeSettings().withSeverity("warning", off: true).withKind("alarm.network", off: true)
        XCTAssertEqual(settings.decide(notice("warning", "camera")), .hide)
        XCTAssertEqual(settings.decide(notice("high", "alarm.network")), .hide)
        XCTAssertEqual(settings.decide(notice("high", "camera")), .show)
        XCTAssertEqual(settings.decide(notice("critical", "alarm.network")), .show)
    }

    func testWithoutSoundShowsTheNoticeQuietlyExceptTheCriticalOnes() {
        let settings = NoticeSettings(silent: true)
        XCTAssertEqual(settings.decide(notice("high", "alert")), .silent)
        XCTAssertEqual(settings.decide(notice("warning", "node")), .silent)
        XCTAssertEqual(settings.decide(notice("critical", "alarm.device")), .show)
    }

    func testSwitchingBackOnShowsAgain() {
        let off = NoticeSettings().withKind("node", off: true).withSeverity("high", off: true)
        let on = off.withKind("node", off: false).withSeverity("high", off: false)
        XCTAssertEqual(on, NoticeSettings())
    }

    func testTheChoicesAreKeptAndReadBackAndADamagedTextMeansEverythingShows() {
        let settings = NoticeSettings(muted: false, silent: true).withSeverity("high", off: true).withKind("node", off: true).withKind("alarm.solar", off: true)
        XCTAssertEqual(NoticeSettings.decode(settings.encode()), settings)
        XCTAssertEqual(NoticeSettings.decode(nil), NoticeSettings())
        XCTAssertEqual(NoticeSettings.decode("nonsense"), NoticeSettings())
        XCTAssertEqual(NoticeSettings.decode("false|false|critical,bogus|moon"), NoticeSettings())
        XCTAssertEqual(NoticeSettings.decode("a|b|c"), NoticeSettings())
    }

    func testTheChoicesLiveInTheStoreOfThePreferences() {
        let store = MemoryStore()
        XCTAssertEqual(NoticePreferences.load(store), NoticeSettings())
        let settings = NoticeSettings(muted: true).withKind("camera", off: true)
        NoticePreferences.save(store, settings)
        XCTAssertEqual(NoticePreferences.load(store), settings)
    }

    func testANoticeCarriesTheKindOfWhatItIsAbout() {
        func event(_ id: Int, _ type: String, to: String, source: String? = nil, severity: String? = nil, code: String? = nil) -> ArmorEvent {
            ArmorEvent(id: id, at: "", type: type, subject: "s", from: nil, to: to, targets: 1, mode: nil, severity: severity, code: code, sourceType: source)
        }
        let events = [
            event(1, "alarm", to: "raised", source: "solar", severity: "high", code: "solar_fault"),
            event(2, "camera", to: "offline"),
            event(3, "alert", to: "high"),
            event(4, "node", to: "offline"),
            event(5, "alarm", to: "raised", source: "network", severity: "warning", code: "network_port_opened"),
        ]
        let kinds = AlarmPolicy.notices(events, armed: true, plain()).map(\.kind)
        XCTAssertEqual(kinds, ["alarm.solar", "camera", "alert", "node", "alarm.network"])
        XCTAssertEqual(NoticeKinds.ofAlarm("weird"), "alarm.other")
        XCTAssertEqual(NoticeKinds.ofAlarm(nil), "alarm.other")
    }
}
