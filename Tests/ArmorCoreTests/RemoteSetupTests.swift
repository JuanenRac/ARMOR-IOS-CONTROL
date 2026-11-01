import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

final class RemoteSetupTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    private let sample = """
    {"wireguard":{"script":true,"tool":true,"configured":true,"running":false,"endpoint":"casa.duckdns.org:51821","subnet":"10.8.0.0/24","port":"51820",
                  "peers":[{"name":"movil-ana","address":"10.8.0.2"},{"name":" ","address":"x"}]},
     "ddns":{"script":true,"configured":true,"provider":"duckdns","name":"casa","last_address":"203.0.113.9"}}
    """

    func testTheWayInFromOutsideIsReadWithItsDevices() {
        let setup = SecurityParser.remoteSetup(json(sample))
        XCTAssertTrue(setup.vpnConfigured)
        XCTAssertFalse(setup.vpnRunning)
        XCTAssertEqual(setup.peers, [VpnPeer(name: "movil-ana", address: "10.8.0.2")])
        XCTAssertEqual(setup.ddnsName, "casa")
        XCTAssertEqual(setup.ddnsLast, "203.0.113.9")
        let empty = SecurityParser.remoteSetup([:])
        XCTAssertFalse(empty.vpnScript)
        XCTAssertTrue(empty.peers.isEmpty)
    }

    func testThePortToForwardComesFromTheEndpointThenFromTheSetup() {
        XCTAssertEqual(SecurityParser.forwardedPort(SecurityParser.remoteSetup(json(sample))), "51821")
        XCTAssertEqual(SecurityParser.forwardedPort(SecurityParser.remoteSetup(json(#"{"wireguard":{"endpoint":"casa.duckdns.org","port":"4000"}}"#))), "4000")
        XCTAssertEqual(SecurityParser.forwardedPort(SecurityParser.remoteSetup([:])), "51820")
    }

    func testTheNameOfADeviceKeepsOnlyWhatTheHelperTakes() {
        XCTAssertEqual(SecurityParser.cleanPeerName("movil ana!_1-b"), "movilana_1-b")
        XCTAssertEqual(SecurityParser.cleanPeerName(String(repeating: "a", count: 40)).count, 32)
        XCTAssertEqual(SecurityParser.cleanPeerName("ñandú"), "and")
    }

    func testThePrivateKeyOfADeviceNeverPrintsInALog() {
        let config = SecurityParser.peerConfig(json(#"{"name":"movil-ana","config":"[Interface]\nPrivateKey = SECRETSECRET\n"}"#))
        XCTAssertEqual(config.name, "movil-ana")
        XCTAssertTrue(config.config.contains("SECRETSECRET"))
        for text in [String(describing: config), String(reflecting: config), "\(config)"] {
            XCTAssertFalse(text.contains("SECRETSECRET"))
            XCTAssertTrue(text.contains("<hidden>"))
        }
    }

    func testCopyingTheConfigurationIsOffByDefaultAndTheTimeIsKeptInRange() {
        XCTAssertFalse(PeerConfigPolicy.defaults.allowCopy)
        XCTAssertEqual(PeerConfigPolicy.bundled(), PeerConfigPolicy.defaults)
        XCTAssertEqual(PeerConfigPolicy.parse([:]), PeerConfigPolicy.defaults)
        XCTAssertTrue(PeerConfigPolicy.parse(["allow_copy_peer_config": true]).allowCopy)
        XCTAssertEqual(PeerConfigPolicy.parse(["peer_config_visible_seconds": 1]).visibleSeconds, 10)
        XCTAssertEqual(PeerConfigPolicy.parse(["peer_config_visible_seconds": 99999]).visibleSeconds, 600)
    }

    func testTheNamesOfTheDynamicAddressServices() {
        let t = plain("es")
        XCTAssertEqual(SecurityText.ddnsProviderName("duckdns", t), "DuckDNS (gratuito)")
        XCTAssertEqual(SecurityText.ddnsProviderName("cloudflare", t), "Cloudflare")
        XCTAssertEqual(SecurityText.ddnsProviderName("url", t), "Otro (una dirección a la que llamar)")
    }

    func testTheCallsGoToTheirPathsAndSendWhatTheHelperNeeds() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api: ArmorApi = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        let origin = "http://192.168.0.180:8080"
        StubProtocol.routes["GET /api/v1/admin/remote"] = (200, sample)
        StubProtocol.routes["POST /api/v1/admin/remote/wireguard/setup"] = (200, sample)
        StubProtocol.routes["POST /api/v1/admin/remote/wireguard/peers"] = (201, #"{"name":"movil-ana","config":"cfg"}"#)
        StubProtocol.routes["GET /api/v1/admin/remote/wireguard/peers/movil-ana"] = (200, #"{"name":"movil-ana","config":"cfg2"}"#)
        StubProtocol.routes["DELETE /api/v1/admin/remote/wireguard/peers/movil-ana"] = (200, "{}")
        StubProtocol.routes["POST /api/v1/admin/remote/ddns/setup"] = (200, sample)
        StubProtocol.routes["POST /api/v1/admin/remote/ddns/update"] = (200, sample)
        StubProtocol.routes["POST /api/v1/admin/remote/ddns/remove"] = (200, sample)
        let read = try await api.remoteSetup(origin)
        XCTAssertEqual(read.peers.count, 1)
        _ = try await api.vpnSetup(origin, endpoint: "casa.duckdns.org", port: 51820, lan: "192.168.0.0/24", routeLan: "")
        var body = try XCTUnwrap(StubProtocol.bodies.last)
        for piece in ["\"endpoint\":\"casa.duckdns.org\"", "\"port\":51820", "\"lan\":"] { XCTAssertTrue(body.contains(piece), piece) }
        XCTAssertFalse(body.contains("route_lan"))
        let added = try await api.vpnAddPeer(origin, name: "movil-ana", fullTunnel: true)
        XCTAssertEqual(added.config, "cfg")
        body = try XCTUnwrap(StubProtocol.bodies.last)
        XCTAssertTrue(body.contains("\"full_tunnel\":true"))
        let shown = try await api.vpnShowPeer(origin, name: "movil-ana")
        XCTAssertEqual(shown.config, "cfg2")
        try await api.vpnRemovePeer(origin, name: "movil-ana")
        _ = try await api.ddnsSetup(origin, provider: "duckdns", domain: "casa", token: "tok", zone: "", record: "", url: "")
        body = try XCTUnwrap(StubProtocol.bodies.last)
        for piece in ["\"provider\":\"duckdns\"", "\"domain\":\"casa\"", "\"token\":\"tok\""] { XCTAssertTrue(body.contains(piece), piece) }
        XCTAssertFalse(body.contains("zone"))
        _ = try await api.ddnsUpdate(origin)
        _ = try await api.ddnsRemove(origin)
    }
}
