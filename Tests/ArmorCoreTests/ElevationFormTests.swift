import XCTest
@testable import ArmorCore

/// The sheet that asks for the proof of identity again: the button and the answer.
final class ElevationFormTests: XCTestCase {
    func testTheButtonNeedsAPasswordOrACode() {
        XCTAssertFalse(ElevationForm.canConfirm(password: "", code: ""))
        XCTAssertTrue(ElevationForm.canConfirm(password: "x", code: ""))
        XCTAssertTrue(ElevationForm.canConfirm(password: "", code: "123456"))
        XCTAssertTrue(ElevationForm.canConfirm(password: "x", code: "123456"))
    }

    func testACodeOfOnlySpacesIsNothing() {
        XCTAssertFalse(ElevationForm.canConfirm(password: "", code: "   "))
        XCTAssertFalse(ElevationForm.canConfirm(password: "", code: " \n\t"))
        XCTAssertTrue(ElevationForm.canConfirm(password: " ", code: ""))   // a password may be a space: it is sent as typed
    }

    func testTheCodeLosesItsSpacesAndThePasswordKeepsThem() {
        XCTAssertEqual(ElevationForm.cleanCode(" 123 456 "), "123456")
        XCTAssertEqual(ElevationForm.cleanCode("12\n34"), "1234")
        XCTAssertEqual(ElevationForm.cleanCode(""), "")
        let answer = ElevationForm.answer(password: " my pass ", code: "123 456")
        XCTAssertEqual(answer.password, " my pass ")
        XCTAssertEqual(answer.code, "123456")
    }
}
