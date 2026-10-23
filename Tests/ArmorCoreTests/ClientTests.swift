import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// Answers the requests of the client with what the test says and remembers what was asked.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var routes: [String: (status: Int, body: String)] = [:]
    nonisolated(unsafe) static var seen: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [String] = []

    static func reset() { routes = [:]; seen = []; bodies = [] }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = ""
        if let data = request.httpBody { body = String(decoding: data, as: UTF8.self) }
        else if let stream = request.httpBodyStream {
            stream.open(); var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
            stream.close(); body = String(decoding: data, as: UTF8.self)
        }
        StubProtocol.seen.append(request); StubProtocol.bodies.append(body)
        let key = "\(request.httpMethod ?? "GET") \(request.url?.path ?? "")"
        let answer = StubProtocol.routes[key] ?? (404, "{}")
        let response = HTTPURLResponse(url: request.url!, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(answer.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ClientTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private var api: ArmorApiClient!

    override func setUp() {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
    }

    func testStatusIsReadFromTheRightPathWithTheClientTag() async throws {
        StubProtocol.routes["GET /api/v1/status"] = (200, #"{"mode":"armed","revision":3,"nodes":{}}"#)
        let status = try await api.status(origin)
        XCTAssertTrue(status.armed)
        XCTAssertEqual(StubProtocol.seen.first?.value(forHTTPHeaderField: "X-Armor-Client"), "ios/0.1.0")
        XCTAssertEqual(StubProtocol.seen.first?.value(forHTTPHeaderField: "Accept"), "application/json")
    }
    func testSignInSendsTheCredentialsOnceAndReadsTheSecondFactor() async throws {
        StubProtocol.routes["POST /api/v1/studio/session"] = (200, #"{"totp_required":true,"challenge":"abc"}"#)
        let outcome = try await api.signIn(origin, username: "ana", password: "pw")
        XCTAssertEqual(outcome, .needsCode(challenge: "abc"))
        XCTAssertTrue(StubProtocol.bodies[0].contains("\"username\":\"ana\""))
        StubProtocol.routes["POST /api/v1/studio/session"] = (201, "{}")
        let done = try await api.signIn(origin, username: "ana", password: "pw")
        XCTAssertEqual(done, .done)
    }
    func testDisarmCarriesThePinAndArmingNever() async throws {
        StubProtocol.routes["POST /api/v1/mode"] = (200, "{}")
        try await api.setMode(origin, mode: "disarmed", pin: "1234")
        try await api.setMode(origin, mode: "armed", pin: "1234")
        let disarm = try Json.object(Data(StubProtocol.bodies[0].utf8)), arm = try Json.object(Data(StubProtocol.bodies[1].utf8))
        XCTAssertEqual(disarm.str("pin"), "1234")
        XCTAssertEqual(disarm.str("mode"), "disarmed")
        XCTAssertFalse(arm.has("pin"))
    }
    func testAModeThatIsNotArmedOrDisarmedIsRefusedBeforeSending() async {
        do { try await api.setMode(origin, mode: "panic", pin: nil); XCTFail() } catch {}
        XCTAssertTrue(StubProtocol.seen.isEmpty)
    }
    func testARefusalKeepsItsStatusAndCode() async {
        StubProtocol.routes["POST /api/v1/mode"] = (403, #"{"code":"wrong_pin","error":"El PIN no es correcto"}"#)
        do { try await api.setMode(origin, mode: "disarmed", pin: "0") ; XCTFail() } catch let error as ArmorApiError {
            XCTAssertEqual(error.status, 403)
            XCTAssertEqual(error.code, "wrong_pin")
        } catch { XCTFail("\(error)") }
    }
    func testElevationIsRecognised() async {
        StubProtocol.routes["POST /api/v1/alarms/acknowledge"] = (403, #"{"error":"elevation_required"}"#)
        do { try await api.acknowledgeAllAlarms(origin); XCTFail() } catch let error as ArmorApiError { XCTAssertTrue(error.isElevationRequired) } catch { XCTFail("\(error)") }
    }
    func testPanelCommandsUseTheirOwnBody() async throws {
        StubProtocol.routes["POST /api/v1/alarm/command"] = (202, "{}")
        try await api.sendAlarmCommand(origin, node: "alarm-1", mode: "away", force: true, pin: "99", profile: "night")
        try await api.sendAlarmCommand(origin, node: "alarm-1", mode: nil, force: false, pin: "42", profile: nil)
        try await api.silenceAlarmSiren(origin, node: "alarm-1", pin: nil)
        let arm = try Json.object(Data(StubProtocol.bodies[0].utf8)), disarm = try Json.object(Data(StubProtocol.bodies[1].utf8)), silence = try Json.object(Data(StubProtocol.bodies[2].utf8))
        XCTAssertEqual(arm.str("action"), "arm"); XCTAssertEqual(arm.str("profile"), "night"); XCTAssertTrue(arm.bool("force")); XCTAssertFalse(arm.has("pin"))
        XCTAssertEqual(disarm.str("action"), "disarm"); XCTAssertEqual(disarm.str("pin"), "42")
        XCTAssertEqual(silence.str("action"), "silence"); XCTAssertFalse(silence.has("pin"))
    }
    func testStreamTicketMustPointAtACameraPath() async throws {
        StubProtocol.routes["POST /api/v1/cameras/cam%201/stream-ticket"] = (200, #"{"path":"/api/v1/cameras/cam%201/stream?ticket=t"}"#)
        StubProtocol.routes["POST /api/v1/cameras/evil/stream-ticket"] = (200, #"{"path":"https://evil.example/x"}"#)
        // the path of a request is compared decoded by URL.path, so the key uses the decoded form
        StubProtocol.routes["POST /api/v1/cameras/cam 1/stream-ticket"] = (200, #"{"path":"/api/v1/cameras/cam%201/stream?ticket=t"}"#)
        let url = try await api.streamTicket(origin, cameraId: "cam 1")
        XCTAssertEqual(url, origin + "/api/v1/cameras/cam%201/stream?ticket=t")
        do { _ = try await api.streamTicket(origin, cameraId: "evil"); XCTFail("accepted a foreign path") } catch {}
    }
    func testStreamTicketAsksForTheQualityThatWasChosenAndAnUnknownOneBecomesAuto() async throws {
        StubProtocol.routes["POST /api/v1/cameras/cam 1/stream-ticket"] = (200, #"{"path":"/api/v1/cameras/cam%201/stream?ticket=t"}"#)
        _ = try await api.streamTicket(origin, cameraId: "cam 1", quality: "low")
        _ = try await api.streamTicket(origin, cameraId: "cam 1")
        _ = try await api.streamTicket(origin, cameraId: "cam 1", quality: "ultra")
        let asked = try StubProtocol.bodies.map { try Json.object(Data($0.utf8)).str("quality") }
        XCTAssertEqual(asked, ["low", "auto", "auto"])
        XCTAssertEqual(CameraQuality.requested(away: true, tile: true), "low")
        XCTAssertEqual(CameraQuality.requested(away: false, tile: true), "normal")
        XCTAssertEqual(CameraQuality.requested(away: true, tile: false), "auto")
    }
    func testPathPiecesAreEscaped() {
        XCTAssertEqual(ArmorApiClient.part("cam 1"), "cam%201")
        XCTAssertEqual(ArmorApiClient.part("a/b"), "a%2Fb")
        XCTAssertEqual(ArmorApiClient.part("alm-0001"), "alm-0001")
    }
    func testHistoryQuery() async throws {
        StubProtocol.routes["GET /api/v1/history"] = (200, #"{"events":[]}"#)
        _ = try await api.history(origin, limit: 20, before: 100, after: nil)
        XCTAssertEqual(StubProtocol.seen.first?.url?.query, "limit=20&before=100")
    }
    func testVoiceCommandBody() async throws {
        StubProtocol.routes["POST /api/v1/voice/command"] = (200, #"{"accepted":true,"outcome":"confirmation-needed","intent":"arm","speech":"x","confirmation_token":"t"}"#)
        let reply = try await api.voiceCommand(origin, text: "arma", language: "pt", confirmation: nil)
        XCTAssertEqual(reply.confirmationToken, "t")
        let body = try Json.object(Data(StubProtocol.bodies[0].utf8))
        XCTAssertEqual(body.str("language"), "pt")
        XCTAssertFalse(body.has("confirmation"))
    }
    func testPushRegistrationAcceptsAServerWithPushOff() async throws {
        StubProtocol.routes["POST /api/v1/push/register"] = (409, "{}")
        try await api.registerPush(origin, token: "tok")
    }
    func testUnreachableServerHasNoStatus() async {
        final class Failing: URLProtocol {
            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)) }
            override func stopLoading() {}
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Failing.self]
        let broken = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "t")
        do { _ = try await broken.status(origin); XCTFail() } catch let error as ArmorApiError { XCTAssertNil(error.status) } catch { XCTFail("\(error)") }
    }
}
