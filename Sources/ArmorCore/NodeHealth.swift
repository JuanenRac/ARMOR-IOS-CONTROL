// ARMOR-IOS-CONTROL - the health of the nodes as the server reports it: the same report from every radar, solar, electrical, alarm and wall-panel node, its parsing and its wording.
// The same reading as the Android app. Reading only.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// What a node says about itself, and what the server makes of it. `rssiDbm` is nil unless the node is on a Wi-Fi link that is up.
public struct NodeHealthView: Equatable, Sendable, Identifiable {
    public let nodeId: String
    /// "radar", "solar", "electrical", "alarm" or "hmi".
    public let family: String
    public let firmware: String
    public let board: String?
    /// "ok", "warning" or "stale" (no report for a few minutes).
    public let status: String
    public let receivedAt: String
    public let uptimeSeconds: Int
    public let resetReason: String
    public let heapFree: Int, heapMin: Int
    /// "wifi", "ethernet" or "none".
    public let link: String
    public let linkUp: Bool
    public let rssiDbm: Int?
    public let brokerConnections: Int, lowStackTasks: Int
    public let lastError: String?
    public let restarts24h: Int
    /// The codes of the warnings the server raised: "node_low_memory", "node_frequent_resets", "node_link_flapping", "node_weak_signal", and for a radar node "node_sensor_bluetooth_open", "node_radar_masked" and "node_wifi_jam".
    public let warnings: [String]
    /// What the control of the node says: "running", "paused" or "standby" (empty when the server says nothing), and whether maintenance is on.
    public let controlState: String
    public let maintenance: Bool
    public var id: String { nodeId }
    public var needsLook: Bool { status == "warning" }
    public var silent: Bool { status == "stale" }
}

public struct NodeHealthTotals: Equatable, Sendable {
    public var nodes = 0, stale = 0, withWarnings = 0
    public init(nodes: Int = 0, stale: Int = 0, withWarnings: Int = 0) { self.nodes = nodes; self.stale = stale; self.withWarnings = withWarnings }
}

/// A node the server knows but that has sent no report yet (an older firmware, or the broker does not let it write one).
public struct NodeWaiting: Equatable, Sendable { public let nodeId: String, family: String }

public struct NodeHealthOverview: Equatable, Sendable {
    public var nodes: [NodeHealthView] = []
    public var waiting: [NodeWaiting] = []
    public var totals = NodeHealthTotals()
    public var isEmpty: Bool { nodes.isEmpty }
    public init() {}
}

public enum NodeHealthParser {
    public static func overview(_ root: JSON) -> NodeHealthOverview {
        var out = NodeHealthOverview()
        out.nodes = root.objects("nodes").compactMap(node)
        out.waiting = root.objects("waiting").compactMap { item in
            let id = item.str("node_id")
            return id.isEmpty ? nil : NodeWaiting(nodeId: id, family: item.str("family"))
        }
        if let totals = root.object("totals") { out.totals = NodeHealthTotals(nodes: totals.int("nodes"), stale: totals.int("stale"), withWarnings: totals.int("with_warnings")) }
        return out
    }

    private static func node(_ json: JSON) -> NodeHealthView? {
        let id = json.str("node_id")
        guard !id.isEmpty, let report = json.object("report") else { return nil }
        func nonEmpty(_ text: String) -> String? { text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : text }
        return NodeHealthView(
            nodeId: id, family: json.str("family"), firmware: json.str("firmware"), board: nonEmpty(json.str("board")),
            status: json.str("status", "ok"), receivedAt: json.str("received_at"),
            uptimeSeconds: report.int("uptime_s"), resetReason: report.str("reset_reason", "unknown"),
            heapFree: report.int("heap_free"), heapMin: report.int("heap_min"),
            link: report.str("link", "none"), linkUp: report.bool("link_up"), rssiDbm: report.has("rssi_dbm") ? report.int("rssi_dbm") : nil,
            brokerConnections: report.int("broker_reconnects"), lowStackTasks: report.int("low_stack_tasks"), lastError: nonEmpty(report.str("last_error")),
            restarts24h: json.int("restarts_24h"), warnings: json.objects("warnings").map { $0.str("code") },
            controlState: json.object("control")?.str("state") ?? "", maintenance: json.object("control")?.bool("maintenance") ?? false)
    }
}

/// The wording of the health of the nodes (the source phrases are Spanish; the translator gives them in the language chosen).
public enum NodeHealthText {
    private static let abnormalResets: Set<String> = ["panic", "int_wdt", "task_wdt", "other_wdt", "brownout", "power_glitch", "cpu_lockup"]

    public static func family(_ family: String, _ t: Translator) -> String {
        switch family {
        case "radar": return t.tr("Radar")
        case "solar": return t.tr("Pasarela solar")
        case "electrical": return t.tr("Eléctrico")
        case "alarm": return t.tr("Central de alarma")
        case "hmi": return t.tr("Panel de pared")
        default: return family
        }
    }

    public static func status(_ status: String, _ t: Translator) -> String {
        switch status {
        case "ok": return t.tr("sano")
        case "warning": return t.tr("conviene mirarlo")
        default: return t.tr("sin informe")
        }
    }

