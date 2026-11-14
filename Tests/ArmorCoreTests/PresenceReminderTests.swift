// ARMOR-IOS-CONTROL - the reminder on leaving home: what it says, when it keeps quiet, and what it keeps.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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

    func testEnteringTheCircleSaysHomeAndLeavingSaysAway() {
        XCTAssertEqual(PresenceShare.word(entered: true), "home")
        XCTAssertEqual(PresenceShare.word(entered: false), "away")
        XCTAssertTrue(PresenceShare.valid("home"))
        XCTAssertTrue(PresenceShare.valid("away"))
        XCTAssertFalse(PresenceShare.valid("38.0,-1.1"))
        XCTAssertFalse(PresenceShare.valid(""))
    }

    func testTheWordIsOffByDefaultAndApartFromTheReminder() {
        let store = PresenceStore(MemoryStore())
        XCTAssertFalse(store.share)
        store.share = true
        XCTAssertTrue(store.share)
        XCTAssertFalse(store.enabled, "turning on the word does not turn on the reminder")
        store.share = false
        XCTAssertFalse(store.share)
    }

    func testTheCircleIsWatchedOnlyWithSomethingOnAndAPlaceSaved() {
        XCTAssertFalse(PresenceShare.watching(reminder: false, share: false, hasHome: true))
        XCTAssertFalse(PresenceShare.watching(reminder: true, share: true, hasHome: false))
        XCTAssertTrue(PresenceShare.watching(reminder: true, share: false, hasHome: true))
        XCTAssertTrue(PresenceShare.watching(reminder: false, share: true, hasHome: true))
        XCTAssertFalse(PresenceShare.notifyOnEntry(share: false), "with the word off, coming back is not heard")
        XCTAssertTrue(PresenceShare.notifyOnEntry(share: true))
    }

    func testTheWordGoesAsAPutWithOnlyTheWord() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        let origin = "http://192.168.0.180:8080"
        StubProtocol.routes["PUT /api/v1/presence/me"] = (200, #"{"state":"home","since":"t"}"#)
        try await api.setPresence(origin, state: "home")
        XCTAssertEqual(StubProtocol.seen.map { ($0.httpMethod ?? "") + " " + ($0.url?.path ?? "") }, ["PUT /api/v1/presence/me"])
        let body = try Json.object(Data(StubProtocol.bodies[0].utf8))
        XCTAssertEqual(Set(body.keys), ["state"])
        XCTAssertEqual(body["state"] as? String, "home")
    }

    func testAnyOtherWordIsNeverSentAndAServerWithTheOptionOffAnswers404() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        let origin = "http://192.168.0.180:8080"
        do { try await api.setPresence(origin, state: "38.0,-1.1"); XCTFail("the word should be refused") } catch { }
        XCTAssertTrue(StubProtocol.seen.isEmpty)
        StubProtocol.routes["PUT /api/v1/presence/me"] = (404, #"{"error":"not found"}"#)
        do { try await api.setPresence(origin, state: "away"); XCTFail("a 404 should fail") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 404) }
    }
}
