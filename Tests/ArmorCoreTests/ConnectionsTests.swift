import XCTest
@testable import ArmorCore

/// The list of connections of the history: what the server answers is read as it is and never trusted blindly.
final class ConnectionsTests: XCTestCase {
    private func object(_ text: String) -> JSON { (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? JSON ?? [:] }

    func testTheClientsAreReadAndWhatIsNotAClientIsLeftOut() {
        let list = ConnectionsParser.list(object("""
        {"clients":[
          {"id":"0123456789abcdef","kind":"android","user":"ana","label":"Pixel","app_version":"0.8.0.5","first_seen":"2026-01-01T10:00:00Z","last_seen":"2026-01-02T10:00:00Z","active_sessions":2,"logins_ok":5,"logins_failed":1,"ip":"192.168.0.9"},
          {"id":"fedcba9876543210","kind":"studio","first_seen":"a","last_seen":"b","active_sessions":-3},
          {"id":"short","kind":"studio"},
          {"id":"0123456789abcdef","kind":"toaster"},
          {"id":"ABCDEF0123456789","kind":"other"}
        ]}
        """))
        XCTAssertEqual(list.map { $0.id }, ["0123456789abcdef", "fedcba9876543210"])
        XCTAssertEqual(list[0].user, "ana")
        XCTAssertEqual(list[0].activeSessions, 2)
        XCTAssertEqual(list[0].loginsFailed, 1)
        XCTAssertEqual(list[0].ip, "192.168.0.9")
        XCTAssertNil(list[1].user)
        XCTAssertNil(list[1].ip)
        XCTAssertEqual(list[1].activeSessions, 0)   // never negative
        XCTAssertEqual(ConnectionsParser.list([:]).count, 0)
    }

    func testTheTitleNamesTheKindAndThePartsThatExist() {
        let t = plain()
        let list = ConnectionsParser.list(object(#"{"clients":[{"id":"0123456789abcdef","kind":"android","user":"ana","label":"Pixel","app_version":"0.8"},{"id":"fedcba9876543210","kind":"voice"}]}"#))
        XCTAssertEqual(ConnectionsParser.title(list[0], t), "App Android · Pixel · ana · Versión 0.8")
        XCTAssertEqual(ConnectionsParser.title(list[1], t), "Servicio de voz")
    }
}
