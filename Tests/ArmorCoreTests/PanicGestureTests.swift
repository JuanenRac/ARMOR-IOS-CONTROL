// ARMOR-IOS-CONTROL - the hidden panic gesture: only while the server offers it, only for a person who may operate, silent whatever the answer, and no trace in the report.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

final class PanicGestureTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"

    private func signedIn(role: String = "operator", offered: Bool) async throws -> (ArmorController, FakeApi) {
        let api = FakeApi()
        api.facts = SessionFacts(role: role, deviceLock: "user", panicGesture: offered)
        let made = makeController(api: api)
        _ = try await made.0.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        return (made.0, api)
    }
    private func gestures(_ api: FakeApi) -> Int { api.calls.filter { $0 == "panic" }.count }

    func testFiveQuickTouchesMakeTheGestureFourDoNotAndSlowOnesDoNotAddUp() {
        var counter = TapCounter()
        XCTAssertFalse((1...4).contains { counter.touch(atMs: Int64($0) * 400) })
        XCTAssertTrue(counter.touch(atMs: 2_000))
        XCTAssertFalse(counter.touch(atMs: 2_100), "it starts again after a gesture")
        var slow = TapCounter()
        XCTAssertFalse((0...9).contains { slow.touch(atMs: Int64($0) * 1_000) }, "one a second: never five inside three seconds")
        var late = TapCounter()
        for at in [0, 1, 2, 3] as [Int64] { XCTAssertFalse(late.touch(atMs: at)) }
        XCTAssertFalse(late.touch(atMs: PanicGesture.windowMs + 10), "the fifth comes after the window")
        var edge = TapCounter()
        for at in [0, 1, 2, 3] as [Int64] { XCTAssertFalse(edge.touch(atMs: at)) }
        XCTAssertTrue(edge.touch(atMs: PanicGesture.windowMs), "just inside the window")
    }

    func testTheSessionSaysWhetherTheServerOffersItAndAnOlderServerOffersNothing() throws {
        func offered(_ security: String) throws -> Bool {
            SessionFacts.parse(try Json.object(Data(("{\"user\":{\"role\":\"operator\"},\"capabilities\":{\"version\":1,\"security\":" + security + "}}").utf8))).panicGesture
        }
        XCTAssertTrue(try offered("{\"client.panic_gesture\":true}"))
        XCTAssertFalse(try offered("{\"client.panic_gesture\":false}"))
        XCTAssertFalse(try offered("{}"))
        XCTAssertFalse(SessionFacts.parse(try Json.object(Data("{\"user\":{\"role\":\"operator\"}}".utf8))).panicGesture)
        XCTAssertFalse(SessionFacts().panicGesture)
    }

    func testWhileTheServerDoesNotOfferItTheGestureSendsNothing() async throws {
        let (controller, api) = try await signedIn(offered: false)
        await controller.panicGesture()
        XCTAssertEqual(gestures(api), 0)
    }

    func testOfferedAndMadeItAsksOnceAndTheGateOfThePhoneIsNotAsked() async throws {
        let auth = FakeAuth()
        let api = FakeApi()
        api.facts = SessionFacts(role: "operator", deviceLock: "always", panicGesture: true)
        let made = makeController(api: api, auth: auth)
        _ = try await made.0.signIn(origin: origin, username: "ana", password: "pw", remember: false)
        let before = auth.asked
        await made.0.panicGesture()
        XCTAssertEqual(gestures(api), 1)
        XCTAssertEqual(auth.asked, before, "no fingerprint or face prompt: the person may be watched")
    }

    func testAViewerNeverSendsItEvenWhenTheServerOffersIt() async throws {
        let (controller, api) = try await signedIn(role: "viewer", offered: true)
        await controller.panicGesture()
        XCTAssertEqual(gestures(api), 0)
    }

    func testA404MeansTheOptionWasTurnedOffSinceTheAppForgetsTheGestureAndAsksNoMore() async throws {
        let (controller, api) = try await signedIn(offered: true)
        api.panicError = ArmorApiError(message: "not found", status: 404)
        await controller.panicGesture()
        XCTAssertFalse(controller.state.facts.panicGesture)
        await controller.panicGesture()
        XCTAssertEqual(gestures(api), 1, "it does not ask again")
    }

    func testALostConnectionIsTriedOnceMoreAndAServerRefusalIsNot() async throws {
        let (controller, api) = try await signedIn(offered: true)
        api.panicError = ArmorApiError(message: "timeout", status: nil)
        api.panicErrorOnce = true
        await controller.panicGesture()
        XCTAssertEqual(gestures(api), 2, "the second try went through")
        let (other, refusing) = try await signedIn(offered: true)
        refusing.panicError = ArmorApiError(message: "busy", status: 500)
        await other.panicGesture()
        XCTAssertEqual(gestures(refusing), 1, "an answer of the server is not retried")
    }

    func testTheRouteIsPostedAndLeavesNoLineInTheReport() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        StubProtocol.routes["POST /api/v1/alarm/panic-gesture"] = (200, #"{"ok":true}"#)
        StubProtocol.routes["GET /api/v1/status"] = (200, #"{"mode":"armed","revision":3,"nodes":{}}"#)
        DiagnosticLog.shared.clear()
        _ = try await api.status(origin)
        try await api.panicGesture(origin)
        XCTAssertEqual(StubProtocol.seen.map { ($0.httpMethod ?? "") + " " + ($0.url?.path ?? "") }, ["GET /api/v1/status", "POST /api/v1/alarm/panic-gesture"])
        XCTAssertTrue(DiagnosticLog.shared.recent().allSatisfy { !$0.route.contains("panic") })
        XCTAssertEqual(DiagnosticLog.shared.recent().count, 1, "the rest of the calls still are in the log")
    }
}
