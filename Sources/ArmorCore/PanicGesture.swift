// ARMOR-IOS-CONTROL - the hidden panic gesture: a long press on the shield of the status card, or five quick touches on it. It asks the server for the silent duress alarm; nothing shows on the phone.
// The same numbers as the Android app (PanicGesture.kt), which has the mark of the app in its top bar; the phone has no such mark, so the gesture is on the shield of the status card.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The numbers of the gesture, in one place.
public enum PanicGesture {
    /// Quick touches that make the gesture.
    public static let taps = 5
    /// All of them must fall inside this time (milliseconds).
    public static let windowMs: Int64 = 3_000
    /// Tries to reach the server when the connection fails (the first one included), and the wait between them (milliseconds).
    public static let tries = 2
    public static let retryMs: UInt64 = 2_000
}

/// Counts quick touches: `touch` says true on the `taps`-th one inside `windowMs`, and starts counting again after it.
public struct TapCounter: Sendable {
    private var times: [Int64] = []
    private let taps: Int
    private let windowMs: Int64

    public init(taps: Int = PanicGesture.taps, windowMs: Int64 = PanicGesture.windowMs) { self.taps = taps; self.windowMs = windowMs }

    public mutating func touch(atMs: Int64) -> Bool {
        times.append(atMs)
        while let first = times.first, atMs - first > windowMs { times.removeFirst() }
        if times.count < taps { return false }
        times.removeAll()
        return true
    }
}
