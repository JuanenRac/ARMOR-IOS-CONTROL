// ARMOR-IOS-CONTROL - the pairing QR code as a picture: drawn from a text and read back from a still picture (the camera feeds the same reader frame by frame on a phone).
// Needs CoreImage, so it exists on iOS and macOS only; the text rules are in PairingCode.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public enum QrImage {
    /// The QR code of a text (black on white, scaled up without blurring), or nil when it cannot be drawn.
    public static func make(_ text: String, scale: CGFloat = 12) -> CGImage? {
        guard !text.isEmpty, scale >= 1 else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }

    /// The text of the first QR code found in a picture, or nil when there is none.
    public static func read(_ image: CGImage) -> String? {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: CIImage(cgImage: image)) ?? []
        for feature in features { if let code = feature as? CIQRCodeFeature, let text = code.messageString { return text } }
        return nil
    }
}
#endif
