// ARMOR-IOS-CONTROL - a battery stack whose readings the server is refusing, from GET /api/v1/system/ingest (the same rule as Studio and the Android app): the topic has an error
// newer than the last reading the server took, and the message was a battery's.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct RefusedBattery: Equatable {
    public let name: String
    public let reason: String

    public init(name: String, reason: String) {
        self.name = name
        self.reason = reason
    }

    public static func fromIngest(_ body: JSON) -> [RefusedBattery] {
        guard let topics = body["topics"] as? [Any] else { return [] }
        return topics.compactMap { entry in
            guard let item = entry as? JSON else { return nil }
            let parts = item.str("topic").split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 5, parts[0] == "armor", parts[1] == "solar", !parts[2].isEmpty, !parts[3].isEmpty, parts[4] == "state" else { return nil }
            let failedAt = item.str("last_error_at")
            let takenAt = item.str("last_ok_at")
            guard !failedAt.isEmpty, takenAt.isEmpty || takenAt < failedAt else { return nil }
            guard item.str("last_payload").range(of: "\"kind\"\\s*:\\s*\"battery\"", options: .regularExpression) != nil else { return nil }
            return RefusedBattery(name: "\(parts[2]) / \(parts[3])", reason: String(item.str("last_error").prefix(200)))
        }
    }
}
