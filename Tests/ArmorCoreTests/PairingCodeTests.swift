import XCTest
@testable import ArmorCore

/// The pairing code is the same text the shared library writes, and it can never hold a secret.
final class PairingCodeTests: XCTestCase {
    func testWritesTheSameTextAsTheSharedLibraryAndReadsItBack() {
        let text = PairingCode.build(nodeId: "radar-1", server: "https://armor.local:8443/")
        XCTAssertEqual(text, "armor-provision:{\"node_id\":\"radar-1\",\"server\":\"https://armor.local:8443\",\"v\":1}")
        XCTAssertEqual(PairingCode.parse(text), Pairing(nodeId: "radar-1", server: "https://armor.local:8443"))
        XCTAssertEqual(PairingCode.parse(PairingCode.build(nodeId: "a1", server: "http://192.168.0.180:18080"))?.server, "http://192.168.0.180:18080")
    }

    func testRefusesIdsAndAddressesThatAreNotValidOrCouldHoldASecret() {
        for id in ["", "-x", "Radar", "a b", String(repeating: "x", count: 65)] { XCTAssertNil(PairingCode.build(nodeId: id, server: "https://armor.local"), id) }
        for server in ["https://user:pw@armor.local", "https://user@armor.local", "https://armor.local/?token=x", "https://armor.local/#x", "https://armor.local/api",
                       "ftp://armor.local", "armor.local", "https://", "https://armor.local:99999", "https://armor .local", ""] {
            XCTAssertNil(PairingCode.cleanServer(server), server)
            XCTAssertNil(PairingCode.build(nodeId: "radar-1", server: server), server)
        }
    }

    func testRefusesExtraOrMissingFieldsOtherVersionsAndOtherText() {
        let prefix = "armor-provision:"
        for bad in ["{\"v\":1,\"node_id\":\"radar-1\",\"server\":\"https://armor.local\",\"token\":\"x\"}", "{\"v\":1,\"node_id\":\"radar-1\"}",
                    "{\"v\":2,\"node_id\":\"radar-1\",\"server\":\"https://armor.local\"}", "{\"v\":true,\"node_id\":\"radar-1\",\"server\":\"https://armor.local\"}",
                    "{\"v\":1,\"node_id\":5,\"server\":\"https://armor.local\"}"] { XCTAssertNil(PairingCode.parse(prefix + bad), bad) }
        for bad in [nil, "", "armor-provision:", "armor-provision:{", "armor-provision:[]", "other:{}", prefix + String(repeating: "x", count: 600)] { XCTAssertNil(PairingCode.parse(bad), bad ?? "nil") }
    }
}
