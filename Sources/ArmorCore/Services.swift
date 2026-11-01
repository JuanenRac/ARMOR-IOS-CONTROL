// ARMOR-IOS-CONTROL - every service of the system, running or not: the programs of the machine (read from systemd) and the field nodes (read from what they last reported). Reading only.
// The same reading as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// "running", "stopped", "failed", "starting", "not_installed", "online", "offline" or "unknown".
public struct ServiceInfo: Equatable, Sendable, Identifiable {
    public let id: String, name: String, family: String, description: String, kind: String, state: String
    public let subState: String?, unit: String?
    public let enabled: Bool?
    public let pid: Int?, sinceMs: Int?, memoryBytes: Int?, restarts: Int?, port: Int?
}

public struct ServicesOverview: Equatable, Sendable {
    public var timeMs = 0
    public var systemd = false
    public var services: [ServiceInfo] = []
    public init() {}
}

public enum ServicesParser {
    private static func whole(_ json: JSON, _ key: String) -> Int? { json.double(key).map { Int($0) } }
    private static func text(_ json: JSON, _ key: String) -> String? {
        guard json.has(key) else { return nil }
        let value = json.str(key)
        return value.trimmingCharacters(in: .whitespaces).isEmpty ? nil : value
    }

    public static func overview(_ root: JSON) -> ServicesOverview {
        var out = ServicesOverview()
        out.timeMs = root.int("time_ms")
        out.systemd = root.bool("systemd")
        out.services = root.objects("services").map(service)
        return out
    }

    private static func service(_ json: JSON) -> ServiceInfo {
        ServiceInfo(id: json.str("id"), name: json.str("name"), family: json.str("family"), description: json.str("description"), kind: json.str("kind"), state: json.str("state", "unknown"),
                    subState: text(json, "sub_state"), unit: text(json, "unit"), enabled: json.has("enabled") ? json.bool("enabled") : nil, pid: whole(json, "pid"), sinceMs: whole(json, "since_ms"),
                    memoryBytes: whole(json, "memory_bytes"), restarts: whole(json, "restarts"), port: whole(json, "port"))
    }
}

/// The wording of the Services screen (the source phrases are Spanish; the translator gives them in the language chosen).
public enum ServicesText {
    public static let familyOrder = ["Core", "Network", "AI_and_voice", "Field_nodes"]

    public static func family(_ id: String, _ t: Translator) -> String {
        switch id {
        case "Core": return t.tr("Núcleo")
        case "Network": return t.tr("Red")
        case "AI_and_voice": return t.tr("IA y voz")
        case "Field_nodes": return t.tr("Nodos de campo")
        default: return id
        }
    }

    public static func state(_ state: String, _ t: Translator) -> String {
        switch state {
        case "running": return t.tr("En marcha")
        case "stopped": return t.tr("Parado")
        case "failed": return t.tr("Fallido")
        case "starting": return t.tr("Arrancando")
        case "not_installed": return t.tr("No instalado")
        case "online": return t.tr("En línea")
        case "offline": return t.tr("Sin responder")
        default: return t.tr("Desconocido")
        }
    }

    public static func memory(_ bytes: Int?) -> String {
        guard let bytes else { return "—" }
        if bytes >= 1_073_741_824 { return String(format: "%.1f GB", Double(bytes) / 1_073_741_824) }
        if bytes >= 1_048_576 { return String(format: "%.0f MB", Double(bytes) / 1_048_576) }
        return "\(bytes / 1024) KB"
    }

    /// "hace 3 min" style, for when it started or last reported.
    public static func since(_ sinceMs: Int?, nowMs: Int, _ t: Translator) -> String {
        guard let sinceMs, sinceMs > 0 else { return "—" }
        let seconds = max(0, (nowMs - sinceMs) / 1000)
        if seconds < 90 { return t.trf("hace %s s", seconds) }
        if seconds < 5400 { return t.trf("hace %s min", seconds / 60) }
        if seconds < 36 * 3600 { return t.trf("hace %s h", seconds / 3600) }
        return t.trf("hace %s d", seconds / 86400)
    }

    public static func summary(_ overview: ServicesOverview, _ t: Translator) -> String {
        let failed = overview.services.filter { $0.state == "failed" || $0.state == "offline" }.count
        let running = overview.services.filter { $0.state == "running" || $0.state == "online" }.count
        return failed > 0 ? t.trf("%s con problemas de %s", failed, overview.services.count) : t.trf("%s de %s en marcha", running, overview.services.count)
    }
}
