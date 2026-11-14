import XCTest
@testable import ArmorCore

final class EnrolmentCodeTests: XCTestCase {
    private let code = "Q2hpbGRyZW5PZkFyY2hpdGVjdHM"
    private let fingerprint = "79ca85e16340bbc46012defe4cfdff30287c1f0fa5f8dc26b395d15e498e8a7a"
    private let origin = "https://armor.example.org:18080"
    private func text(ca: String? = nil, extra: String = "", version: Int = 1, address: String? = nil, code overridden: String? = nil) -> String {
        "armor-enrol:{\"ca\":\"\(ca ?? fingerprint)\",\"code\":\"\(overridden ?? code)\",\"origin\":\"\(address ?? origin)\"\(extra),\"v\":\(version)}"
    }

    func testReadsTheTextStudioWrites() {
        XCTAssertEqual(EnrolmentCode.parse(text()), Enrolment(origin: origin, code: code, caFingerprint: fingerprint))
        XCTAssertEqual(EnrolmentCode.parse(text(ca: ""))?.caFingerprint, "")
        XCTAssertEqual(EnrolmentCode.parse(text(address: "https://armor.example.org/"))?.origin, "https://armor.example.org")
    }

    func testRefusesAnythingThatIsNotExactlyThatText() {
        XCTAssertNil(EnrolmentCode.parse(nil))
        XCTAssertNil(EnrolmentCode.parse(text(extra: ",\"password\":\"x\"")))
        XCTAssertNil(EnrolmentCode.parse(text(version: 2)))
        XCTAssertNil(EnrolmentCode.parse(text(address: "http://armor.local")))
        XCTAssertNil(EnrolmentCode.parse(text(address: "https://user:pw@armor.local")))
        XCTAssertNil(EnrolmentCode.parse(text(address: "https://armor.local/api")))
        XCTAssertNil(EnrolmentCode.parse(text(address: "https://armor.local/?x=1")))
        XCTAssertNil(EnrolmentCode.parse(text(ca: "abcd")))
        XCTAssertNil(EnrolmentCode.parse(text(ca: fingerprint.uppercased())))
        XCTAssertNil(EnrolmentCode.parse(text(code: "short")))
        XCTAssertNil(EnrolmentCode.parse("armor-provision:{\"node_id\":\"a\",\"server\":\"\(origin)\",\"v\":1}"))
        XCTAssertNil(EnrolmentCode.parse("armor-enrol:[1]"))
        XCTAssertNil(EnrolmentCode.parse("armor-enrol:{broken"))
        XCTAssertNil(EnrolmentCode.parse("armor-enrol:" + String(repeating: "x", count: 400)))
        XCTAssertNil(EnrolmentCode.parse("armor-enrol:{\"ca\":\"\",\"code\":\"\(code)\",\"origin\":\"\(origin)\",\"v\":true}"))
    }

    func testTheServerAgreesOnlyWithTheSameAddressAndTheSameAuthority() throws {
        let read = try XCTUnwrap(EnrolmentCode.parse(text()))
        XCTAssertTrue(EnrolmentCode.agrees(read, EnrolmentFacts(origin: origin, caFingerprint: fingerprint)))
        XCTAssertFalse(EnrolmentCode.agrees(read, EnrolmentFacts(origin: "https://other.example.org", caFingerprint: fingerprint)))
        XCTAssertFalse(EnrolmentCode.agrees(read, EnrolmentFacts(origin: origin, caFingerprint: "")))
        XCTAssertFalse(EnrolmentCode.agrees(read, EnrolmentFacts(origin: origin, caFingerprint: String(repeating: "0", count: 64))))
    }

    func testReadsTheFactsOfTheServerAndRefusesWhatIsNotThem() {
        func facts(_ json: String) -> EnrolmentFacts? { EnrolmentCode.parseFacts(Data(json.utf8)) }
        XCTAssertEqual(facts("{\"origin\":\"\(origin)\",\"ca_fingerprint\":\"\(fingerprint)\"}"), EnrolmentFacts(origin: origin, caFingerprint: fingerprint))
        XCTAssertEqual(facts("{\"origin\":\"\(origin)\",\"ca_fingerprint\":null}"), EnrolmentFacts(origin: origin, caFingerprint: ""))
        XCTAssertNil(facts("{\"origin\":\"http://armor.local\",\"ca_fingerprint\":null}"))
        XCTAssertNil(facts("{\"ca_fingerprint\":null}"))
        XCTAssertNil(facts("{\"origin\":\"\(origin)\",\"ca_fingerprint\":5}"))
        XCTAssertNil(facts("not json"))
    }

    func testAnAuthorityNamedByTheCodePairsTheKeyOfThatCertificateOnly() {
        let pins = PinStore(MemoryStore())
        let a = String(repeating: "A", count: 43) + "=", b = String(repeating: "B", count: 43) + "=", c = String(repeating: "C", count: 43) + "="
        let leaf = String(repeating: "1", count: 64), authority = String(repeating: "2", count: 64)
        let host = "armor.example.org"
        // nothing named: a private authority the system does not know is refused, as before
        XCTAssertEqual(pins.decide(host: host, chainPins: [a, b], systemTrusts: false, chainFingerprints: [leaf, authority]), .unknownAuthority(pin: b))
        pins.expectAuthority(authority, for: host)
        XCTAssertEqual(pins.expectedAuthority(for: host), authority)
        // the chain holds that certificate: its key is the one to pair, even if the system does not know the authority
        XCTAssertEqual(pins.decide(host: host, chainPins: [a, b], systemTrusts: false, chainFingerprints: [leaf, authority]), .firstUse(pin: b))
        // the chain does not hold it: the usual rules decide, nothing is refused by the expectation
        let other = String(repeating: "3", count: 64)
        XCTAssertEqual(pins.decide(host: host, chainPins: [a, c], systemTrusts: false, chainFingerprints: [leaf, other]), .unknownAuthority(pin: c))
        XCTAssertEqual(pins.decide(host: host, chainPins: [a, c], systemTrusts: true, chainFingerprints: [leaf, other]), .firstUse(pin: c))
        // once a key is paired the expectation is not needed and a different chain is a mismatch
        pins.add(b, for: host)
        XCTAssertEqual(pins.decide(host: host, chainPins: [a, c], systemTrusts: true, chainFingerprints: [leaf, other]), .mismatch)
        pins.clearExpected(for: host)
        XCTAssertNil(pins.expectedAuthority(for: host))
    }

    func testAnExpectedAuthorityThatIsNotAFingerprintIsIgnored() {
        let pins = PinStore(MemoryStore())
        pins.expectAuthority("short", for: "armor.example.org")
        pins.expectAuthority(String(repeating: "G", count: 64), for: "armor.example.org")
        pins.expectAuthority(String(repeating: "A", count: 64), for: "armor.example.org")
        XCTAssertNil(pins.expectedAuthority(for: "armor.example.org"))
    }
}
