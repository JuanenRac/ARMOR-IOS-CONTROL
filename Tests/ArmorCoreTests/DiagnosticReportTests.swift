import XCTest
@testable import ArmorCore

final class DiagnosticReportTests: XCTestCase {
    private func info(origin: String = "https://casa.example.org:8443/x?a=b", recent: [DiagnosticLog.Entry] = []) -> DiagnosticInfo {
        DiagnosticInfo(appVersion: "0.8.0.2", appBuild: "80002", systemVersion: "17.4", device: "iPhone", language: "es", origin: origin, role: "admin", notificationsAllowed: true, recent: recent, nowMs: 100_000)
    }

    func testARouteIsReducedToItsShapeWithNoQueryOrIds() {
        XCTAssertEqual(DiagnosticLog.shape("/api/v1/cameras/gate/snapshot?ticket=SECRET"), "/api/v1/cameras/gate/…")
        XCTAssertEqual(DiagnosticLog.shape("/api/v1/alarms"), "/api/v1/alarms")
        XCTAssertEqual(DiagnosticLog.shape("?x=1"), "/")
    }

    func testOnlyTheLastAnswersAreKeptAndTheOldestGoesFirst() {
        let log = DiagnosticLog()
        for index in 1...40 { log.record(method: "GET", path: "/api/v1/state", status: 200 + index, atMs: Int64(index)) }
        let kept = log.recent()
        XCTAssertEqual(kept.count, 25)
        XCTAssertEqual(kept.first?.status, 216)
        XCTAssertEqual(kept.last?.status, 240)
    }

    func testTheAddressIsReducedToSchemeAndHostAndNeverHoldsASignIn() {
        XCTAssertEqual(DiagnosticReport.originLabel("https://user:pass@casa.example.org:8443/x?a=b"), "https://casa.example.org")
        XCTAssertEqual(DiagnosticReport.originLabel("ftp://host"), "not set")
        XCTAssertEqual(DiagnosticReport.originLabel(""), "not set")
    }

    func testTheReportSaysWhatIsKnownAndWhatIsNotAndHoldsNoSecret() {
        let log = DiagnosticLog()
        log.record(method: "POST", path: "/api/v1/alarm/command?pin=1234", status: 403, atMs: 90_000)
        let text = DiagnosticReport.render(info(origin: "https://user:pass@casa.example.org/x", recent: log.recent()))
        XCTAssertTrue(text.contains("App: 0.8.0.2 (build 80002)"))
        XCTAssertTrue(text.contains("Server: https://casa.example.org"))
        XCTAssertTrue(text.contains("POST /api/v1/alarm/command -> 403 (10s ago)"))
        for secret in ["user:pass", "1234", "pin="] { XCTAssertFalse(text.contains(secret), secret) }
    }
}
