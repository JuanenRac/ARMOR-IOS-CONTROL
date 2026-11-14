// ARMOR-IOS-CONTROL - the alarm window of the open app: which alarm it shows, when it comes back after being closed, and what it never shows (the same cases as the Android app).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import XCTest
@testable import ArmorCore

final class AlarmBannerTests: XCTestCase {
    private let t = plain()

    private func alarm(_ id: String, _ severity: String = "high", code: String = "smoke", raisedAt: String = "2030-01-01T10:00:00Z", by: String? = nil) -> Alarm {
        Alarm(id: id, sourceType: "device", sourceId: "dev-\(id)", severity: severity, code: code, raisedAt: raisedAt, acknowledgedBy: by, cleared: false, detail: [], falseAlarm: nil)
    }

    func testNothingWaitingMeansNoBanner() {
        XCTAssertNil(AlarmBannerPolicy.from([], closedKey: nil, t))
        XCTAssertNil(AlarmBannerPolicy.from([alarm("a", by: "ana")], closedKey: nil, t))
    }

    func testTheWorstUnconfirmedAlarmIsShownAndTheCountSaysHowManyWait() throws {
        let banner = try XCTUnwrap(AlarmBannerPolicy.from([alarm("a", "warning"), alarm("b", "critical"), alarm("c", "high")], closedKey: nil, t))
        XCTAssertEqual(banner.severity, "critical")
        XCTAssertEqual(banner.alarm.id, "b")
        XCTAssertEqual(banner.count, 3)
        XCTAssertTrue(banner.title.contains("3"))
        XCTAssertTrue(banner.detail.contains("dev-b"))
    }

    func testOfTwoEqualAlarmsTheNewerOneIsShown() throws {
        let banner = try XCTUnwrap(AlarmBannerPolicy.from([alarm("old", raisedAt: "2030-01-01T09:00:00Z"), alarm("new", raisedAt: "2030-01-01T11:00:00Z")], closedKey: nil, t))
        XCTAssertEqual(banner.alarm.id, "new")
    }

    func testASingleAlarmNamesItsSeverityInsteadOfACount() throws {
        let banner = try XCTUnwrap(AlarmBannerPolicy.from([alarm("a", "critical")], closedKey: nil, t))
        XCTAssertEqual(banner.count, 1)
        XCTAssertTrue(banner.title.contains("CRÍTICA"))
    }

    func testAConfirmedAlarmDoesNotWaitAndDoesNotCount() throws {
        let banner = try XCTUnwrap(AlarmBannerPolicy.from([alarm("a", "critical", by: "ana"), alarm("b", "warning")], closedKey: nil, t))
        XCTAssertEqual(banner.alarm.id, "b")
        XCTAssertEqual(banner.count, 1)
    }

    func testTheAlarmOfADuressPinIsNeverShownOnAPhone() throws {
        XCTAssertNil(AlarmBannerPolicy.from([alarm("a", "critical", code: "duress_disarm")], closedKey: nil, t))
        let banner = try XCTUnwrap(AlarmBannerPolicy.from([alarm("a", "critical", code: "duress_disarm"), alarm("b", "warning")], closedKey: nil, t))
        XCTAssertEqual(banner.alarm.id, "b")
    }

    func testAClosedBannerStaysClosedUntilTheSetOfWaitingAlarmsChanges() throws {
        let first = [alarm("a")]
        let closed = try XCTUnwrap(AlarmBannerPolicy.from(first, closedKey: nil, t)).key
        XCTAssertNil(AlarmBannerPolicy.from(first, closedKey: closed, t))
        XCTAssertNil(AlarmBannerPolicy.from([alarm("a", "critical")], closedKey: closed, t), "the same alarm, however its text changes")
        XCTAssertNotNil(AlarmBannerPolicy.from(first + [alarm("b")], closedKey: closed, t), "a new alarm brings it back")
    }

    func testTheKeyDoesNotDependOnTheOrder() {
        XCTAssertEqual(AlarmBannerPolicy.key([alarm("b"), alarm("a")]), AlarmBannerPolicy.key([alarm("a"), alarm("b")]))
        XCTAssertNotEqual(AlarmBannerPolicy.key([alarm("a")]), AlarmBannerPolicy.key([alarm("a"), alarm("b")]))
    }

    func testCriticalBeatsFasterThanTheRest() {
        XCTAssertTrue(AlarmBannerPolicy.isCritical("critical"))
        XCTAssertFalse(AlarmBannerPolicy.isCritical("high"))
        XCTAssertLessThan(AlarmBannerPolicy.pulseSeconds("critical"), AlarmBannerPolicy.pulseSeconds("high"))
    }

    func testTheWordsOfTheBannerAreInEveryLanguage() {
        for language in ["en", "es", "de", "fr", "it", "ja", "zh", "pt"] {
            let translator = Translator(language: language)
            for phrase in ["Ver alarmas", "Cerrar", "Confirmar", "ALARMA %s", "%d alarmas sin confirmar"] {
                XCTAssertFalse(translator.tr(phrase).isEmpty, "\(language) \(phrase)")
                if language != "es" { XCTAssertNotEqual(translator.tr(phrase), phrase, "\(language) \(phrase) is not translated") }
            }
        }
    }
}
