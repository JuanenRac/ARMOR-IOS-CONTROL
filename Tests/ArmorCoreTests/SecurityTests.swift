import XCTest
@testable import ArmorCore

final class SecurityTests: XCTestCase {
    private let a = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    private let b = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    private let c = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="

    func testPinWellFormed() {
        XCTAssertTrue(PinStore.isWellFormed(a))
        XCTAssertFalse(PinStore.isWellFormed("short="))
        XCTAssertFalse(PinStore.isWellFormed(String(repeating: "A", count: 44)))
    }
    func testFirstUseThenTrustedThenMismatch() {
        let store = PinStore(MemoryStore())
        XCTAssertEqual(store.decide(host: "casa", chainPins: [a, b], systemTrusts: true), .firstUse(pin: b))
        store.add(b, for: "casa")
        XCTAssertEqual(store.decide(host: "casa", chainPins: [a, b], systemTrusts: true), .trusted)
        XCTAssertEqual(store.decide(host: "CASA", chainPins: [c], systemTrusts: true), .mismatch)
        XCTAssertEqual(store.decide(host: "casa", chainPins: [c], systemTrusts: false), .mismatch)
    }
    func testAPrivateAuthorityMustBePairedFirst() {
        let store = PinStore(MemoryStore())
        XCTAssertEqual(store.decide(host: "x", chainPins: [a, b], systemTrusts: false), .unknownAuthority(pin: b))
        XCTAssertEqual(store.decide(host: "x", chainPins: [], systemTrusts: true), .mismatch)
    }
    func testAStandAloneServerPinsItsOwnKey() {
        XCTAssertEqual(PinStore(MemoryStore()).decide(host: "x", chainPins: [a], systemTrusts: true), .firstUse(pin: a))
    }
    func testAHostKeepsFourPinsAndCanBeCleared() {
        let store = PinStore(MemoryStore())
        let d = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=", e = "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE="
        for pin in [a, b, c, d, e] { store.add(pin, for: "h") }
        XCTAssertEqual(store.pins(for: "h").count, 4)
        XCTAssertFalse(store.pins(for: "h").contains(a))
        store.add("garbage", for: "h")
        XCTAssertEqual(store.pins(for: "h").count, 4)
        store.clear(for: "h")
        XCTAssertTrue(store.pins(for: "h").isEmpty)
    }
    func testQrCode() {
        XCTAssertEqual(PinStore.parseQr("armor-pin:\(a)")?.pin, a)
        XCTAssertNil(PinStore.parseQr("armor-pin:\(a)")?.host)
        let withHost = PinStore.parseQr("armor-pin:casa.duckdns.org:\(a)")
        XCTAssertEqual(withHost?.host, "casa.duckdns.org")
        XCTAssertEqual(withHost?.pin, a)
        XCTAssertNil(PinStore.parseQr("https://evil.example"))
        XCTAssertNil(PinStore.parseQr("armor-pin:nope"))
    }

    func testVaultKeepsSessionPerServerAndForgets() {
        let vault = SessionVault(secrets: MemorySecrets(), prefs: MemoryStore())
        vault.saveSession(SessionCookie(name: "armor_studio_sid", value: "v"), origin: "http://a:1")
        XCTAssertEqual(vault.loadSession(origin: "http://a:1")?.value, "v")
        XCTAssertNil(vault.loadSession(origin: "http://other:1"))
        vault.rememberLogin(origin: "http://a:1", username: "ana", password: "pw")
        XCTAssertEqual(vault.rememberedLogin(origin: "http://a:1"), RememberedLogin(username: "ana", password: "pw"))
        vault.forgetAll()
        XCTAssertNil(vault.loadSession(origin: "http://a:1"))
        XCTAssertNil(vault.rememberedLogin(origin: "http://a:1"))
    }
    func testTyingTheKeyToTheUnlockMovesWhatIsKeptAndLeavesItAloneWhileLocked() {
        let secrets = MemorySecrets()
        let vault = SessionVault(secrets: secrets, prefs: MemoryStore())
        XCTAssertFalse(vault.tiedToUnlock)
        vault.saveSession(SessionCookie(name: "n", value: "v"), origin: "o")
        XCTAssertEqual(secrets.items["session_cookie"]?.tied, false)
        XCTAssertTrue(vault.setTiedToUnlock(true))
        XCTAssertEqual(secrets.items["session_cookie"]?.tied, true)
        secrets.phoneLocked = true
        XCTAssertFalse(vault.readable())
        XCTAssertNil(vault.loadSession(origin: "o"))
        XCTAssertFalse(vault.setTiedToUnlock(false))
        XCTAssertTrue(vault.tiedToUnlock)
        XCTAssertNotNil(secrets.items["session_cookie"], "locked is not lost")
        secrets.phoneLocked = false
        XCTAssertTrue(vault.setTiedToUnlock(false))
        XCTAssertEqual(secrets.items["session_cookie"]?.tied, false)
    }
}
