// ARMOR-IOS-CONTROL - the address of a field node's own configuration panel, checked. The panel is a web page the node itself serves on the local network (or the server relays it to a signed-in
// session, so a node can be configured from outside the house); the app shows that real page, so what the node offers is what the phone offers. The same rules as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The address of a node's panel on the local network: an IPv4 address of a private range, with its port when it is not the usual one.
public enum NodeAddress {
    /// A dotted decimal address with no leading zero ("010" is not an address, and a program may read it as octal).
    private static func octets(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var values: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 3, part.allSatisfy({ $0.isASCII && $0.isNumber }), part == "0" || !part.hasPrefix("0"), let value = Int(part), value <= 255 else { return nil }
            values.append(value)
        }
        return values
    }

    /// `http://address[:port]/`, or nil when the text is not an address of the local network (a name, a public address, anything with a path or a login in it).
    public static func parse(_ text: String) -> String? {
        var typed = text.trimmingCharacters(in: .whitespaces)
        if typed.lowercased().hasPrefix("http://") { typed = String(typed.dropFirst(7)) }
        while typed.hasSuffix("/") { typed.removeLast() }
        let pieces = typed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = pieces.first else { return nil }
        let host = String(first)
        var port = 80
        if pieces.count == 2 {
            guard let given = Int(pieces[1]), pieces[1].allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            port = given
        }
        guard let o = octets(host), o[0] == 10 || (o[0] == 192 && o[1] == 168) || (o[0] == 172 && (16...31).contains(o[1])), (1...65535).contains(port) else { return nil }
        return "http://\(host)\(port == 80 ? "" : ":\(port)")/"
    }

    /// The addresses to keep as the recent ones: the new one first, no repeats, at most five.
    public static func remember(_ address: String, among recent: [String]) -> [String] { Array(([address] + recent.filter { $0 != address }).prefix(5)) }
}

/// The panel of a node through the server (`/api/v1/nodes/<id>/panel/`): the server relays the node's own page to a signed-in session. The address is the server's, with the session the app already has.
public enum NodeServerPanel {
    /// `<origin>/api/v1/nodes/<id>/panel/`, or nil when the origin is not a valid server address or the id is not the plain name of a node.
    public static func address(origin: String, nodeId: String) -> String? {
        guard let endpoint = ServerEndpoint.parse(origin), !nodeId.isEmpty, nodeId.count <= 64,
              nodeId.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-") }) else { return nil }
        return "\(endpoint.origin)/api/v1/nodes/\(nodeId)/panel/"
    }

    /// True when `address` is a panel through the server of `origin` (so the page needs the server's session cookie).
    public static func isViaServer(_ address: String, origin: String) -> Bool {
        var base = origin
        while base.hasSuffix("/") { base.removeLast() }
        return !base.isEmpty && address.hasPrefix(base + "/api/v1/nodes/")
    }

    /// True when a page address belongs to the node of the panel: same host, so a link to anywhere else is not followed.
    public static func sameHost(_ address: String, as panel: String) -> Bool {
        guard let host = URL(string: address)?.host, let own = URL(string: panel)?.host else { return false }
        return host == own
    }
}
