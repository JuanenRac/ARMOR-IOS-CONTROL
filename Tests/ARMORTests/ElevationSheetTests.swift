// ARMOR-IOS-CONTROL - tests of the app itself (they run inside the app on a simulator): the proof-of-identity sheet and its answer to the model.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import UIKit
import XCTest
import ArmorCore
@testable import ARMOR

@MainActor
final class ElevationSheetTests: XCTestCase {
    func testAnsweringGivesThePasswordAndClosesTheSheet() async {
        let model = AppModel()
        let answer: (password: String, code: String)? = await withCheckedContinuation { continuation in
            let request = AppModel.ElevationRequest(continuation)
            model.pendingElevation = request
            XCTAssertNotNil(model.pendingElevation)
            model.answerElevation(request, password: "secret", code: "")
        }
        XCTAssertEqual(answer?.password, "secret")
        XCTAssertNil(model.pendingElevation)
    }

    func testCancellingGivesNothingAndClosesTheSheet() async {
        let model = AppModel()
        let answer: (password: String, code: String)? = await withCheckedContinuation { continuation in
            let request = AppModel.ElevationRequest(continuation)
            model.pendingElevation = request
            model.declineElevation(request)
        }
        XCTAssertNil(answer)
        XCTAssertNil(model.pendingElevation)
    }

    func testTheSheetDrawsItself() async {
        let model = AppModel()
        let _: (password: String, code: String)? = await withCheckedContinuation { continuation in
            let request = AppModel.ElevationRequest(continuation)
            let host = UIHostingController(rootView: ElevationSheet(request: request).environmentObject(model))
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
            host.view.layoutIfNeeded()
            XCTAssertGreaterThan(host.view.bounds.width, 0)
            model.declineElevation(request)
        }
    }
}
