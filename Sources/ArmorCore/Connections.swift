// ARMOR-IOS-CONTROL - the devices and apps that connect to the server, as the server's history lists them. Reading only. The same as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// One client the server has seen: Studio in a browser, an app, the panel of a node, the voice service or anything else. `kind` is "studio", "android", "node", "voice" or "other".
/// `ip` and `agent` come only when the signed-in user is an administrator; no password, token or cookie is ever part of it.
public struct ConnectionClient: Equatable, Sendable, Identifiable {
    public let id: String, kind: String
    public let user: String?, label: String?, appVersion: String?
    public let firstSeen: String, lastSeen: String
    public let activeSessions: Int, loginsOk: Int, loginsFailed: Int
    public let ip: String?, agent: String?
}

public enum ConnectionsParser {
    private static let kinds: Set<String> = ["studio", "android", "node", "voice", "other"]

    private static func text(_ json: JSON, _ key: String) -> String? {
        guard json.has(key) else { return nil }
        let value = json.str(key)
        return value.trimmingCharacters(in: .whitespaces).isEmpty ? nil : value
    }

    /// A client from the server's JSON, or nil when it is not a well-formed one (never trusted blindly).
    public static func client(_ json: JSON) -> ConnectionClient? {
        if let message = Contract.parseTolerant("connection_client", json) as? Contract.ConnectionClient, kinds.contains(message.kind) {
            func clean(_ value: String?) -> String? { value.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } }
            return ConnectionClient(id: message.id, kind: message.kind, user: clean(message.user), label: clean(message.label), appVersion: clean(message.app_version),
                                    firstSeen: message.first_seen, lastSeen: message.last_seen,
                                    activeSessions: Int(max(0, message.active_sessions)), loginsOk: Int(max(0, message.logins_ok)), loginsFailed: Int(max(0, message.logins_failed)),
                                    ip: clean(message.ip), agent: clean(message.agent))
        }
        return legacyClient(json)
    }

    private static func legacyClient(_ json: JSON) -> ConnectionClient? {
        let id = json.str("id"), kind = json.str("kind")
        guard id.count == 16, id.allSatisfy({ ($0 >= "0" && $0 <= "9") || ($0 >= "a" && $0 <= "f") }), kinds.contains(kind) else { return nil }
        return ConnectionClient(id: id, kind: kind, user: text(json, "user"), label: text(json, "label"), appVersion: text(json, "app_version"),
                                firstSeen: json.str("first_seen"), lastSeen: json.str("last_seen"),
                                activeSessions: max(0, json.int("active_sessions")), loginsOk: max(0, json.int("logins_ok")), loginsFailed: max(0, json.int("logins_failed")),
                                ip: text(json, "ip"), agent: text(json, "agent"))
    }

    /// The list of the answer `{ "clients": [...] }`; what is not a client is left out.
    public static func list(_ json: JSON) -> [ConnectionClient] { json.objects("clients").compactMap(client) }

    /// "Studio · label · user · Versión 1.2", the parts that exist.
    public static func title(_ client: ConnectionClient, _ t: Translator) -> String {
        let kind: String
        switch client.kind {
        case "studio": kind = t.tr("Studio")
        case "android": kind = t.tr("App Android")
        case "node": kind = t.tr("Panel de nodo")
        case "voice": kind = t.tr("Servicio de voz")
        default: kind = t.tr("Otro cliente")
        }
        return ([kind, client.label, client.user, client.appVersion.map { t.trf("Versión %s", $0) }] as [String?]).compactMap { $0 }.joined(separator: " · ")
    }
}
