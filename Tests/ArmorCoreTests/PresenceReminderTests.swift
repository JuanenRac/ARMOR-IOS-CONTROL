// ARMOR-IOS-CONTROL - the reminder on leaving home: what it says, when it keeps quiet, and what it keeps.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import XCTest
@testable import ArmorCore

final class PresenceReminderTests: XCTestCase {
    private let now: Int64 = 10_000_000_000

    func testWithTheAlarmArmedThePhoneLeavingHomeSaysNothing() {
        XCTAssertNil(PresenceDecision.onLeft(mode: "armed", lastReminderMs: 0, nowMs: now))
    }

    func testWithTheAlarmDisarmedItRemindsThePersonToArm() {
        XCTAssertEqual(PresenceDecision.onLeft(mode: "disarmed", lastReminderMs: 0, nowMs: now), .armNow)
    }

    func testWhenTheServerCannotBeReadItAsksThePersonToCheckRatherThanStayingSilent() {
        XCTAssertEqual(PresenceDecision.onLeft(mode: nil, lastReminderMs: 0, nowMs: now), .check)
        XCTAssertEqual(PresenceDecision.onLeft(mode: "something else", lastReminderMs: 0, nowMs: now), .check)
    }

    func testAfterAReminderTheNextOneWaitsForTheQuietTimeAndThenComesAgain() {
        XCTAssertNil(PresenceDecision.onLeft(mode: "disarmed", lastReminderMs: now - PresenceConfig.cooldownMs + 1, nowMs: now))
        XCTAssertEqual(PresenceDecision.onLeft(mode: "disarmed", lastReminderMs: now - PresenceConfig.cooldownMs, nowMs: now), .armNow)
    }

    func testAClockThatWentBackDoesNotKeepTheReminderQuietForEver() {
        XCTAssertEqual(PresenceDecision.onLeft(mode: "disarmed", lastReminderMs: now + 5_000, nowMs: now), .armNow)
    }

    func testOnlyARealPlaceIsAHome() {
        XCTAssertTrue(HomePlace(lat: 38.0, lon: -1.1).valid)
        XCTAssertFalse(HomePlace(lat: 0, lon: 0).valid)
        XCTAssertFalse(HomePlace(lat: 91, lon: 0.5).valid)
        XCTAssertFalse(HomePlace(lat: 10, lon: 181).valid)
    }

    func testTheChoiceIsOffByDefaultAndTheHomeIsKeptAndForgotten() {
        let store = PresenceStore(MemoryStore())
        XCTAssertFalse(store.enabled)
        XCTAssertNil(store.home)
        XCTAssertEqual(store.lastReminderMs, 0)
        store.enabled = true
        store.home = HomePlace(lat: 38.123456, lon: -1.654321)
        store.lastReminderMs = 42
        XCTAssertTrue(store.enabled)
        XCTAssertEqual(store.home, HomePlace(lat: 38.123456, lon: -1.654321))
        XCTAssertEqual(store.lastReminderMs, 42)
        store.home = HomePlace(lat: 0, lon: 0)
        XCTAssertNil(store.home, "a place that is not real is not kept")
        store.enabled = false
        XCTAssertFalse(store.enabled)
    }

    func testTheNumbersMakeSense() {
        XCTAssertGreaterThanOrEqual(PresenceConfig.radiusM, 50)
        XCTAssertGreaterThanOrEqual(PresenceConfig.cooldownMs, 60_000)
    }
}
