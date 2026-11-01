// ARMOR-IOS-CONTROL - what the server says about the security of the account: the second factor, the open sessions and how it sees this phone. The same reading as the Android app.
// The service passwords and the keys of a VPN are not here: setting up the way in from outside the house is done in Studio.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct SessionInfo: Equatable, Sendable, Identifiable {
    public let id: String
    public let createdMs: Int, lastSeenMs: Int
    public let remote: Bool
    public let ip: String, agent: String
    public let current: Bool
}

public struct TotpInfo: Equatable, Sendable {
    public let enabled: Bool
    public let recoveryLeft: Int
    public let policy: String
}

public struct RemoteInfo: Equatable, Sendable {
    public let ip: String
    public let remote: Bool
    public let cookieSecure: Bool
    public let trustProxy: String, policy: String
}

/// The key and the address of the second factor that is being set up, until the first code confirms it.
public struct TotpSetup: Equatable, Sendable {
    public let secret: String
    public let uri: String
}

public struct VpnPeer: Equatable, Sendable {
    public let name: String
    public let address: String
}

/// The configuration of a device of the VPN. It holds the PRIVATE KEY of the device, so it is shown once, never written to disk or to a log, and it prints as hidden.
public struct PeerConfig: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let name: String
    public let config: String
    public var description: String { "PeerConfig(name: \(name), config: <hidden>)" }
    public var debugDescription: String { description }
}

/// The way in from outside the house as the maintenance helper reports it (never a key or a token).
public struct RemoteSetup: Equatable, Sendable {
    public let vpnScript: Bool, vpnTool: Bool, vpnConfigured: Bool, vpnRunning: Bool
    public let vpnEndpoint: String, vpnSubnet: String, vpnPort: String
    public let peers: [VpnPeer]
    public let ddnsScript: Bool, ddnsConfigured: Bool
    public let ddnsProvider: String, ddnsName: String, ddnsLast: String
}

/// What the person allows for the configuration of a device of the VPN, from Resources/security.json. The defaults are the careful ones: no copying to the clipboard, and the window closes by itself.
public struct PeerConfigPolicy: Equatable, Sendable {
    public let allowCopy: Bool
    public let visibleSeconds: Double

    public static let defaults = PeerConfigPolicy(allowCopy: false, visibleSeconds: 120)

    public static func parse(_ json: JSON) -> PeerConfigPolicy {
        let seconds = json.double("peer_config_visible_seconds") ?? defaults.visibleSeconds
        return PeerConfigPolicy(allowCopy: json.has("allow_copy_peer_config") ? json.bool("allow_copy_peer_config") : defaults.allowCopy, visibleSeconds: min(600, max(10, seconds)))
    }

    public static func bundled() -> PeerConfigPolicy {
        guard let url = Bundle.module.url(forResource: "security", withExtension: "json"), let data = try? Data(contentsOf: url), let json = try? Json.object(data) else { return defaults }
        return parse(json)
    }
}

public enum SecurityParser {
    public static func remoteSetup(_ root: JSON) -> RemoteSetup {
        let vpn = root.object("wireguard") ?? [:], ddns = root.object("ddns") ?? [:]
        let peers = vpn.objects("peers").compactMap { item -> VpnPeer? in
            let name = item.str("name")
            return name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : VpnPeer(name: name, address: item.str("address"))
        }
        return RemoteSetup(vpnScript: vpn.bool("script"), vpnTool: vpn.bool("tool"), vpnConfigured: vpn.bool("configured"), vpnRunning: vpn.bool("running"), vpnEndpoint: vpn.str("endpoint"),
                           vpnSubnet: vpn.str("subnet"), vpnPort: vpn.str("port"), peers: peers, ddnsScript: ddns.bool("script"), ddnsConfigured: ddns.bool("configured"), ddnsProvider: ddns.str("provider"),
                           ddnsName: ddns.str("name"), ddnsLast: ddns.str("last_address"))
    }

    public static func peerConfig(_ root: JSON) -> PeerConfig { PeerConfig(name: root.str("name"), config: root.str("config")) }

