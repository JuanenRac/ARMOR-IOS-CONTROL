// ARMOR-IOS-CONTROL - safe parsing of the address of the server, and the two addresses of an installation (at home and away).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct ServerEndpoint: Equatable, Sendable {
    public let origin: String

    /// Builds the origin typed by an operator: a host (with or without http:// or https://) and a port.
    public static func fromHostAndPort(_ hostInput: String, _ portInput: String) -> ServerEndpoint? {
        let source = hostInput.trimmingCharacters(in: .whitespaces)
        let scheme = source.lowercased().hasPrefix("https://") ? "https" : "http"
        let host = hostOf(source)
        guard let port = Int(portInput.trimmingCharacters(in: .whitespaces)), (1...65535).contains(port) else { return nil }
        return parse("\(scheme)://\(host):\(port)")
    }

    private static func hostOf(_ source: String) -> String {
        var text = source
        for prefix in ["http://", "https://"] where text.lowercased().hasPrefix(prefix) { text = String(text.dropFirst(prefix.count)); break }
        text = String(text.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        return String(text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    /// True when what was typed names a place outside the home network without asking for a secure connection: the app refuses to send the password that way.
    public static func needsSecureConnection(_ hostInput: String) -> Bool {
        let source = hostInput.trimmingCharacters(in: .whitespaces)
        if source.isEmpty || source.lowercased().hasPrefix("https://") { return false }
        let host = hostOf(source)
        return !host.isEmpty && !isPrivateLanHost(host)
    }

    /// True when what was typed is a public IPv4 address (not a name, not an address of the house): it stops working the day the operator changes it.
    public static func usesPublicIpAddress(_ hostInput: String) -> Bool {
        let source = hostInput.trimmingCharacters(in: .whitespaces)
        if source.isEmpty { return false }
        let host = hostOf(source)
        return octets(host) != nil && !isPrivateLanHost(host)
    }

    /// The four numbers of an IPv4 literal; nil for anything else and for a number with a leading zero (some resolvers read "010.0.0.1" as octal).
    static func octets(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 3, part.allSatisfy({ $0 >= "0" && $0 <= "9" }), part == "0" || !part.hasPrefix("0"), let n = Int(part), n <= 255 else { return nil }
            numbers.append(n)
        }
        return numbers
    }

    /// Plain HTTP is allowed only to a private-LAN or loopback IPv4 literal (or "localhost"): a name such as "10.attacker.example" merely starts like a private address.
    public static func isPrivateLanHost(_ host: String) -> Bool {
        if host == "localhost" { return true }
        guard let o = octets(host) else { return false }
        return o[0] == 127 || o[0] == 10 || (o[0] == 192 && o[1] == 168) || (o[0] == 172 && (16...31).contains(o[1]))
    }

    public static func parse(_ value: String) -> ServerEndpoint? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespaces)), let scheme = url.scheme, let host = url.host, !host.isEmpty else { return nil }
        let accepted = scheme == "https" || (scheme == "http" && isPrivateLanHost(host))
        if !accepted || url.user != nil || url.password != nil || url.query != nil || url.fragment != nil { return nil }
        if !(url.path.isEmpty || url.path == "/") { return nil }
        return ServerEndpoint(origin: "\(scheme)://\(host)" + (url.port.map { ":\($0)" } ?? ""))
    }
}

/// Where the phone is, as far as the choice of address goes.
public enum NetworkPlace: String, Sendable { case home, away, unknown }

/// The two addresses of one installation: the private one used at home and the one used away (a name that follows the house, or the address of the VPN). Either may be empty.
public struct DualEndpoint: Equatable, Sendable {
    public var home: ServerEndpoint?
    public var away: ServerEndpoint?
    public init(home: ServerEndpoint?, away: ServerEndpoint?) { self.home = home; self.away = away }

    /// The address to use now: at home the private one, away the remote one; with only one address, that one; when the place is not known yet, the private one if there is one.
    public func chosen(for place: NetworkPlace) -> ServerEndpoint? {
        switch place {
        case .home: return home ?? away
        case .away: return away ?? home
        case .unknown: return home ?? away
        }
    }

    /// The other address, tried when the chosen one does not answer.
    public func alternative(to used: ServerEndpoint) -> ServerEndpoint? {
        if used == home, let away, away != used { return away }
        if used == away, let home, home != used { return home }
        return nil
    }
}
