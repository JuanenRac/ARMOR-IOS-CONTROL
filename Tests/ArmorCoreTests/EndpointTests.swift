import XCTest
@testable import ArmorCore

final class EndpointTests: XCTestCase {
    func testPrivateAddressesAreAcceptedOverHttp() {
        for host in ["192.168.0.180", "10.1.2.3", "172.16.0.1", "172.31.255.255", "127.0.0.1", "localhost"] {
            XCTAssertNotNil(ServerEndpoint.fromHostAndPort(host, "8080"), host)
        }
    }
    func testPublicOrDisguisedHostsAreRefusedOverHttp() {
        for host in ["8.8.8.8", "10.attacker.example", "010.0.0.1", "172.32.0.1", "casa.duckdns.org", "192.168.0.1.evil.com"] {
            XCTAssertNil(ServerEndpoint.fromHostAndPort(host, "8080"), host)
        }
    }
    func testHttpsIsAcceptedForAName() {
        XCTAssertEqual(ServerEndpoint.fromHostAndPort("https://casa.duckdns.org", "443")?.origin, "https://casa.duckdns.org:443")
    }
    func testPortMustBeValid() {
        XCTAssertNil(ServerEndpoint.fromHostAndPort("192.168.0.2", "0"))
        XCTAssertNil(ServerEndpoint.fromHostAndPort("192.168.0.2", "70000"))
        XCTAssertNil(ServerEndpoint.fromHostAndPort("192.168.0.2", "abc"))
    }
    func testParseRefusesCredentialsQueryAndPath() {
        XCTAssertNil(ServerEndpoint.parse("http://user:pw@192.168.0.2:8080"))
        XCTAssertNil(ServerEndpoint.parse("http://192.168.0.2:8080?x=1"))
        XCTAssertNil(ServerEndpoint.parse("http://192.168.0.2:8080/api"))
        XCTAssertEqual(ServerEndpoint.parse("http://192.168.0.2:8080/")?.origin, "http://192.168.0.2:8080")
    }
    func testNeedsSecureConnectionAndPublicIp() {
        XCTAssertTrue(ServerEndpoint.needsSecureConnection("casa.duckdns.org"))
        XCTAssertFalse(ServerEndpoint.needsSecureConnection("https://casa.duckdns.org"))
        XCTAssertFalse(ServerEndpoint.needsSecureConnection("192.168.0.2"))
        XCTAssertTrue(ServerEndpoint.usesPublicIpAddress("8.8.8.8"))
        XCTAssertFalse(ServerEndpoint.usesPublicIpAddress("192.168.0.2"))
        XCTAssertFalse(ServerEndpoint.usesPublicIpAddress("casa.duckdns.org"))
    }
    func testDualEndpointChoosesByPlace() throws {
        let home = try XCTUnwrap(ServerEndpoint.parse("http://192.168.0.180:8080")), away = try XCTUnwrap(ServerEndpoint.parse("https://casa.duckdns.org:443"))
        let both = DualEndpoint(home: home, away: away)
        XCTAssertEqual(both.chosen(for: .home), home)
        XCTAssertEqual(both.chosen(for: .away), away)
        XCTAssertEqual(both.chosen(for: .unknown), home)
        XCTAssertEqual(both.alternative(to: home), away)
        XCTAssertEqual(both.alternative(to: away), home)
        XCTAssertEqual(DualEndpoint(home: home, away: nil).chosen(for: .away), home)
        XCTAssertNil(DualEndpoint(home: home, away: nil).alternative(to: home))
        XCTAssertEqual(DualEndpoint(home: nil, away: away).chosen(for: .home), away)
    }
}
