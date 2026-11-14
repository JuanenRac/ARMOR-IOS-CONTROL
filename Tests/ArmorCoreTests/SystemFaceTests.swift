// ARMOR-IOS-CONTROL - what the widget says about the system: armed or disarmed only for the two words of the server, and its words in the eight languages.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import XCTest
@testable import ArmorCore

final class SystemFaceTests: XCTestCase {
    func testTheFaceIsArmedOrDisarmedOnlyForTheTwoWordsOfTheServer() {
        XCTAssertEqual(SystemFace.of("armed"), .armed)
        XCTAssertEqual(SystemFace.of("disarmed"), .disarmed)
        XCTAssertEqual(SystemFace.of(nil), .unknown)
        XCTAssertEqual(SystemFace.of(""), .unknown)
        XCTAssertEqual(SystemFace.of("ARMED"), .unknown)
        XCTAssertEqual(SystemFace.of("night"), .unknown)
    }

    func testTheThreeFacesHaveTheirWordsInEveryLanguage() {
        for language in ["en", "es", "de", "fr", "it", "ja", "zh", "pt"] {
            let translator = Translator(language: language)
            for face in SystemFace.allCases {
                XCTAssertFalse(face.text(translator).isEmpty, "\(language) \(face.phrase)")
                if language != "es" { XCTAssertNotEqual(face.text(translator), face.phrase, "\(language) \(face.phrase) is not translated") }
            }
        }
    }

    func testTheWidgetFileOnlyShowsAndOpensTheApp() throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/widget/ArmorStatusWidget.swift")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("the widget source is not in this copy") }
        let source = try String(contentsOf: path, encoding: .utf8)
        for word in ["setMode", "sendAlarmCommand", "acknowledge", "setArmingMode", "panicGesture"] { XCTAssertFalse(source.contains(word), "the widget must not call \(word)") }
    }
}
