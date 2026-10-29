// ARMOR-IOS-CONTROL - the windows of a camera that has two lenses in one stream.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// Which part of the picture a window shows: all of it, or the upper or the lower lens of a camera that has two lenses in one stream.
public enum LensHalf: String, Equatable, Sendable { case whole, upper, lower }

/// The rectangle of the picture a window draws, as fractions of its height: `y` is where it starts and `height` how much of it is shown.
public struct LensCrop: Equatable, Sendable {
    public let y: Double, height: Double
    public static func of(_ half: LensHalf) -> LensCrop {
        switch half {
        case .whole: return LensCrop(y: 0, height: 1)
        case .upper: return LensCrop(y: 0, height: 0.5)
        case .lower: return LensCrop(y: 0.5, height: 0.5)
        }
    }
}

/// A camera whose stream carries two lenses, one above the other, appears as two windows of the list, one after the other: each shows its half of the picture and the name says which lens it
/// is, while what the buttons do (snapshot, move) is done to the real camera behind them (`CameraView.serverId`).
public func withLensWindows(_ cameras: [CameraView], _ t: Translator) -> [CameraView] {
    cameras.flatMap { camera -> [CameraView] in
        guard camera.layout == "split" else { return [camera] }
        return [(LensHalf.upper, t.tr("Objetivo superior")), (LensHalf.lower, t.tr("Objetivo inferior"))].map { half, label in
            CameraView(id: "\(camera.id).\(half.rawValue)", name: "\(camera.name) · \(label)", liveVideoAvailable: camera.liveVideoAvailable, layout: nil, lens: half, sourceId: camera.id)
        }
    }
}
