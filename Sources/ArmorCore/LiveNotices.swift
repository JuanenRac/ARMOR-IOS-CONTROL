// ARMOR-IOS-CONTROL - the small live notices of the server (WebSocket /api/v1/events), the rules without the socket so they are tested without a phone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// Besides the whole state, the server tells the consoles that something they may be showing changed: `{"type":"alarm","id":"alm-00001","version":12}` and nothing more.
public struct LiveNotice: Equatable, Sendable {
    public let type: String
    public let id: String
    public let version: Int64
    public init(type: String, id: String, version: Int64) { self.type = type; self.id = id; self.version = version }
}

public enum LiveNotices {
    public static let types = ["alarm", "device", "solar", "network", "design"]
    static let maxMessage = 1024
    static let maxId = 64
    public static let firstRetrySeconds = 2.0
    public static let lastRetrySeconds = 60.0
    /// One notice within this long means the notices are flowing, and the app asks far less often.
    public static let freshSeconds = 60.0
    public static let slowPollSeconds = 30.0

    /// The notice a message carries, or nil when it is not one (the state, a kind this app does not know, anything malformed).
    public static func parse(_ text: String?) -> LiveNotice? {
        guard let text, text.count <= maxMessage, let data = text.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = object["type"] as? String, types.contains(type),
              let id = object["id"] as? String, id.count <= maxId,
              let version = object["version"] as? NSNumber else { return nil }
        let value = version.doubleValue
        guard value.isFinite else { return nil }
        return LiveNotice(type: type, id: id, version: version.int64Value)
    }

    /// The address of the channel of a server: ws for http and wss for https; nil when it is not an address.
    public static func url(_ origin: String) -> URL? {
        var trimmed = origin
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.hasPrefix("https://") { return URL(string: "wss://" + trimmed.dropFirst("https://".count) + "/api/v1/events") }
        if trimmed.hasPrefix("http://") { return URL(string: "ws://" + trimmed.dropFirst("http://".count) + "/api/v1/events") }
        return nil
    }

    /// The wait before the next try after `failures` failed ones: two seconds, doubling, one minute at most.
    public static func retryDelay(_ failures: Int) -> Double {
        let step = min(max(failures - 1, 0), 10)
        return min(lastRetrySeconds, firstRetrySeconds * Double(1 << step))
    }

    /// The pause between two passes of the polling: the usual one, or thirty seconds while a notice arrived within the last minute.
    public static func pollDelay(base: Double, lastNotice: Date?, now: Date) -> Double {
        guard let lastNotice, now.timeIntervalSince(lastNotice) >= 0, now.timeIntervalSince(lastNotice) <= freshSeconds else { return base }
        return max(base, slowPollSeconds)
    }
}
