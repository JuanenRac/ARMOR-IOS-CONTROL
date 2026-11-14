// ARMOR-IOS-CONTROL - the action "Open camera" of a notice: what travels in the notice, which ids are acted on and what the screen of the cameras does with the request.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import XCTest
@testable import ArmorCore

final class OpenCameraTests: XCTestCase {
    private let door = CameraView(id: "door", name: "Door", liveVideoAvailable: true)
    private let garden = CameraView(id: "garden", name: "Garden", liveVideoAvailable: true, layout: "split")

    func testAnIdIsActedOnOnlyIfItLooksLikeACameraId() {
        for good in ["door", "cam-1", "cam_2", "cam.3", "A1"] { XCTAssertTrue(OpenCamera.valid(good), good) }
        for bad in ["", "a b", "../x", "x/y", String(repeating: "x", count: 81), "a;b", "a\u{0}b"] { XCTAssertFalse(OpenCamera.valid(bad), bad) }
    }

    func testTheCameraOfTheNoticeIsOpenedWhenTheListHasIt() {
        XCTAssertEqual(OpenCamera.resolve(requested: "door", cameras: [door, garden], loaded: true), .open(door))
        XCTAssertEqual(OpenCamera.resolve(requested: "door", cameras: [door], loaded: false), .open(door))
    }

    func testACameraWithTwoLensesOpensItsFirstWindow() {
        let windows = withLensWindows([door, garden], plain())
        guard case let .open(window) = OpenCamera.resolve(requested: "garden", cameras: windows, loaded: true) else { return XCTFail("expected a window") }
        XCTAssertEqual(window.serverId, "garden")
        XCTAssertEqual(window.lens, .upper)
    }

    func testTheRequestWaitsForTheListAndIsDroppedWhenTheCameraIsNotThere() {
        XCTAssertEqual(OpenCamera.resolve(requested: "door", cameras: [], loaded: false), .wait)
        XCTAssertEqual(OpenCamera.resolve(requested: "door", cameras: [garden], loaded: true), .drop)
        XCTAssertEqual(OpenCamera.resolve(requested: "../x", cameras: [door], loaded: true), .drop)
        XCTAssertEqual(OpenCamera.resolve(requested: "../x", cameras: [], loaded: false), .drop)
    }

    func testTheNoticeCarriesTheActionsItsFactsAllow() {
        XCTAssertEqual(NoticeActions.category(alarmId: nil, cameraId: "door"), NoticeActions.openCameraCategoryId)
        XCTAssertEqual(NoticeActions.category(alarmId: "alm-1", cameraId: nil), NoticeActions.categoryId)
        XCTAssertEqual(NoticeActions.category(alarmId: "alm-1", cameraId: "door"), NoticeActions.ackAndOpenCategoryId)
        XCTAssertNil(NoticeActions.category(alarmId: nil, cameraId: "../x"))
        XCTAssertNil(NoticeActions.category(alarmId: nil, cameraId: nil))
        XCTAssertEqual(NoticeActions.userInfo(alarmId: "alm-1", cameraId: "door"), ["alarm_id": "alm-1", "camera_id": "door"])
        XCTAssertEqual(NoticeActions.userInfo(alarmId: nil, cameraId: "door"), ["camera_id": "door"])
        XCTAssertEqual(NoticeActions.userInfo(alarmId: "a b", cameraId: "x y"), [:])
    }

    func testTheCameraIsReadBackOnlyIfValid() {
        XCTAssertEqual(NoticeActions.cameraId(from: ["camera_id": "door"]), "door")
        XCTAssertNil(NoticeActions.cameraId(from: ["camera_id": "a b"]))
        XCTAssertNil(NoticeActions.cameraId(from: ["camera_id": 5]))
        XCTAssertNil(NoticeActions.cameraId(from: [:]))
    }

    func testTheNamesOfTheActionsAreDistinct() {
        let names = [NoticeActions.categoryId, NoticeActions.openCameraCategoryId, NoticeActions.ackAndOpenCategoryId, NoticeActions.acknowledgeActionId, NoticeActions.openCameraActionId]
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testTheLabelOfTheActionIsInEveryLanguage() {
        for language in ["en", "es", "de", "fr", "it", "ja", "zh", "pt"] {
            let translator = Translator(language: language)
            XCTAssertFalse(translator.tr("Abrir cámara").isEmpty, language)
            if language != "es" { XCTAssertNotEqual(translator.tr("Abrir cámara"), "Abrir cámara", "\(language) is not translated") }
        }
    }
}
