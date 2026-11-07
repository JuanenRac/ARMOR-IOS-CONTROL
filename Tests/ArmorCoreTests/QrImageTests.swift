import XCTest
@testable import ArmorCore

#if canImport(CoreImage)
import CoreGraphics

/// The pairing QR code as a still picture: drawn and read back with no camera.
final class QrImageTests: XCTestCase {
    private let node = PairingCode.build(nodeId: "radar-1", server: "https://armor.local:8443")

    func testThePairingCodeSurvivesBeingDrawnAndRead() throws {
        let text = try XCTUnwrap(node)
        let picture = try XCTUnwrap(QrImage.make(text))
        XCTAssertGreaterThan(picture.width, 100)
        XCTAssertEqual(picture.width, picture.height)
        let read = try XCTUnwrap(QrImage.read(picture))
        XCTAssertEqual(read, text)
        XCTAssertEqual(PairingCode.parse(read), Pairing(nodeId: "radar-1", server: "https://armor.local:8443"))
    }

    func testSeveralScalesReadTheSame() throws {
        let text = try XCTUnwrap(node)
        for scale: CGFloat in [6, 12, 20] { XCTAssertEqual(QrImage.read(try XCTUnwrap(QrImage.make(text, scale: scale))), text, "scale \(scale)") }
    }

    func testNothingToDrawGivesNoPicture() {
        XCTAssertNil(QrImage.make(""))
        XCTAssertNil(QrImage.make("x", scale: 0))
    }

    func testAPictureWithoutACodeReadsNothing() throws {
        let space = CGColorSpaceCreateDeviceGray()
        let context = try XCTUnwrap(CGContext(data: nil, width: 120, height: 120, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        XCTAssertNil(QrImage.read(try XCTUnwrap(context.makeImage())))
    }

    func testACodeThatIsNotAPairingCodeIsReadButRefusedByTheRules() throws {
        let picture = try XCTUnwrap(QrImage.make("https://example.com/?token=secret"))
        let read = QrImage.read(picture)
        XCTAssertEqual(read, "https://example.com/?token=secret")
        XCTAssertNil(PairingCode.parse(read))
    }
}
#endif
