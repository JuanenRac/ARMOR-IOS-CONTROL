// ARMOR-IOS-CONTROL - the electrical network as the electrical nodes measure it: what the server reports, its parsing and its wording. Reading only. The same reading as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// One measured channel of a node (a circuit, a line, the grid input, a DC bus); what the meter did not say is nil.
public struct ElectricalChannel: Equatable, Sendable, Identifiable {
    public let id: String, domain: String, label: String
    public let voltageV: Double?, currentA: Double?, powerW: Double?, energyKwh: Double?, frequencyHz: Double?, powerFactor: Double?
    /// "closed", "open" or "unknown" for a channel with a switch, or nil.
    public let state: String?
    public let alarm: Bool
    public var name: String { label.isEmpty ? id : label }
}

public struct ElectricalSwitch: Equatable, Sendable, Identifiable {
    public let id: String, label: String
    public let sourceA: String?, sourceB: String?
    public let aClosed: Bool, bClosed: Bool
    public let selected: String
    public let closing: Bool
    public let fault: String
    public var name: String { label.isEmpty ? id : label }
}

public struct ElectricalNode: Equatable, Sendable, Identifiable {
    public let nodeId: String
    public let stale: Bool
    public let receivedAt: String
    public let switchingEnabled: Bool?
    public let channels: [ElectricalChannel]
    public let switches: [ElectricalSwitch]
    public var id: String { nodeId }
}

/// The sums the server makes over the nodes that are reporting.
public struct ElectricalTotals: Equatable, Sendable {
    public var nodes = 0
    public var channels = 0
    public var stale = 0
    /// Watts from the grid (negative while the house feeds it); nil when no node reports the channel called grid.
    public var gridW: Double?
    public var gridKwh: Double?
    public var alarms = 0
    public init() {}
}

public struct ElectricalOverview: Equatable, Sendable {
    public var nodes: [ElectricalNode] = []
    public var totals = ElectricalTotals()
    public init() {}
    public var isEmpty: Bool { nodes.isEmpty }
}

public enum ElectricalParser {
    public static func overview(_ root: JSON) -> ElectricalOverview {
        var out = ElectricalOverview()
        out.nodes = root.objects("nodes").compactMap(node)
        if let sums = root.object("totals") { out.totals = totals(sums) }
        return out
    }

    public static func totals(_ json: JSON) -> ElectricalTotals {
        var t = ElectricalTotals()
        t.nodes = json.int("nodes"); t.channels = json.int("channels"); t.stale = json.int("stale"); t.gridW = json.double("grid_w"); t.gridKwh = json.double("grid_kwh"); t.alarms = json.int("alarms")
        return t
    }

    private static func node(_ json: JSON) -> ElectricalNode? {
        let id = json.str("node_id")
        guard let reading = json.object("reading"), !id.isEmpty else { return nil }
        return ElectricalNode(nodeId: id, stale: json.bool("stale"), receivedAt: json.str("received_at"), switchingEnabled: reading.has("switching_enabled") ? reading.bool("switching_enabled") : nil,
                              channels: reading.objects("channels").compactMap(channel), switches: reading.objects("switches").compactMap(switchItem))
    }

    private static func switchItem(_ json: JSON) -> ElectricalSwitch? {
        let id = json.str("id")
        if id.isEmpty { return nil }
        let a = json.str("source_a"), b = json.str("source_b")
        return ElectricalSwitch(id: id, label: json.str("label"), sourceA: a.isEmpty ? nil : a, sourceB: b.isEmpty ? nil : b, aClosed: json.bool("a_closed"), bClosed: json.bool("b_closed"),
                                selected: json.str("selected", "none"), closing: json.bool("closing"), fault: json.str("fault", "none"))
    }

    private static func channel(_ c: JSON) -> ElectricalChannel? {
        let id = c.str("id")
        if id.isEmpty { return nil }
        return ElectricalChannel(id: id, domain: c.str("domain", "ac"), label: c.str("label"), voltageV: c.double("voltage_v"), currentA: c.double("current_a"), powerW: c.double("power_w"),
                                 energyKwh: c.double("energy_kwh"), frequencyHz: c.double("frequency_hz"), powerFactor: c.double("power_factor"), state: c.has("state") ? c.str("state") : nil, alarm: c.bool("alarm"))
    }
}

/// The wording of the electrical network (the source phrases are Spanish; the translator gives them in the language chosen).
public enum ElectricalText {
    public static func watts(_ value: Double?) -> String {
        guard let value else { return "—" }
        return abs(value) >= 1000 ? String(format: "%.2f kW", value / 1000) : "\(Int(value.rounded())) W"
    }
    public static func volts(_ value: Double?) -> String { value.map { String(format: "%.1f V", $0) } ?? "—" }
    public static func amps(_ value: Double?) -> String { value.map { String(format: "%.2f A", $0) } ?? "—" }
    public static func kwh(_ value: Double?) -> String { value.map { String(format: "%.1f kWh", $0) } ?? "—" }

    /// Which way the power goes on the grid input: drawing, feeding the network, or nothing.
    public static func gridFlow(_ watts: Double?, _ t: Translator) -> String {
        guard let watts else { return t.tr("Sin dato") }
        if abs(watts) < 5 { return t.tr("Sin consumo de red") }
        return watts > 0 ? t.trf("Consume %s de la red", Self.watts(watts)) : t.trf("Cede %s a la red", Self.watts(-watts))
    }

    public static func switchState(_ state: String?, _ t: Translator) -> String? {
        switch state {
        case "closed": return t.tr("Cerrado")
        case "open": return t.tr("Abierto")
        case "unknown": return t.tr("Sin confirmar")
        default: return nil
        }
    }

    public static func switchSource(_ item: ElectricalSwitch, _ t: Translator) -> String {
        switch item.selected {
        case "a": return t.tr("Fuente A") + (item.sourceA.map { " (\($0))" } ?? "")
        case "b": return t.tr("Fuente B") + (item.sourceB.map { " (\($0))" } ?? "")
        default: return t.tr("Ninguna fuente")
        }
    }

    public static func switchFault(_ fault: String, _ t: Translator) -> String? {
        switch fault {
        case "did_not_close": return t.tr("No cerró")
        case "did_not_open": return t.tr("No abrió")
        case "both_closed": return t.tr("Las dos fuentes cerradas")
        case "disabled": return t.tr("Maniobra desactivada")
        default: return nil
        }
    }
}
