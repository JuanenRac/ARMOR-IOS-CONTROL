import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

/// The library of recordings: what is read from the server's list, the routes of the files, and the calls to look at one and to delete one.
final class EvidenceTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }
    private func item(_ kind: String = "snapshot", camera: String = "cam-front", file: String = "a.jpg") -> MediaItemView {
        MediaItemView(id: "i1", cameraId: camera, kind: kind, file: file, createdAt: "2026-03-05T10:42:17.123Z", bytes: 2048)
    }

    func testTheLibraryIsReadWithItsItemsAndTheCamerasThatAreRecording() {
        let library = EvidenceParser.catalogue(json("""
        {"items":[{"id":"1","cameraId":"cam-front","kind":"snapshot","file":"a.jpg","createdAt":"2026-03-05T10:42:17Z","bytes":2048},
                  {"id":"2","cameraId":"cam-back","kind":"recording","file":"b.mp4","createdAt":"2026-03-05T11:00:00Z","bytes":9000000}],
         "activeCameraIds":["cam-back",""]}
        """))
        XCTAssertEqual(library.items.map(\.id), ["1", "2"])
        XCTAssertEqual(library.items.map(\.isPhoto), [true, false])
        XCTAssertEqual(library.items[1].bytes, 9_000_000)
        XCTAssertEqual(library.activeCameraIds, ["cam-back"])
    }

    func testAnItemWithAFieldMissingIsLeftOutAndNotTheWholeLibrary() {
        let library = EvidenceParser.catalogue(json("""
        {"items":[{"id":"","cameraId":"c","kind":"snapshot","file":"a.jpg"},{"id":"2","cameraId":"","kind":"snapshot","file":"a.jpg"},{"id":"3","cameraId":"c","kind":"","file":"a.jpg"},
                  {"id":"4","cameraId":"c","kind":"snapshot","file":""},{"id":"5","cameraId":"c","kind":"snapshot","file":"ok.jpg"}]}
        """))
        XCTAssertEqual(library.items.map(\.id), ["5"])
        XCTAssertEqual(library.items[0].bytes, 0)
        XCTAssertTrue(library.activeCameraIds.isEmpty)
        XCTAssertEqual(EvidenceParser.catalogue([:]), MediaCatalogueView())
    }

    func testAPhotoAndAVideoLiveInDifferentFoldersAndNothingClimbsOutOfThePath() {
        XCTAssertEqual(EvidenceParser.path(item("snapshot")), "/api/v1/media/cam-front/snapshots/a.jpg")
        XCTAssertEqual(EvidenceParser.path(item("recording", file: "b.mp4")), "/api/v1/media/cam-front/recordings/b.mp4")
        XCTAssertEqual(EvidenceParser.path(item("snapshot", camera: "cam 1/../x", file: "../../etc passwd")), "/api/v1/media/cam%201%2F..%2Fx/snapshots/..%2F..%2Fetc%20passwd")
    }

    func testTheDayAndTheSizeAreShownAsAPersonReadsThem() {
        XCTAssertEqual(EvidenceParser.when("2026-03-05T10:42:17.123Z"), "2026-03-05 10:42")
        XCTAssertEqual(EvidenceParser.when("not a date"), "not a date")
        XCTAssertEqual(EvidenceParser.when("2026-03-05"), "2026-03-05")
        XCTAssertEqual(EvidenceParser.when(""), "")
        XCTAssertEqual(EvidenceParser.size(-5), "0 B")
        XCTAssertEqual(EvidenceParser.size(900), "900 B")
        XCTAssertEqual(EvidenceParser.size(2048), "2 KB")
        XCTAssertEqual(EvidenceParser.size(1_572_864), "1.5 MB")
        XCTAssertEqual(EvidenceParser.size(1_048_576), "1.0 MB")
    }
}

final class EvidenceClientTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private var api: ArmorApi!

    override func setUp() {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        api = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
    }

    private let photo = MediaItemView(id: "1", cameraId: "cam-front", kind: "snapshot", file: "a.jpg", createdAt: "2026-03-05T10:42:17Z", bytes: 5)

    func testTheLibraryIsReadFromItsPathThroughTheProtocol() async throws {
        StubProtocol.routes["GET /api/v1/media"] = (200, #"{"items":[{"id":"1","cameraId":"cam-front","kind":"snapshot","file":"a.jpg","createdAt":"2026-03-05T10:42:17Z","bytes":5}],"activeCameraIds":["cam-front"]}"#)
        let library = try await api.media(origin)
        XCTAssertEqual(library.items.count, 1)
        XCTAssertEqual(library.activeCameraIds, ["cam-front"])
    }

    func testARefusedListKeepsItsStatus() async {
        StubProtocol.routes["GET /api/v1/media"] = (401, #"{"error":"unauthorized"}"#)
        do { _ = try await api.media(origin); XCTFail("must refuse") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 401) } catch { XCTFail("\(error)") }
    }

    func testDeletingAFileSendsTheDeleteToItsFolderAndAViewerIsRefused() async throws {
        StubProtocol.routes["DELETE /api/v1/media/cam-front/snapshots/a.jpg"] = (204, "{}")
        try await api.deleteMedia(origin, item: photo)
        XCTAssertEqual(StubProtocol.seen.last?.httpMethod, "DELETE")
        StubProtocol.routes["DELETE /api/v1/media/cam-front/snapshots/a.jpg"] = (403, #"{"error":"forbidden"}"#)
        do { try await api.deleteMedia(origin, item: photo); XCTFail("must refuse") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 403) } catch { XCTFail("\(error)") }
    }

    // Downloads through a stand-in protocol are only supported by Foundation on Apple systems: these two run in the macOS job.
#if !canImport(FoundationNetworking)
    func testAFileIsTakenToATemporaryCopyThatKeepsItsEnding() async throws {
        StubProtocol.routes["GET /api/v1/media/cam-front/recordings/b.mp4"] = (200, "VIDEO-BYTES")
        let video = MediaItemView(id: "2", cameraId: "cam-front", kind: "recording", file: "b.mp4", createdAt: "", bytes: 11)
        let copy = try await api.mediaFile(origin, item: video)
        defer { try? FileManager.default.removeItem(at: copy) }
        XCTAssertEqual(copy.pathExtension, "mp4")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "VIDEO-BYTES")
    }

    func testAFileTheServerRefusesLeavesNothingBehindAndSaysWhy() async {
        StubProtocol.routes["GET /api/v1/media/cam-front/snapshots/a.jpg"] = (404, #"{"error":"not_found"}"#)
        do { _ = try await api.mediaFile(origin, item: photo); XCTFail("must refuse") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 404) } catch { XCTFail("\(error)") }
    }
#endif

    func testAnApiWithoutTheLibraryRefusesInsteadOfInventingOne() async {
        let bare = FakeApi()
        do { _ = try await bare.media(origin); XCTFail("must refuse") } catch let error as ArmorApiError { XCTAssertNil(error.status) } catch { XCTFail("\(error)") }
    }
}
