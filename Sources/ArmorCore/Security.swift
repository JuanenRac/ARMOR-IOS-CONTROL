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

public enum SecurityParser {
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
