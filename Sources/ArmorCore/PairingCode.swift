// ARMOR-IOS-CONTROL - the text of the pairing QR code: the id of a node and the address of the server, nothing else (the same text the shared Python library writes).
// The code holds no password, no token and no certificate; reading it refuses anything that could hold a secret.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct Pairing: Equatable, Sendable {
    public let nodeId: String
    public let server: String
    public init(nodeId: String, server: String) { self.nodeId = nodeId; self.server = server }
}

public enum PairingCode {
    public static let prefix = "armor-provision"
    public static let version = 1
    private static let maxText = 256

    public static func validNodeId(_ text: String) -> Bool {
        guard let first = text.unicodeScalars.first, text.unicodeScalars.count <= 64 else { return false }
        func lowerOrDigit(_ c: Unicode.Scalar) -> Bool { (c >= "a" && c <= "z") || (c >= "0" && c <= "9") }
        return lowerOrDigit(first) && text.unicodeScalars.allSatisfy { lowerOrDigit($0) || $0 == "_" || $0 == "-" }
    }

    /// The server address as the code holds it (no trailing slash), or nil when it is not an address without a secret in it.
    public static func cleanServer(_ server: String) -> String? {
        guard !server.isEmpty, server.count <= maxText else { return nil }
        if server.unicodeScalars.contains(where: { $0.value < 33 || $0.value == 127 }) { return nil }
        if server.contains("?") || server.contains("#") || server.contains("@") { return nil }
        guard let parts = URLComponents(string: server), let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        guard let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil else { return nil }
        guard parts.path.isEmpty || parts.path == "/" else { return nil }
        if let port = parts.port, !(1...65535).contains(port) { return nil }
        var clean = server
        while clean.hasSuffix("/") { clean.removeLast() }
        return clean
    }

    /// The text to turn into a QR code (keys in alphabetical order, compact), or nil when the id or the server are not valid.
    public static func build(nodeId: String, server: String) -> String? {
        guard validNodeId(nodeId), let clean = cleanServer(server) else { return nil }
        return "\(prefix):{\"node_id\":\"\(nodeId)\",\"server\":\"\(clean)\",\"v\":\(version)}"
    }

    /// Reads the text of a scanned code; nil when it is not exactly what `build` writes.
    public static func parse(_ text: String?) -> Pairing? {
        guard let text, text.hasPrefix(prefix + ":"), text.count <= 2 * maxText else { return nil }
        let body = String(text.dropFirst(prefix.count + 1))
        guard let data = body.data(using: .utf8), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        guard Set(object.keys) == ["v", "node_id", "server"] else { return nil }
        // A JSON true or false is also a number for NSNumber: it is refused by its text, and only a number equal to the version counts.
        guard body.range(of: #""v"\s*:\s*(true|false)"#, options: .regularExpression) == nil, let number = object["v"] as? NSNumber, number.intValue == version else { return nil }
        guard let id = object["node_id"] as? String, validNodeId(id), let server = object["server"] as? String, let clean = cleanServer(server) else { return nil }
        return Pairing(nodeId: id, server: clean)
    }
}
