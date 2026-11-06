import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// The address of a node's panel: only the local network, only plain addresses, and the same rules as the Android app.
final class NodePanelTests: XCTestCase {
    func testAnAddressOfTheLocalNetworkBecomesTheAddressOfThePanel() {
        XCTAssertEqual(NodeAddress.parse("192.168.0.235"), "http://192.168.0.235/")
        XCTAssertEqual(NodeAddress.parse(" http://192.168.0.235/ "), "http://192.168.0.235/")
        XCTAssertEqual(NodeAddress.parse("10.0.0.7:8080"), "http://10.0.0.7:8080/")
        XCTAssertEqual(NodeAddress.parse("172.16.5.4:80"), "http://172.16.5.4/")
        XCTAssertEqual(NodeAddress.parse("172.31.255.254"), "http://172.31.255.254/")
    }

    func testAnythingElseIsRefused() {
        for text in ["", "armor.local", "8.8.8.8", "172.15.0.1", "172.32.0.1", "192.169.0.1", "192.168.0.256", "192.168.0.010", "192.168.0", "192.168.0.1:0", "192.168.0.1:65536", "192.168.0.1:abc",
                     "192.168.0.1/api", "https://192.168.0.1", "user@192.168.0.1", "192.168.0.1:80:90", "127.0.0.1"] {
            XCTAssertNil(NodeAddress.parse(text), text)
        }
    }

    func testTheRecentAddressesKeepTheLatestFirstWithoutRepeatsAndAtMostFive() {
        var recent: [String] = []
        for index in 1...7 { recent = NodeAddress.remember("http://10.0.0.\(index)/", among: recent) }
        XCTAssertEqual(recent.count, 5)
        XCTAssertEqual(recent.first, "http://10.0.0.7/")
        recent = NodeAddress.remember("http://10.0.0.5/", among: recent)
        XCTAssertEqual(recent, ["http://10.0.0.5/", "http://10.0.0.7/", "http://10.0.0.6/", "http://10.0.0.4/", "http://10.0.0.3/"])
    }

    func testThePanelThroughTheServerHasTheAddressOfTheServer() {
        XCTAssertEqual(NodeServerPanel.address(origin: "http://192.168.0.180:18080", nodeId: "radar-1"), "http://192.168.0.180:18080/api/v1/nodes/radar-1/panel/")
        XCTAssertEqual(NodeServerPanel.address(origin: "https://casa.example.org", nodeId: "a.b_c"), "https://casa.example.org/api/v1/nodes/a.b_c/panel/")
        XCTAssertNil(NodeServerPanel.address(origin: "http://casa.example.org", nodeId: "radar-1"))   // plain http outside the home is refused
        XCTAssertNil(NodeServerPanel.address(origin: "http://192.168.0.180", nodeId: "../x"))
        XCTAssertNil(NodeServerPanel.address(origin: "http://192.168.0.180", nodeId: "a b"))
        XCTAssertNil(NodeServerPanel.address(origin: "http://192.168.0.180", nodeId: ""))
        XCTAssertNil(NodeServerPanel.address(origin: "not an address", nodeId: "radar-1"))
    }

    func testOnlyAPanelOfTheServerNeedsTheSessionAndTheOnlyLinksFollowedAreTheNodesOwn() {
        let server = "http://192.168.0.180:18080/"
        XCTAssertTrue(NodeServerPanel.isViaServer("http://192.168.0.180:18080/api/v1/nodes/radar-1/panel/", origin: server))
        XCTAssertFalse(NodeServerPanel.isViaServer("http://192.168.0.235/", origin: server))
        XCTAssertFalse(NodeServerPanel.isViaServer("http://192.168.0.180:18080/api/v1/nodes/x/panel/", origin: ""))
        XCTAssertTrue(NodeServerPanel.sameHost("http://192.168.0.235/config", as: "http://192.168.0.235/"))
        XCTAssertFalse(NodeServerPanel.sameHost("http://evil.example.org/", as: "http://192.168.0.235/"))
    }

    func testForgettingANodeCallsTheRouteOfTheNodeHealth() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api: ArmorApi = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        StubProtocol.routes["DELETE /api/v1/node-health/radar 1"] = (204, "")
        try await api.forgetNode("http://192.168.0.180:8080", id: "radar 1")
        StubProtocol.routes["DELETE /api/v1/node-health/gone"] = (404, "{}")
        try await api.forgetNode("http://192.168.0.180:8080", id: "gone")   // a node the server no longer knows is not a failure
        StubProtocol.routes["DELETE /api/v1/node-health/denied"] = (403, "{\"error\":\"forbidden\"}")
        do { try await api.forgetNode("http://192.168.0.180:8080", id: "denied"); XCTFail("must refuse") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 403) }
    }
}
