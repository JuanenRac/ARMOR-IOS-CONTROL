// ARMOR-IOS-CONTROL - the QR code of the app as a still picture (no camera): drawn by the app and read back.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import UIKit
import XCTest
import ArmorCore
@testable import ARMOR

final class PairingQrTests: XCTestCase {
    func testTheAppDrawsAReadablePairingCode() throws {
        let text = try XCTUnwrap(PairingCode.build(nodeId: "alarm-1", server: "https://armor.local"))
        let picture = try XCTUnwrap(PairingQr.image(text)?.cgImage)
        XCTAssertEqual(QrImage.read(picture), text)
    }

    func testAnEmptyTextGivesNoPicture() {
        XCTAssertNil(PairingQr.image(""))
    }
}