    public static func warning(_ code: String, _ t: Translator) -> String {
        switch code {
        case "node_low_memory": return t.tr("Anda corto de memoria")
        case "node_frequent_resets": return t.tr("Se reinicia demasiado")
        case "node_link_flapping": return t.tr("Pierde el broker una y otra vez")
        case "node_weak_signal": return t.tr("Señal Wi-Fi débil")
        case "node_sensor_bluetooth_open": return t.tr("El Bluetooth propio de un sensor está abierto")
        case "node_radar_masked": return t.tr("Los sensores del radar están tapados")
        case "node_wifi_jam": return t.tr("Posible bloqueo de la Wi-Fi")
        default: return code
        }
    }

    /// Why the node last started, in words.
    public static func resetReason(_ reason: String, _ t: Translator) -> String {
        switch reason {
        case "power_on": return t.tr("alimentación conectada")
        case "external": return t.tr("pin de reinicio")
        case "software": return t.tr("reinicio pedido (una actualización, por ejemplo)")
        case "panic": return t.tr("fallo del programa (panic)")
        case "int_wdt": return t.tr("perro guardián (interrupciones)")
        case "task_wdt": return t.tr("perro guardián (una tarea se paró)")
        case "other_wdt": return t.tr("perro guardián")
        case "deep_sleep": return t.tr("despertó del sueño profundo")
        case "brownout": return t.tr("caída de tensión (brown-out)")
        case "sdio": return t.tr("reinicio por SDIO")
        case "usb": return t.tr("reinicio por USB")
        case "jtag": return t.tr("reinicio por el depurador")
        case "efuse": return t.tr("reinicio por un error de eFuse")
        case "power_glitch": return t.tr("interferencia en la alimentación")
        case "cpu_lockup": return t.tr("procesador bloqueado")
        default: return t.tr("desconocido")
        }
    }

    /// A restart nobody asked for: a crash, a watchdog, a sag of the supply.
    public static func isUnexpected(_ reason: String) -> Bool { abnormalResets.contains(reason) }

    /// The link in words: "Wi-Fi · activo · -61 dBm (buena)", "Cable Ethernet · caído".
    public static func link(_ view: NodeHealthView, _ t: Translator) -> String {
        let kind: String
        switch view.link {
        case "wifi": kind = t.tr("Wi-Fi")
        case "ethernet": kind = t.tr("Cable Ethernet")
        default: kind = t.tr("sin enlace")
        }
        let state = view.linkUp ? t.tr("activo") : t.tr("caído")
        let reading = view.rssiDbm.map { " · " + t.trf("%s dBm (%s)", $0, signal($0, t)) } ?? ""
        return "\(kind) · \(state)\(reading)"
    }

    /// The usual reading of a Wi-Fi signal: -60 dBm or better is good, down to -70 fair, down to -80 weak, below that very weak.
    public static func signal(_ dbm: Int, _ t: Translator) -> String {
        if dbm >= -60 { return t.tr("buena") }
        if dbm >= -70 { return t.tr("aceptable") }
        if dbm >= -80 { return t.tr("débil") }
        return t.tr("muy débil")
    }

    /// 142000 is "139 KB", a megabyte or more "1.4 MB".
    public static func bytes(_ value: Int) -> String {
        if value < 0 { return "–" }
        if value >= 1_048_576 { return String(format: "%.1f MB", Double(value) / 1_048_576.0) }
        if value >= 1024 { return "\(Int((Double(value) / 1024.0).rounded())) KB" }
        return "\(value) B"
    }

    /// "3 d 4 h", "5 h 12 min" or "7 min".
    public static func uptime(_ seconds: Int, _ t: Translator) -> String {
        if seconds < 0 { return "–" }
        let days = seconds / 86_400, hours = (seconds % 86_400) / 3_600, minutes = (seconds % 3_600) / 60
        if days > 0 { return t.trf("%s d %s h", days, hours) }
        if hours > 0 { return t.trf("%s h %s min", hours, minutes) }
        return t.trf("%s min", minutes)
    }

    /// The line the screen shows at the top.
    public static func summary(_ overview: NodeHealthOverview, _ t: Translator) -> String {
        if overview.totals.nodes == 0 { return t.tr("Ningún nodo ha enviado aún su informe de salud") }
        if overview.totals.withWarnings > 0 {
            return overview.totals.withWarnings == 1 ? t.tr("Un nodo con aviso de salud") : t.trf("%s nodos con aviso de salud", overview.totals.withWarnings)
        }
        if overview.totals.stale > 0 { return t.trf("%s nodos sin informe reciente", overview.totals.stale) }
        return t.tr("Todos los nodos sanos")
    }

    /// The nodes that need a look first, then the silent ones, then the healthy, each in order of name.
    public static func orderedByNeed(_ nodes: [NodeHealthView]) -> [NodeHealthView] {
        func rank(_ node: NodeHealthView) -> Int { node.status == "warning" ? 0 : (node.status == "stale" ? 1 : 2) }
        return nodes.sorted { rank($0) != rank($1) ? rank($0) < rank($1) : $0.nodeId < $1.nodeId }
    }
}
