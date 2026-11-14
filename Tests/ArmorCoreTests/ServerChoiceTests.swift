import XCTest
@testable import ArmorCore

final class ServerChoiceTests: XCTestCase {
    func testAServerReadsWithoutItsSchemeAndASecureOneHasALock() {
        XCTAssertEqual(ServerChoice.label("http://192.168.0.50:8080"), "192.168.0.50:8080")
        XCTAssertEqual(ServerChoice.label("https://casa.example.org:443"), "\u{1F512} casa.example.org:443")
        XCTAssertEqual(ServerChoice.label("https://casa.example.org"), "\u{1F512} casa.example.org")
    }

    func testTheInstallationNamesThatServerAloneWithNoAddressForAway() {
        let plain = ServerChoice.installation(for: "http://192.168.0.50:8080")
        XCTAssertEqual(plain, SavedInstallation(homeHost: "192.168.0.50", homePort: "8080", awayHost: "", awayPort: "443"))
        let secure = ServerChoice.installation(for: "https://casa.example.org")
        XCTAssertEqual(secure, SavedInstallation(homeHost: "https://casa.example.org", homePort: "443", awayHost: "", awayPort: "443"))
        XCTAssertEqual(ServerChoice.installation(for: "https://casa.example.org:18080")?.homePort, "18080")
    }

    func testAnOriginTheAppWouldRefuseFillsNothing() {
        XCTAssertNil(ServerChoice.installation(for: "http://casa.example.org:8080"))
        XCTAssertNil(ServerChoice.installation(for: "ftp://192.168.0.50"))
        XCTAssertNil(ServerChoice.installation(for: "not an address"))
    }

    func testTheInstallationMakesTheSameEndpointAgain() {
        for origin in ["http://10.0.0.4:8080", "https://armor.example.org:18080", "https://armor.example.org:443"] {
            XCTAssertEqual(ServerChoice.installation(for: origin)?.endpoints.home?.origin, origin)
        }
    }

    func testTheOfferListsEachValidServerOnceWithTheOneInUseFirst() {
        let kept = ["http://10.0.0.4:8080", "https://armor.example.org:18080", "http://10.0.0.4:8080", "http://evil.example.org:80"]
        XCTAssertEqual(ServerChoice.offered(kept, inUse: "https://armor.example.org:18080"), ["https://armor.example.org:18080", "http://10.0.0.4:8080"])
        XCTAssertEqual(ServerChoice.offered(kept, inUse: "http://192.168.1.1:8080"), ["http://10.0.0.4:8080", "https://armor.example.org:18080"])
        XCTAssertEqual(ServerChoice.offered([], inUse: "http://10.0.0.4:8080"), [])
    }
}
