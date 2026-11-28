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
    func testPlainHttpAfterHttpsIsNotEvenAsked() async throws {
        let memory = SchemeMemory(MemoryStore())
        let only = SavedInstallation(homeHost: "192.168.0.180", homePort: "8080")
        memory.reached(try XCTUnwrap(URL(string: "https://192.168.0.180:8443/api")))
        let selection = await Connector.select(api: FakeApi(), installation: only, place: .home, networkAvailable: true, schemes: memory)
        XCTAssertEqual(selection, .failed(.plainAfterSecure))
    }
    func testAnotherAddressThatIsAllowedIsStillUsed() async throws {
        let memory = SchemeMemory(MemoryStore())
        memory.reached(try XCTUnwrap(URL(string: "https://192.168.0.180/")))
        let selection = await Connector.select(api: FakeApi(), installation: both, place: .home, networkAvailable: true, schemes: memory)
        XCTAssertEqual(selection, .reached(try XCTUnwrap(both.endpoints.away)))
    }
    func testTheMemoryOfTheScheme() throws {
        let store = MemoryStore()
        let memory = SchemeMemory(store)
        let plain = try XCTUnwrap(URL(string: "http://192.168.0.180:8080/x"))
        XCTAssertTrue(memory.allows(plain))
        memory.reached(plain)
        XCTAssertTrue(memory.allows(plain), "plain http teaches nothing")
        memory.reached(try XCTUnwrap(URL(string: "https://192.168.0.180/")))
        XCTAssertFalse(memory.allows(plain))
        XCTAssertEqual(store.get("https_seen_192.168.0.180"), "1")
        XCTAssertTrue(memory.allows(origin: "http://192.168.0.181:8080"))
        memory.enabled = false
        XCTAssertTrue(memory.allows(plain))
        memory.enabled = true
        memory.forget(host: "192.168.0.180")
        XCTAssertTrue(memory.allows(plain))
    }
    func testOnlyAChangedAddressForgetsTheScheme() throws {
        let memory = SchemeMemory(MemoryStore())
        let secure = try XCTUnwrap(URL(string: "https://192.168.0.180/"))
        let old = SavedInstallation(homeHost: "192.168.0.180", homePort: "8080")
        memory.reached(secure)
        memory.forgetChanged(from: old, to: old)
        XCTAssertFalse(memory.allows(origin: "http://192.168.0.180:8080"))
        memory.forgetChanged(from: old, to: SavedInstallation(homeHost: "192.168.0.180", homePort: "8081"))
        XCTAssertTrue(memory.allows(origin: "http://192.168.0.180:8081"))
    }
    func testTheClientRefusesPlainHttpAfterHttps() async throws {
        let memory = SchemeMemory(MemoryStore())
        memory.reached(try XCTUnwrap(URL(string: "https://192.168.0.180/")))
        let client = ArmorApiClient(session: ArmorApiClient.makeSession(), clientTag: "test", schemes: memory)
        do {
            _ = try await client.sessionFacts("http://192.168.0.180:8080")
            XCTFail("it was asked")
        } catch let error as ArmorApiError {
            XCTAssertNil(error.status)
            XCTAssertTrue(error.message.contains("refused"))
        }
    }
    func testIsAway() throws {
        XCTAssertTrue(Reach.isAway(try XCTUnwrap(both.endpoints.away), installation: both))
        XCTAssertFalse(Reach.isAway(try XCTUnwrap(both.endpoints.home), installation: both))
    }
    func testEveryProblemHasWords() {
        for problem in [ReachProblem.noAddress, .offline, .homeUnreachableNoRemote, .remoteUnreachable, .bothUnreachable, .certificateChanged, .plainAfterSecure] {
            XCTAssertFalse(problem.message(t).isEmpty)
        }
    }
}
