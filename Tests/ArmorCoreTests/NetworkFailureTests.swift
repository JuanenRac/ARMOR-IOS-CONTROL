// ARMOR-IOS-CONTROL - the client when the network or the server fails (no connection, a timeout, an answer that is not JSON or is too long, an outage that ends), and what a read-only account can never do.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// Plays what the test says for every request: an answer, or a failure of the transport. It remembers what was asked.
final class ScriptedProtocol: URLProtocol {
    enum Play { case answer(Int, Data), fail(URLError.Code) }
    nonisolated(unsafe) static var play: Play = .answer(200, Data("{}".utf8))
    nonisolated(unsafe) static var seen: [URLRequest] = []

    static func reset() { play = .answer(200, Data("{}".utf8)); seen = [] }
    static func answer(_ status: Int, _ body: String) { play = .answer(status, Data(body.utf8)) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        ScriptedProtocol.seen.append(request)
        switch ScriptedProtocol.play {
        case .fail(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .answer(let status, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

final class NetworkFailureTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private var api: ArmorApiClient!

    override func setUp() {
        ScriptedProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScriptedProtocol.self]
        api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
    }

    private typealias Call = (name: String, run: (ArmorApiClient, String) async throws -> Void)

    private func call(_ name: String, _ run: @escaping (ArmorApiClient, String) async throws -> Void) -> Call { (name, run) }

    private var reads: [Call] {
        [
            call("status") { c, o in _ = try await c.status(o) },
            call("alarms") { c, o in _ = try await c.alarms(o) },
            call("solar") { c, o in _ = try await c.solar(o) },
            call("electrical") { c, o in _ = try await c.electrical(o) },
            call("network") { c, o in _ = try await c.network(o) },
            call("services") { c, o in _ = try await c.services(o) },
            call("devices") { c, o in _ = try await c.devices(o) },
            call("history") { c, o in _ = try await c.history(o, limit: 10, before: nil, after: nil) },
            call("preflight") { c, o in _ = try await c.preflight(o) },
            call("cameraStatus") { c, o in _ = try await c.cameraStatus(o) },
            call("nodeHealth") { c, o in _ = try await c.nodeHealth(o) },
            call("armingModes") { c, o in _ = try await c.armingModes(o) },
            call("batteryOperations") { c, o in _ = try await c.batteryOperations(o) },
            call("alarmPanels") { c, o in _ = try await c.alarmPanels(o) },
            call("sessionFacts") { c, o in _ = try await c.sessionFacts(o) },
        ]
    }

    private var writes: [Call] {
        [
            call("acknowledgeAlarm") { c, o in try await c.acknowledgeAlarm(o, id: "a1") },
            call("acknowledgeAllAlarms") { c, o in try await c.acknowledgeAllAlarms(o) },
            call("panicGesture") { c, o in try await c.panicGesture(o) },
            call("arm") { c, o in try await c.setMode(o, mode: "armed", pin: nil) },
            call("disarm") { c, o in try await c.setMode(o, mode: "disarmed", pin: "1234") },
            call("commandDevice") { c, o in try await c.commandDevice(o, id: "light-1", command: "on", confirm: false) },
            call("scanNetworkNow") { c, o in try await c.scanNetworkNow(o) },
            call("forgetNode") { c, o in try await c.forgetNode(o, id: "node-1") },
            call("nodePanelTicket") { c, o in _ = try await c.nodePanelTicket(o, nodeId: "node-1") },
            call("panelCommand") { c, o in try await c.sendAlarmCommand(o, node: "panel-1", mode: "armed", force: false, pin: nil, profile: nil) },
            call("silenceSiren") { c, o in try await c.silenceAlarmSiren(o, node: "panel-1", pin: nil) },
        ]
    }

    /// The error a call throws; the test fails if it comes back with an answer.
    private func thrown(_ call: Call, file: StaticString = #filePath, line: UInt = #line) async -> Error? {
        do { try await call.run(api, origin) } catch { return error }
        XCTFail("\(call.name) must fail", file: file, line: line)
        return nil
    }

    func testNoReadComesBackWithDataWhenTheServerIsDownWhateverReasonItGives() async {
        for read in reads {
            for status in [401, 500, 502, 503] {
                ScriptedProtocol.answer(status, #"{"error":"nope","code":"some_code"}"#)
                let error = await thrown(read) as? ArmorApiError
                XCTAssertEqual(error?.status, status, "\(read.name) \(status)")
                XCTAssertEqual(error?.code, "some_code", "\(read.name) \(status)")
            }
        }
    }

    func testALostConnectionIsAFailureWithoutAStatusForEveryRead() async {
        let reasons: [URLError.Code] = [.notConnectedToInternet, .timedOut, .cannotConnectToHost, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed]
        for reason in reasons {
            ScriptedProtocol.play = .fail(reason)
            for read in reads {
                let error = await thrown(read) as? ArmorApiError
                XCTAssertNotNil(error, "\(read.name) \(reason.rawValue)")
                XCTAssertNil(error?.status, "\(read.name): there was no answer, so there is no status")
                XCTAssertFalse(error?.message.isEmpty ?? true, "\(read.name) says what happened")
            }
        }
    }

    func testAnOutageThatEndsLeavesTheClientAsGoodAsNew() async throws {
        ScriptedProtocol.answer(200, #"{"mode":"armed","revision":1,"nodes":{}}"#)
        var status = try await api.status(origin)
        XCTAssertTrue(status.armed)
        ScriptedProtocol.answer(503, "")
        for _ in 0..<2 {
            do { _ = try await api.status(origin); XCTFail("an outage answered") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 503) }
        }
        ScriptedProtocol.play = .fail(.networkConnectionLost)
        do { _ = try await api.status(origin); XCTFail("a lost connection answered") } catch let error as ArmorApiError { XCTAssertNil(error.status) }
        ScriptedProtocol.answer(200, #"{"mode":"disarmed","revision":2,"nodes":{}}"#)
        status = try await api.status(origin)
        XCTAssertFalse(status.armed)
        XCTAssertEqual(ScriptedProtocol.seen.count, 5)
    }

    func testAnAnswerThatIsNotJSONIsAFailureNotAnEmptyState() async {
        for body in ["<html>gateway error</html>", "not json", "[1,2,3]", "{\"mode\":", "null"] {
            ScriptedProtocol.answer(200, body)
            for read in [reads[0], reads[1]] { _ = await thrown(read) }
        }
    }

    func testAnAnswerLongerThanTheLimitIsRefused() async {
        ScriptedProtocol.play = .answer(200, Data(repeating: 0x20, count: 9 * 1024 * 1024))
        let error = await thrown(reads[0]) as? ArmorApiError
        XCTAssertNil(error?.status)
        XCTAssertTrue(error?.message.contains("longer than") ?? false, error?.message ?? "no error")
    }

    func testEveryWriteIsRefusedWithTheStatusOfTheServerWhenTheAccountMayOnlyLook() async {
        for write in writes {
            ScriptedProtocol.seen = []
            ScriptedProtocol.answer(403, #"{"error":"forbidden","code":"forbidden"}"#)
            let error = await thrown(write) as? ArmorApiError
            XCTAssertEqual(error?.status, 403, write.name)
            XCTAssertEqual(error?.code, "forbidden", write.name)
            XCTAssertEqual(error?.isElevationRequired, false, "\(write.name) is not a request for a new proof")
            XCTAssertFalse(ScriptedProtocol.seen.isEmpty, write.name)
            XCTAssertTrue(ScriptedProtocol.seen.allSatisfy { ($0.httpMethod ?? "GET") != "GET" }, "\(write.name) sent nothing that only reads")
        }
    }

    func testARefusedWriteIsNotRepeatedByTheClientOnItsOwn() async {
        ScriptedProtocol.answer(403, #"{"error":"forbidden","code":"forbidden"}"#)
        _ = await thrown(writes[0])
        _ = await thrown(writes[2])
        XCTAssertEqual(ScriptedProtocol.seen.compactMap { $0.url?.path }, ["/api/v1/alarms/a1/acknowledge", "/api/v1/alarm/panic-gesture"])
    }

    func testTheRoleDecidesWhatAPhoneOffersWhenTheServerAnnouncesNothingAndOnlyTheExactWordCounts() {
        let operatorActions: Set<String> = [CapabilityAction.arm, CapabilityAction.disarm, CapabilityAction.acknowledge, CapabilityAction.operate, CapabilityAction.cameraControl]
        let adminActions = operatorActions.union([CapabilityAction.administer, CapabilityAction.manageUsers])
        for role in ["viewer", "panel", "guest", "", " ", "ADMIN", "Admin", "root", "operator ", " admin", "admin\n", "operador"] {
            XCTAssertTrue(CapabilityAction.all.allSatisfy { !Capabilities.fromRole(role).can($0) }, "[\(role)]")
        }
        XCTAssertEqual(Set(CapabilityAction.all.filter { Capabilities.fromRole("operator").can($0) }), operatorActions)
        XCTAssertEqual(Set(CapabilityAction.all.filter { Capabilities.fromRole("admin").can($0) }), adminActions)
        XCTAssertFalse(Capabilities.fromRole("admin").announced)
        XCTAssertFalse(Capabilities.fromRole("viewer").has("rtsp_tunnel"))
    }

    func testAnAnnouncedFieldOnlyAllowsWhatItSaysWithARealTrue() throws {
        func parsed(_ text: String) throws -> Capabilities { try XCTUnwrap(Capabilities.parse(try Json.object(Data(text.utf8)))) }
        let none = try parsed(#"{"version":1,"actions":{}}"#)
        XCTAssertTrue(none.announced)
        XCTAssertTrue(CapabilityAction.all.allSatisfy { !none.can($0) })
        let loose = try parsed(#"{"version":1,"actions":{"arm":"true","disarm":"yes","acknowledge":null,"operate":[true],"camera_control":{"a":true},"administer":"1"}}"#)
        XCTAssertTrue(CapabilityAction.all.allSatisfy { !loose.can($0) }, "only a boolean true allows")
        let some = try parsed(#"{"version":1,"actions":{"arm":true,"disarm":false},"features":["a",1,null,"b",true]}"#)
        XCTAssertTrue(some.can("arm"))
        XCTAssertFalse(some.can("disarm"))
        XCTAssertFalse(some.can("Arm"))
        XCTAssertFalse(some.can(""))
        XCTAssertEqual(Set(["a", "b", "c", "1", "true"].filter { some.has($0) }), ["a", "b"])
        let text = try parsed(#"{"version":1,"actions":{"arm":true},"features":"rtsp_tunnel"}"#)
        XCTAssertFalse(text.has("rtsp_tunnel"))
        XCTAssertTrue(text.can("arm"))
        XCTAssertNil(Capabilities.parse(try Json.object(Data(#"{"version":1,"actions":[]}"#.utf8))))
        XCTAssertNil(Capabilities.parse(try Json.object(Data(#"{"version":0,"actions":{"arm":true}}"#.utf8))))
        XCTAssertNil(Capabilities.parse(try Json.object(Data(#"{"actions":{"arm":true}}"#.utf8))))
    }

    func testTwoReadingsOfTheSameAnnouncementAreEqualAndAChangeOfOneActionIsNot() throws {
        func parsed(_ text: String) throws -> Capabilities { try XCTUnwrap(Capabilities.parse(try Json.object(Data(text.utf8)))) }
        let a = try parsed(#"{"version":1,"actions":{"arm":true},"features":["x"]}"#)
        let b = try parsed(#"{"version":1,"actions":{"arm":true},"features":["x"]}"#)
        let c = try parsed(#"{"version":1,"actions":{"arm":true,"disarm":true},"features":["x"]}"#)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, Capabilities.fromRole("viewer"))
    }

    func testEveryAccountThatMayNotChangeAnythingIsReadOnlyOnTheScreens() {
        for role in ["viewer", "panel", "guest"] {
            let facts = SessionFacts(role: role, deviceLock: "user", capabilities: Capabilities.fromRole(role))
            XCTAssertFalse(facts.canChange, role)
            XCTAssertFalse(facts.isAdmin, role)
            XCTAssertTrue(CapabilityAction.all.allSatisfy { !facts.can($0) }, role)
        }
        let operatorFacts = SessionFacts(role: "operator", deviceLock: "user", capabilities: Capabilities.fromRole("operator"))
        XCTAssertTrue(operatorFacts.canChange)
        XCTAssertFalse(operatorFacts.isAdmin)
        let adminFacts = SessionFacts(role: "admin", deviceLock: "user", capabilities: Capabilities.fromRole("admin"))
        XCTAssertTrue(adminFacts.canChange)
        XCTAssertTrue(adminFacts.isAdmin)
        let announcedNothing = SessionFacts(role: "admin", deviceLock: "user", capabilities: Capabilities(announced: true, actions: []))
        XCTAssertFalse(announcedNothing.canChange, "an announcement of nothing beats the role")
        XCTAssertFalse(announcedNothing.isAdmin)
    }
}
