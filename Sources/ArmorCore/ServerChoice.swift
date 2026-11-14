// ARMOR-IOS-CONTROL - the servers whose session is kept on the phone, as the sign-in offers them: how one is written on a button and how it fills the address fields.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum ServerChoice {
    /// How a server reads on its button: the name or address with its port, without the scheme (a server over https has a lock mark).
    public static func label(_ origin: String) -> String {
        guard let url = URL(string: origin), let host = url.host else { return origin }
        let name = url.port.map { "\(host):\($0)" } ?? host
        return url.scheme == "https" ? "\u{1F512} \(name)" : name
    }

    /// The saved installation that names this server alone (no address for away from home: that one belonged to the server before), or nil when the origin is not one the app accepts.
    public static func installation(for origin: String) -> SavedInstallation? {
        guard let endpoint = ServerEndpoint.parse(origin), let url = URL(string: endpoint.origin), let host = url.host else { return nil }
        let secure = url.scheme == "https"
        let port = url.port.flatMap { (1...65535).contains($0) ? $0 : nil } ?? (secure ? 443 : 8080)
        return SavedInstallation(homeHost: (secure ? "https://" : "") + host, homePort: String(port), awayHost: "", awayPort: "443")
    }

    /// The servers to offer: those with a session kept that the app still accepts, each once, with the one in use first.
    public static func offered(_ kept: [String], inUse: String) -> [String] {
        var seen = Set<String>()
        let valid = kept.compactMap { ServerEndpoint.parse($0)?.origin }.filter { seen.insert($0).inserted }
        return valid.contains(inUse) ? [inUse] + valid.filter { $0 != inUse } : valid
    }
}
