import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// The client the screens use (ArmorApiClient) against a REAL ARMOR-SERVER started on the runner of the workflow `swift-tests.yml` (job "Screens against the real server").
/// The address comes from the environment variable ARMOR_SERVER_URL; without it every test here is skipped, so a run that has no server never fails for lack of one.
/// The administrator is the one the workflow gives the server. Nothing here touches a real installation, a phone or a camera.
final class ServerLiveTests: XCTestCase {
    private let user = "admin"
    private let password = "correct-horse-battery"

    private func server() throws -> String {
        guard let origin = ProcessInfo.processInfo.environment["ARMOR_SERVER_URL"], !origin.isEmpty else { throw XCTSkip("no ARMOR_SERVER_URL: this run has no server") }
        return origin
    }

    private func signedIn() async throws -> (ArmorApiClient, String) {
        let origin = try server()
        let client = ArmorApiClient(session: ArmorApiClient.makeSession(), clientTag: "ios-test")
        let result = try await client.signIn(origin, username: user, password: password)
        XCTAssertEqual(result, .done, "a plain password sign-in is complete")
        return (client, origin)
    }

    /// A screen reads a route: the server may say no (a feature that is not set up answers an error with a status), but what it sends must never break the reader.
    private func reads<T>(_ name: String, _ read: () async throws -> T) async {
        do { _ = try await read() }
        catch let error as ArmorApiError { XCTAssertNotNil(error.status, "\(name): a refusal of the server carries a status") }
        catch { XCTFail("\(name): the reader failed on what the real server sent: \(error)") }
    }

    func testAWrongPasswordIsRefusedByTheRealServer() async throws {
        let origin = try server()
        let client = ArmorApiClient(session: ArmorApiClient.makeSession(), clientTag: "ios-test")
        do { _ = try await client.signIn(origin, username: user, password: "not-the-password"); XCTFail("the server accepted a wrong password") }
        catch let error as ArmorApiError { XCTAssertTrue((400...429).contains(error.status ?? 400), "the refusal carries a client-error status") }
    }

    func testTheAdministratorSignsInAndReadsTheStateOfTheSystem() async throws {
        let (client, origin) = try await signedIn()
        let snapshot = try await client.status(origin)
        XCTAssertEqual(snapshot.mode, "disarmed", "a fresh server is disarmed")
        let facts = try await client.sessionFacts(origin)
        XCTAssertEqual(facts.role, "admin", "the administrator is read back as one")
    }

    func testTheScreensThatListThingsGetEmptyListsFromAFreshServerNotErrors() async throws {
        let (client, origin) = try await signedIn()
        let lists = try await client.alarms(origin)
        XCTAssertTrue(lists.active.isEmpty)
        XCTAssertTrue(lists.recent.isEmpty)
        _ = try await client.preflight(origin)
    }

    func testEveryScreenReaderSurvivesWhatTheRealServerSends() async throws {
        let (client, origin) = try await signedIn()
        await reads("history") { try await client.history(origin, limit: 20, before: nil, after: nil) }
        await reads("devices") { try await client.devices(origin) }
        await reads("camera views") { try await client.cameraViews(origin) }
        await reads("camera status") { try await client.cameraStatus(origin) }
        await reads("alarm panels") { try await client.alarmPanels(origin) }
        await reads("arm profiles") { try await client.armProfiles(origin) }
        await reads("alarm commands") { try await client.alarmCommandsEnabled(origin) }
        await reads("arming modes") { try await client.armingModes(origin) }
        await reads("solar") { try await client.solar(origin) }
        await reads("electrical") { try await client.electrical(origin) }
        await reads("battery operations") { try await client.batteryOperations(origin) }
        await reads("network") { try await client.network(origin) }
        await reads("services") { try await client.services(origin) }
        await reads("node health") { try await client.nodeHealth(origin) }
        await reads("connections") { try await client.connections(origin) }
        await reads("site") { try await client.site(origin) }
        await reads("node control operations") { try await client.nodeControlOperations(origin) }
        await reads("machine update") { try await client.machineUpdateState(origin) }
        await reads("my sessions") { try await client.mySessions(origin) }
        await reads("second factor") { try await client.totpState(origin) }
        await reads("remote check") { try await client.remoteCheck(origin) }
    }
}
