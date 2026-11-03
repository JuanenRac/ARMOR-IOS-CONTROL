// ARMOR-IOS-CONTROL - what the session announces the person may do, and what the app falls back to with a server that announces nothing.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import XCTest
@testable import ArmorCore

final class CapabilitiesTests: XCTestCase {
    private func session(_ role: String, _ caps: String? = nil) throws -> JSON {
        let extra = caps.map { ",\"capabilities\":" + $0 } ?? ""
        return try Json.object(Data(("{\"authenticated\":true,\"user\":{\"role\":\"" + role + "\"}" + extra + "}").utf8))
    }

    func testAServerThatAnnouncesNothingLeavesTheRoleToDecide() throws {
        let admin = SessionFacts.parse(try session("admin")).capabilities
        XCTAssertFalse(admin.announced)
        for action in ["arm", "disarm", "acknowledge", "operate", "camera_control", "administer", "manage_users"] { XCTAssertTrue(admin.can(action), action) }
        XCTAssertFalse(admin.can(CapabilityAction.securitySettings), "needs a route only the new server has")
        let operatorCaps = SessionFacts.parse(try session("operator")).capabilities
        XCTAssertTrue(operatorCaps.can(CapabilityAction.arm))
        XCTAssertFalse(operatorCaps.can(CapabilityAction.administer))
        for role in ["viewer", "panel", "", "other"] { XCTAssertTrue(CapabilityAction.all.allSatisfy { !Capabilities.fromRole(role).can($0) }, role) }
    }

    func testAnAnnouncedFieldIsBelievedAndAnActionItDoesNotNameIsNotAllowed() throws {
        let facts = SessionFacts.parse(try session("admin", "{\"version\":1,\"actions\":{\"arm\":true,\"disarm\":false,\"operate\":true,\"future\":true},\"features\":[\"rtsp_tunnel\",7],\"security\":{\"client.device_lock\":\"sensitive\"}}"))
        let caps = facts.capabilities
        XCTAssertTrue(caps.announced)
        XCTAssertTrue(caps.can("arm"))
        XCTAssertFalse(caps.can("disarm"))
        XCTAssertFalse(caps.can("acknowledge"))
        XCTAssertFalse(caps.can("administer"), "the role no longer decides")
        XCTAssertTrue(caps.has("rtsp_tunnel"))
        XCTAssertFalse(caps.has("zone_feed_key"))
        XCTAssertEqual(facts.deviceLock, "sensitive")
        XCTAssertTrue(facts.canChange)
        XCTAssertFalse(facts.isAdmin)
    }

    func testAFieldOfAnotherVersionOrShapeIsIgnoredAndTheRoleDecides() throws {
        XCTAssertNil(Capabilities.parse(try Json.object(Data("{\"version\":2,\"actions\":{\"arm\":true}}".utf8))))
        XCTAssertNil(Capabilities.parse(try Json.object(Data("{\"version\":1}".utf8))))
        XCTAssertNil(Capabilities.parse(nil))
        let caps = SessionFacts.parse(try session("viewer", "{\"version\":9,\"actions\":{\"arm\":true}}")).capabilities
        XCTAssertFalse(caps.announced)
        XCTAssertFalse(caps.can("arm"))
    }

    func testAnOperatorTheServerDoesNotLetDisarmIsRefusedBeforeTheServerIsAsked() async throws {
        let api = FakeApi()
        api.facts = SessionFacts(role: "operator", deviceLock: "user", capabilities: Capabilities(announced: true, actions: ["operate", "arm", "acknowledge"]))
        let made = makeController(api: api)
        _ = try await made.0.signIn(origin: "http://192.168.0.180:8080", username: "ana", password: "pw", remember: false)
        do { try await made.0.disarm(pin: "1234"); XCTFail("disarmed") } catch { XCTAssertEqual(error as? ControllerError, .notAllowed) }
        XCTAssertFalse(api.calls.contains { $0.hasPrefix("mode:") })
        try await made.0.arm()
        XCTAssertTrue(api.calls.contains("mode:armed:-"))
    }
}
