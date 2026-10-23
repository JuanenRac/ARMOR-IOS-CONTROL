import XCTest
@testable import ArmorCore

final class ReachTests: XCTestCase {
    private let t = plain()
    private var both: SavedInstallation { SavedInstallation(homeHost: "192.168.0.180", homePort: "8080", awayHost: "https://casa.duckdns.org", awayPort: "443") }

    func testInstallationRoundTrips() {
        let store = MemoryStore()
        both.save(to: store)
        XCTAssertEqual(SavedInstallation.load(from: store), both)
        XCTAssertNotNil(both.endpoints.home)
        XCTAssertNotNil(both.endpoints.away)
    }
    func testAtHomeTheHomeAddressIsUsed() async throws {
        let selection = await Connector.select(api: FakeApi(), installation: both, place: .home, networkAvailable: true)
        XCTAssertEqual(selection, .reached(try XCTUnwrap(both.endpoints.home)))
    }
    func testAwayTheRemoteAddressIsUsed() async throws {
        let selection = await Connector.select(api: FakeApi(), installation: both, place: .away, networkAvailable: true)
        XCTAssertEqual(selection, .reached(try XCTUnwrap(both.endpoints.away)))
    }
    func testFallsBackToTheOtherAddress() async throws {
        let api = FakeApi()
        api.unreachable = [try XCTUnwrap(both.endpoints.home).origin]
        let selection = await Connector.select(api: api, installation: both, place: .home, networkAvailable: true)
        XCTAssertEqual(selection, .reached(try XCTUnwrap(both.endpoints.away)))
    }
    func testARefusalMeansTheAddressIsRight() async throws {
        final class Refusing: FakeApi, @unchecked Sendable {
            override func sessionFacts(_ origin: String) async throws -> SessionFacts { throw ArmorApiError(message: "no", status: 401) }
        }
        let selection = await Connector.select(api: Refusing(), installation: both, place: .home, networkAvailable: true)
        XCTAssertEqual(selection, .reached(try XCTUnwrap(both.endpoints.home)))
    }
    func testNothingAnswersSaysBothFailed() async throws {
        let api = FakeApi()
        api.unreachable = [try XCTUnwrap(both.endpoints.home).origin, try XCTUnwrap(both.endpoints.away).origin]
        let selection = await Connector.select(api: api, installation: both, place: .home, networkAvailable: true)
        XCTAssertEqual(selection, .failed(.bothUnreachable))
    }
    func testOnlyAHomeAddressUnreachableExplainsTheRemoteOne() async throws {
        let only = SavedInstallation(homeHost: "192.168.0.180", homePort: "8080")
        let api = FakeApi()
        api.unreachable = [try XCTUnwrap(only.endpoints.home).origin]
        let selection = await Connector.select(api: api, installation: only, place: .away, networkAvailable: true)
        XCTAssertEqual(selection, .failed(.homeUnreachableNoRemote))
        XCTAssertTrue(ReachProblem.homeUnreachableNoRemote.message(t).contains("No se puede llegar a casa"))
    }
    func testNoNetworkAndNoAddress() async throws {
        let api = FakeApi()
        api.unreachable = [try XCTUnwrap(both.endpoints.home).origin, try XCTUnwrap(both.endpoints.away).origin]
        let offline = await Connector.select(api: api, installation: both, place: .home, networkAvailable: false)
        XCTAssertEqual(offline, .failed(.offline))
        let none = await Connector.select(api: api, installation: SavedInstallation(), place: .home, networkAvailable: true)
        XCTAssertEqual(none, .failed(.noAddress))
    }
    func testAChangedCertificateIsReportedAsSuch() async throws {
        let api = FakeApi()
        api.unreachable = [try XCTUnwrap(both.endpoints.home).origin]
        let selection = await Connector.select(api: api, installation: both, place: .home, networkAvailable: true, pinMismatch: { true })
        XCTAssertEqual(selection, .failed(.certificateChanged))
    }
    func testIsAway() throws {
        XCTAssertTrue(Reach.isAway(try XCTUnwrap(both.endpoints.away), installation: both))
        XCTAssertFalse(Reach.isAway(try XCTUnwrap(both.endpoints.home), installation: both))
    }
    func testEveryProblemHasWords() {
        for problem in [ReachProblem.noAddress, .offline, .homeUnreachableNoRemote, .remoteUnreachable, .bothUnreachable, .certificateChanged] {
            XCTAssertFalse(problem.message(t).isEmpty)
        }
    }
}