    /// A name of a device as the helper takes it: letters, digits, - and _, up to 32.
    public static func cleanPeerName(_ text: String) -> String { String(text.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }.prefix(32)) }

    /// The UDP port to forward on the router, from the endpoint ("casa.duckdns.org:51820") or, failing that, the port of the setup.
    public static func forwardedPort(_ setup: RemoteSetup) -> String {
        if let colon = setup.vpnEndpoint.lastIndex(of: ":") {
            let port = String(setup.vpnEndpoint[setup.vpnEndpoint.index(after: colon)...])
            if !port.isEmpty { return port }
        }
        return setup.vpnPort.isEmpty ? "51820" : setup.vpnPort
    }

    public static func sessions(_ root: JSON) -> [SessionInfo] {
        root.objects("sessions").compactMap { item in
            let id = item.str("id")
            if id.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
            return SessionInfo(id: id, createdMs: item.int("created"), lastSeenMs: item.int("last_seen"), remote: item.str("origin") == "remote", ip: item.str("ip"), agent: item.str("agent"), current: item.bool("current"))
        }
    }

    public static func totp(_ root: JSON) -> TotpInfo { TotpInfo(enabled: root.bool("enabled"), recoveryLeft: root.int("recovery_left"), policy: root.str("policy", "off")) }

    public static func remote(_ root: JSON) -> RemoteInfo {
        var proxy = "-"
        if root.has("trust_proxy") {
            let value = root["trust_proxy"]
            if let text = value as? String { proxy = text } else if let flag = value as? Bool { proxy = flag ? "true" : "-" } else if let number = value as? Int { proxy = String(number) }
        }
        return RemoteInfo(ip: root.str("ip"), remote: root.str("origin") == "remote", cookieSecure: root.bool("cookie_secure"), trustProxy: proxy, policy: root.str("totp_policy", "off"))
    }

    public static func setup(_ root: JSON) -> TotpSetup { TotpSetup(secret: root.str("secret"), uri: root.str("uri")) }

    /// The strings of a list of recovery codes.
    public static func codes(_ root: JSON) -> [String] {
        ((root["recovery_codes"] as? [Any]) ?? []).compactMap { $0 as? String }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// A key shown in groups of four to be typed by hand: "ABCD EFGH IJ".
    public static func grouped(_ secret: String) -> String {
        var out: [String] = []
        var rest = Substring(secret)
        while !rest.isEmpty { out.append(String(rest.prefix(4))); rest = rest.dropFirst(4) }
        return out.joined(separator: " ")
    }
}

public enum SecurityText {
    public static func ddnsProviderName(_ id: String, _ t: Translator) -> String {
        switch id {
        case "duckdns": return t.tr("DuckDNS (gratuito)")
        case "cloudflare": return t.tr("Cloudflare")
        default: return t.tr("Otro (una dirección a la que llamar)")
        }
    }

    /// The phrase for a code the server gave.
    public static func error(_ code: String, _ t: Translator) -> String {
        switch code {
        case "bad_proof": return t.tr("Eso no es correcto.")
        case "bad_code": return t.tr("Ese código no es correcto.")
        case "totp_locked": return t.tr("Demasiados códigos erróneos: espera un poco y vuelve a intentarlo.")
        case "challenge_expired": return t.tr("El acceso ha tardado demasiado: empieza de nuevo.")
        case "remote_policy": return t.tr("Esto solo se puede hacer desde casa o con la VPN.")
        case "already_enabled": return t.tr("El segundo factor ya está activado: desactívalo primero.")
        case "totp_setup_required": return t.tr("Este servidor pide el segundo factor desde fuera de casa. Configúralo antes desde dentro de casa (Configuración > Seguridad).")
        default: return t.tr("No ha funcionado. No se ha cambiado nada.")
        }
    }

    public static func errorText(_ error: Error, _ t: Translator) -> String {
        if let api = error as? ArmorApiError { return Self.error(api.code, t) }
        return Self.error("", t)
    }
}
