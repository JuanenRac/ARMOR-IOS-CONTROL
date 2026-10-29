import XCTest
@testable import ArmorCore

final class CameraLensesTests: XCTestCase {
    private func camera(_ id: String, layout: String? = nil) -> CameraView { CameraView(id: id, name: id, liveVideoAvailable: true, layout: layout) }

    func testACameraWithTwoLensesInOneStreamIsTwoWindowsOneAfterTheOther() {
        let windows = withLensWindows([camera("a"), camera("yard", layout: "split"), camera("b")], plain())
        XCTAssertEqual(windows.map(\.id), ["a", "yard.upper", "yard.lower", "b"])
        XCTAssertEqual(windows.map(\.lens), [.whole, .upper, .lower, .whole])
        XCTAssertEqual(windows[1].name, "yard · Objetivo superior")
        XCTAssertEqual(windows[2].name, "yard · Objetivo inferior")
    }

    func testTheNameSaysWhichLensInTheLanguageOfTheApp() {
        let t = Translator(language: "en", loader: { _ in ["Objetivo superior": "Upper lens", "Objetivo inferior": "Lower lens"] })
        XCTAssertEqual(withLensWindows([camera("yard", layout: "split")], t).map(\.name), ["yard · Upper lens", "yard · Lower lens"])
    }

    func testWhatTheButtonsAskOfTheServerIsAboutTheRealCamera() {
        let window = withLensWindows([camera("yard", layout: "split")], plain())[1]
        XCTAssertEqual(window.serverId, "yard")
        XCTAssertEqual(camera("yard").serverId, "yard")
        XCTAssertNil(window.layout)
    }

    func testEachWindowDrawsItsHalfOfThePicture() {
        XCTAssertEqual(LensCrop.of(.whole), LensCrop(y: 0, height: 1))
        XCTAssertEqual(LensCrop.of(.upper), LensCrop(y: 0, height: 0.5))
        XCTAssertEqual(LensCrop.of(.lower), LensCrop(y: 0.5, height: 0.5))
    }

    func testTheLayoutOfTheServerIsRead() {
        let cameras = CameraView.parse(["cameras": [["id": "yard", "name": "Patio", "layout": "split", "liveVideoAvailable": true], ["id": "door", "name": "Puerta", "layout": ""]]])
        XCTAssertEqual(cameras.map(\.layout), ["split", nil])
    }

    func testACameraWithoutLayoutIsOneWindow() {
        let one = [camera("a"), camera("b")]
        XCTAssertEqual(withLensWindows(one, plain()), one)
    }
}
