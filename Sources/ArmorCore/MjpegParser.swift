// ARMOR-IOS-CONTROL - cuts a live MJPEG stream (the one the server relays from a camera) into pictures, and says how long to wait before asking for the stream again.
// A picture starts at the JPEG marker FF D8 and ends at FF D9; whatever lies between pictures (the multipart boundaries and headers) is dropped. A picture that grows beyond the limit is thrown away,
// so a stream that is not a camera cannot fill the memory of the phone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct MjpegFrameParser {
    public static let maxFrameBytes = 4 * 1024 * 1024
    private var buffer = Data()

    public init() {}

    /// Feeds a piece of the stream; returns the pictures completed by it, in order.
    public mutating func feed(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var frames: [Data] = []
        while true {
            guard let start = Self.find([0xFF, 0xD8], in: buffer, from: 0) else {
                // no start in sight: keep only the last byte, which may be the first half of a marker
                buffer = buffer.suffix(1)
                break
            }
            if start > 0 { buffer.removeSubrange(buffer.startIndex..<buffer.startIndex + start) }
            guard let end = Self.find([0xFF, 0xD9], in: buffer, from: 2) else {
                if buffer.count > Self.maxFrameBytes { buffer.removeAll(keepingCapacity: false) }
                break
            }
            let frameEnd = end + 2
            if frameEnd <= Self.maxFrameBytes { frames.append(Data(buffer.prefix(frameEnd))) }
            buffer.removeSubrange(buffer.startIndex..<buffer.startIndex + frameEnd)
        }
        return frames
    }

    public mutating func reset() { buffer.removeAll(keepingCapacity: false) }

    private static func find(_ marker: [UInt8], in data: Data, from: Int) -> Int? {
        guard data.count >= from + 2 else { return nil }
        var index = from
        let base = data.startIndex
        while index + 1 < data.count {
            if data[base + index] == marker[0], data[base + index + 1] == marker[1] { return index }
            index += 1
        }
        return nil
    }
}

/// How long to wait before asking for a stream again: 1 s, doubling to 30 s, back to 1 s once a picture arrived.
public struct Backoff: Equatable, Sendable {
    public private(set) var attempts = 0
    public init() {}
    public var delaySeconds: Double { min(30, pow(2, Double(attempts))) }
    public mutating func failed() { attempts = min(attempts + 1, 10) }
    public mutating func succeeded() { attempts = 0 }
}

/// How many cameras are shown at once in the grid, so the phone does not decode what nobody sees: only the tiles on screen run, and a tile that goes out of sight stops its stream.
public enum CameraGrid {
    public static let maxLive = 6

    /// The ids that should be streaming: the visible ones, at most `maxLive`, in the order shown.
    public static func live(visible: [String]) -> [String] { Array(visible.prefix(maxLive)) }
}
