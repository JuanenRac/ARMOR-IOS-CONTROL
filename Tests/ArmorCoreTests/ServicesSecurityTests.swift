import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

final class ServicesSecurityTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    private let services = """
    {"time_ms":1000000,"systemd":true,"services":[
      {"id":"server","name":"Server","family":"Core","description":"The server","kind":"program","state":"running","unit":"armor-server.service","enabled":true,"pid":412,"since_ms":940000,"memory_bytes":104857600,"restarts":2,"port":8080},
      {"id":"radar-1","name":"radar-1","family":"Field_nodes","description":"A radar","kind":"field-node","state":"offline","since_ms":0},
      {"id":"odd","name":"Odd","family":"Other","description":"","kind":"program"}]}
    """

    func testTheServicesAreReadWithTheirNumbersAndTheirGaps() {
        let overview = ServicesParser.overview(json(services))
        XCTAssertTrue(overview.systemd)
        XCTAssertEqual(overview.services.map(\.id), ["server", "radar-1", "odd"])
        let server = overview.services[0]
        XCTAssertEqual(server.pid, 412)
        XCTAssertEqual(server.port, 8080)
        XCTAssertEqual(server.enabled, true)
        XCTAssertEqual(server.unit, "armor-server.service")
        XCTAssertNil(overview.services[1].pid)
        XCTAssertNil(overview.services[1].enabled)
        XCTAssertEqual(overview.services[2].state, "unknown")
        XCTAssertTrue(ServicesParser.overview([:]).services.isEmpty)
    }

    func testTheServicesAreToldInWords() {
        let t = plain("es")
        XCTAssertEqual(ServicesText.family("Core", t), "Núcleo")
        XCTAssertEqual(ServicesText.family("Elsewhere", t), "Elsewhere")
        XCTAssertEqual(ServicesText.state("running", t), "En marcha")
        XCTAssertEqual(ServicesText.state("offline", t), "Sin responder")
        XCTAssertEqual(ServicesText.state("???", t), "Desconocido")
        XCTAssertEqual(ServicesText.memory(nil), "—")
        XCTAssertEqual(ServicesText.memory(2048), "2 KB")
        XCTAssertEqual(ServicesText.memory(104_857_600), "100 MB")
        XCTAssertEqual(ServicesText.memory(1_610_612_736), "1.5 GB")
        XCTAssertEqual(ServicesText.since(nil, nowMs: 5, t), "—")
        XCTAssertEqual(ServicesText.since(0, nowMs: 5, t), "—")
        XCTAssertEqual(ServicesText.since(1_000_000, nowMs: 1_045_000, t), "hace 45 s")
        XCTAssertEqual(ServicesText.since(1_000_000, nowMs: 1_600_000, t), "hace 10 min")
        XCTAssertEqual(ServicesText.since(1_000_000, nowMs: 1_000_000 + 7_200_000, t), "hace 2 h")
        XCTAssertEqual(ServicesText.since(1_000_000, nowMs: 1_000_000 + 3 * 86_400_000, t), "hace 3 d")
    }

    func testTheSummaryCountsTheProblemsFirst() {
        let t = plain("es")
        let overview = ServicesParser.overview(json(services))
        XCTAssertEqual(ServicesText.summary(overview, t), "1 con problemas de 3")
        let fine = ServicesParser.overview(json(#"{"services":[{"id":"a","state":"running"},{"id":"b","state":"online"},{"id":"c","state":"stopped"}]}"#))
        XCTAssertEqual(ServicesText.summary(fine, t), "2 de 3 en marcha")
    }

    func testTheSessionsAreReadAndThoseWithoutAnIdentifierAreLeftOut() {
        let sessions = SecurityParser.sessions(json(#"{"sessions":[{"id":"s1","created":10,"last_seen":20,"origin":"remote","ip":"203.0.113.9","agent":"iPhone","current":true},{"id":" "},{"id":"s2","origin":"local"}]}"#))
        XCTAssertEqual(sessions.map(\.id), ["s1", "s2"])
        XCTAssertTrue(sessions[0].remote)
        XCTAssertTrue(sessions[0].current)
        XCTAssertEqual(sessions[0].lastSeenMs, 20)
        XCTAssertFalse(sessions[1].remote)
        XCTAssertTrue(SecurityParser.sessions([:]).isEmpty)
    }

    func testTheSecondFactorAndTheViewOfThePhoneAreRead() {
        let totp = SecurityParser.totp(json(#"{"enabled":true,"recovery_left":7,"policy":"remote"}"#))
        XCTAssertTrue(totp.enabled)
        XCTAssertEqual(totp.recoveryLeft, 7)
        XCTAssertEqual(totp.policy, "remote")
        XCTAssertEqual(SecurityParser.totp([:]).policy, "off")
        let remote = SecurityParser.remote(json(#"{"ip":"203.0.113.9","origin":"remote","cookie_secure":true,"trust_proxy":"loopback","totp_policy":"remote"}"#))
        XCTAssertTrue(remote.remote)
        XCTAssertEqual(remote.trustProxy, "loopback")
        XCTAssertEqual(SecurityParser.remote(json(#"{"trust_proxy":false}"#)).trustProxy, "-")
        XCTAssertEqual(SecurityParser.remote(json(#"{"trust_proxy":null}"#)).trustProxy, "-")
        XCTAssertEqual(SecurityParser.remote(json(#"{"trust_proxy":2}"#)).trustProxy, "2")
    }

    func testTheKeyIsShownInGroupsAndTheRecoveryCodesAreKept() {
        XCTAssertEqual(SecurityParser.grouped("ABCDEFGHIJ"), "ABCD EFGH IJ")
        XCTAssertEqual(SecurityParser.grouped(""), "")
        XCTAssertEqual(SecurityParser.codes(json(#"{"recovery_codes":["aaaa-1111"," ","bbbb-2222"]}"#)), ["aaaa-1111", "bbbb-2222"])
        XCTAssertTrue(SecurityParser.codes([:]).isEmpty)
        XCTAssertEqual(SecurityParser.setup(json(#"{"secret":"JBSWY3DP","uri":"otpauth://totp/x"}"#)), TotpSetup(secret: "JBSWY3DP", uri: "otpauth://totp/x"))
    }

    func testEveryRefusalHasWordsAndAnUnknownOneSaysNothingChanged() {
        let t = plain("es")
        XCTAssertEqual(SecurityText.error("bad_code", t), "Ese código no es correcto.")
        XCTAssertTrue(SecurityText.error("totp_locked", t).contains("Demasiados"))
        XCTAssertTrue(SecurityText.error("whatever", t).contains("No se ha cambiado nada"))
        let refusal = ArmorApiError(message: "x", status: 401, body: #"{"code":"bad_proof"}"#)
        XCTAssertEqual(SecurityText.errorText(refusal, t), "Eso no es correcto.")
        XCTAssertTrue(SecurityText.errorText(NSError(domain: "x", code: 1), t).contains("No se ha cambiado nada"))
    }

    func testTheCallsGoToTheirPathsThroughTheProtocol() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api: ArmorApi = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        let origin = "http://192.168.0.180:8080"
        StubProtocol.routes["GET /api/v1/system/services"] = (200, services)
        StubProtocol.routes["GET /api/v1/studio/sessions"] = (200, #"{"sessions":[{"id":"s1"}]}"#)
        StubProtocol.routes["DELETE /api/v1/studio/sessions/s1"] = (204, "")
        StubProtocol.routes["POST /api/v1/studio/sessions/end-others"] = (204, "")
        StubProtocol.routes["GET /api/v1/studio/totp"] = (200, #"{"enabled":false}"#)
        StubProtocol.routes["POST /api/v1/studio/totp/setup"] = (200, #"{"secret":"JBSWY3DP","uri":"otpauth://totp/x"}"#)
        StubProtocol.routes["POST /api/v1/studio/totp/enable"] = (200, #"{"recovery_codes":["a","b"]}"#)
        StubProtocol.routes["DELETE /api/v1/studio/totp"] = (204, "")
        StubProtocol.routes["GET /api/v1/remote/check"] = (200, #"{"ip":"1.2.3.4"}"#)
        let overview = try await api.services(origin)
        XCTAssertEqual(overview.services.count, 3)
        let sessions = try await api.mySessions(origin)
        XCTAssertEqual(sessions.count, 1)
        try await api.endSession(origin, id: "s1")
        try await api.endOtherSessions(origin)
        let state = try await api.totpState(origin)
        XCTAssertFalse(state.enabled)
        let setup = try await api.totpSetup(origin, password: "pw")
        XCTAssertEqual(setup.secret, "JBSWY3DP")
        XCTAssertTrue(try XCTUnwrap(StubProtocol.bodies.last).contains("\"password\":\"pw\""))
        let codes = try await api.totpEnable(origin, code: "123456")
        XCTAssertEqual(codes, ["a", "b"])
        try await api.totpDisable(origin, password: "pw")
        XCTAssertTrue(try XCTUnwrap(StubProtocol.bodies.last).contains("\"password\":\"pw\""))
        let remote = try await api.remoteCheck(origin)
        XCTAssertEqual(remote.ip, "1.2.3.4")
    }
}
