import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

final class ResponseLimitTests: XCTestCase {
    func testAnAnswerWithinTheLimitPassesAndOneOverItFails() throws {
        XCTAssertEqual(try ResponseLimit.check(Data(count: 10), limit: 10).count, 10)
        XCTAssertThrowsError(try ResponseLimit.check(Data(count: 11), limit: 10)) { error in
            XCTAssertEqual((error as? ArmorApiError)?.status, nil)
            XCTAssertTrue((error as? ArmorApiError)?.message.contains("longer") ?? false)
        }
    }
    func testTheClientRefusesAJsonAnswerFarOverAnyRealOne() async {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        StubProtocol.routes["GET /api/v1/status"] = (200, "{\"mode\":\"armed\",\"pad\":\"" + String(repeating: "a", count: ResponseLimit.json + 10) + "\"}")
        do { _ = try await api.status("http://192.168.0.180:8080"); XCTFail("an answer over the limit was accepted") }
        catch { XCTAssertTrue((error as? ArmorApiError)?.message.contains("longer") ?? false) }
    }
}
