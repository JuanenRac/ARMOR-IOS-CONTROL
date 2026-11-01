// ARMOR-IOS-CONTROL - the longest answer the app takes from a server.
// What comes back from a connection is refused past a limit: a server (or whatever stands in its place) that sends far more than any real answer is a failed request, the same as a lost connection,
// and never a big block that the parsers then walk through. (The session also has a time limit for the whole answer, so nothing keeps arriving for long.)
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum ResponseLimit {
    /// An answer of the API (JSON): the biggest the server makes is far under this.
    public static let json = 8 * 1024 * 1024
    /// A picture (the heat map as a PNG): the same limit the server puts on what it hands over.
    public static let picture = 16_000_000

    /// Passes `data` on when it is within `limit`; otherwise the request failed.
    @discardableResult
    public static func check(_ data: Data, limit: Int) throws -> Data {
        if data.count > limit { throw ArmorApiError(message: "The answer is longer than \(limit) bytes", status: nil) }
        return data
    }
}
