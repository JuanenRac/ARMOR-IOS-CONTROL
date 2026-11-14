// ARMOR-IOS-CONTROL - the picture in the notice of a camera: when it is wanted, what is taken for a picture and how the phone asks its own server for it.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

final class NoticePhotoTests: XCTestCase {
    private let origin = "http://192.168.0.180:8080"
    private func notice(_ camera: String?) -> AlarmNotice { AlarmNotice(id: 7, title: "t", text: "x", severity: "high", kind: "camera", cameraId: camera) }

    private func client() -> ArmorApiClient {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
    }

    func testANoticeGetsAPictureOnlyWhenThePersonTurnedItOnAndTheNoticeNamesACamera() {
        XCTAssertTrue(NoticePhoto.wanted(enabled: true, notice: notice("cam-1")))
        XCTAssertFalse(NoticePhoto.wanted(enabled: false, notice: notice("cam-1")))
        XCTAssertFalse(NoticePhoto.wanted(enabled: true, notice: notice(nil)))
    }

    func testAnIdThatIsNotTheIdOfACameraOfTheServerAsksForNoPicture() {
        XCTAssertFalse(NoticePhoto.wanted(enabled: true, notice: notice("../admin")))
        XCTAssertFalse(NoticePhoto.wanted(enabled: true, notice: notice("a b")))
        XCTAssertFalse(NoticePhoto.wanted(enabled: true, notice: notice("")))
        XCTAssertFalse(NoticePhoto.validCameraId(String(repeating: "a", count: 81)))
    }

    func testOnlyTheSignatureOfAJpegOrAPngIsTakenForAPicture() {
        XCTAssertEqual(NoticePhoto.fileExtension(of: Data([0xFF, 0xD8, 0xFF, 0xE0, 1])), "jpg")
        XCTAssertEqual(NoticePhoto.fileExtension(of: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0])), "png")
        XCTAssertNil(NoticePhoto.fileExtension(of: Data(#"{"error":"no"}"#.utf8)))
        XCTAssertNil(NoticePhoto.fileExtension(of: Data()))
        XCTAssertNil(NoticePhoto.fileExtension(of: Data([0xFF, 0xD8])))
    }

    func testTheChoiceIsOffByDefault() {
        let store = NoticePhotoStore(MemoryStore())
        XCTAssertFalse(store.enabled)
        store.enabled = true
        XCTAssertTrue(store.enabled)
        store.enabled = false
        XCTAssertFalse(store.enabled)
    }

    func testAnOfflineCameraNamesItsCameraInTheNotice() {
        let event = ArmorEvent(id: 3, at: "2026-01-01T00:00:00Z", type: "camera", subject: "front-door", from: "online", to: "offline", targets: nil, mode: nil)
        let notices = AlarmPolicy.notices([event], armed: true, Translator(language: "es"))
        XCTAssertEqual(notices.first?.cameraId, "front-door")
        let odd = ArmorEvent(id: 4, at: "", type: "camera", subject: "../x", from: "online", to: "offline", targets: nil, mode: nil)
        XCTAssertNil(AlarmPolicy.notices([odd], armed: true, Translator(language: "es")).first?.cameraId, "an id that is not a camera id is not carried")
    }

    func testThePictureIsAskedWithAGetAndNothingInTheBody() async throws {
        let api = client()
        StubProtocol.routes["GET /api/v1/cameras/cam-1/snapshot"] = (200, "JPEGBYTES")
        let data = try await api.cameraStill(origin, cameraId: "cam-1", limit: NoticePhoto.maxBytes)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "JPEGBYTES")
        XCTAssertEqual(StubProtocol.seen.map { ($0.httpMethod ?? "") + " " + ($0.url?.path ?? "") }, ["GET /api/v1/cameras/cam-1/snapshot"])
        XCTAssertEqual(StubProtocol.bodies, [""])
    }

    func testAPictureLongerThanTheLimitIsRefused() async {
        let api = client()
        StubProtocol.routes["GET /api/v1/cameras/cam-1/snapshot"] = (200, String(repeating: "x", count: 200))
        do { _ = try await api.cameraStill(origin, cameraId: "cam-1", limit: 100); XCTFail("the picture should be refused") } catch { }
    }

    func testACameraWithoutASnapshotAddressOrAskedTooSoonGivesTheErrorOfTheServer() async {
        let api = client()
        StubProtocol.routes["GET /api/v1/cameras/cam-1/snapshot"] = (422, #"{"error":"this camera has no snapshot address"}"#)
        do { _ = try await api.cameraStill(origin, cameraId: "cam-1", limit: 1000); XCTFail("422 should fail") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 422) } catch { XCTFail("wrong error") }
        StubProtocol.routes["GET /api/v1/cameras/cam-1/snapshot"] = (429, #"{"error":"too soon"}"#)
        do { _ = try await api.cameraStill(origin, cameraId: "cam-1", limit: 1000); XCTFail("429 should fail") } catch let error as ArmorApiError { XCTAssertEqual(error.status, 429) } catch { XCTFail("wrong error") }
    }
}
