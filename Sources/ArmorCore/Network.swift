// ARMOR-IOS-CONTROL - the local network as the ARMOR-NETWORK nodes see it: what the server reports, its parsing and its wording, and the finder of nodes that look like ARMOR nodes.
// The same reading as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// What an operator has said about a device: a name, whether it is known. Nil fields were never set.
public struct NetworkNote: Equatable, Sendable {
    public let name: String?, notes: String?
    public let trusted: Bool
    public let kind: String?
}

public struct NetworkPort: Equatable, Sendable {
    public let port: Int
    public let proto: String
    public let service: String?, banner: String?
}

public struct NetworkDevice: Equatable, Sendable, Identifiable {
    public let id: String, ip: String
    public let mac: String?
    public let randomizedMac: Bool
    public let vendor: String?, hostname: String?
    public let kind: String
    public let os: String?
    public let online: Bool
    public let firstSeenMs: Int, lastSeenMs: Int
    public let latencyMs: Double?
    public let ports: [NetworkPort]
    public let services: [String]
    public let note: NetworkNote?

    /// What to call it: what the operator named it, else the name it gives itself, else its maker, else its address.
    public var name: String {
        for candidate in [note?.name, hostname, vendor] { if let candidate, !candidate.trimmingCharacters(in: .whitespaces).isEmpty { return candidate } }
        return ip
    }
    public var known: Bool { note?.trusted == true }
    public var shownKind: String { note?.kind ?? kind }
}

public struct NetworkProbe: Equatable, Sendable {
    public let target: String, kind: String
    public let ok: Bool
    public let latencyMs: Double?
}

public struct NetworkInternet: Equatable, Sendable {
    /// "up", "degraded", "down" (the router answers, nothing beyond does), "lan_down" (the router does not answer) or "unknown".
    public let state: String
    public let sinceMs: Int?
    public let gatewayOk: Bool?
    public let latencyMs: Double?, lossPercent: Double?
    public let probes: [NetworkProbe]
    public let outages24h: Int, downtime24hS: Int
}

/// What the Internet sees of the connection, as the network node reports it: the public address, the provider and the place.
public struct NetworkPublicInfo: Equatable, Sendable {
    public let ip: String
    public let org: String?, city: String?, region: String?, country: String?, timezone: String?
}

public struct NetworkNode: Equatable, Sendable, Identifiable {
    public let nodeId: String
    public let stale: Bool
    public let ip: String, cidr: String
    public let gateway: String?
    public let rxBps: Int?, txBps: Int?
    public let internet: NetworkInternet
    public let devices: [NetworkDevice]
    public let publicInfo: NetworkPublicInfo?
    public var id: String { nodeId }
}

public struct NetworkEvent: Equatable, Sendable, Identifiable {
    public let id: String, nodeId: String, kind: String
    public let atMs: Int
    public let deviceId: String?
    public let port: Int?, outageS: Int?
    public let detail: String?
}

public struct NetworkOutage: Equatable, Sendable {
    public let kind: String
    public let startedMs: Int, endedMs: Int, durationS: Int
}

public struct NetworkTotals: Equatable, Sendable {
    public var nodes = 0, stale = 0, devices = 0, online = 0, unknown = 0
    public var internet: String?
    public init() {}
}

public struct NetworkOverview: Equatable, Sendable {
    public var nodes: [NetworkNode] = []
    public var totals = NetworkTotals()
    public var events: [NetworkEvent] = []
    public var outages: [NetworkOutage] = []
    public init() {}
    public var isEmpty: Bool { nodes.isEmpty }
}

public enum NetworkParser {
    private static func text(_ json: JSON, _ key: String) -> String? {
        guard json.has(key) else { return nil }
        let value = json.str(key)
        return value.trimmingCharacters(in: .whitespaces).isEmpty ? nil : value
    }
    private static func whole(_ json: JSON, _ key: String) -> Int? { json.double(key).map { Int($0) } }

    public static func overview(_ root: JSON) -> NetworkOverview {
        var out = NetworkOverview()
        out.nodes = root.objects("nodes").compactMap(node)
        if let sums = root.object("totals") { out.totals = totals(sums) }
        out.events = root.objects("events").compactMap(event)
        out.outages = root.objects("outages").map { NetworkOutage(kind: $0.str("kind"), startedMs: $0.int("started_ms"), endedMs: $0.int("ended_ms"), durationS: $0.int("duration_s")) }
        return out
    }

    private static func totals(_ json: JSON) -> NetworkTotals {
        var t = NetworkTotals()
        t.nodes = json.int("nodes"); t.stale = json.int("stale"); t.devices = json.int("devices"); t.online = json.int("online"); t.unknown = json.int("unknown"); t.internet = text(json, "internet")
        return t
    }

    private static func node(_ json: JSON) -> NetworkNode? {
        let id = json.str("node_id")
        guard let iface = json.object("interface"), let internet = json.object("internet"), !id.isEmpty else { return nil }
        var info: NetworkPublicInfo?
        if let publicJson = json.object("public"), !publicJson.str("ip").isEmpty {
            info = NetworkPublicInfo(ip: publicJson.str("ip"), org: text(publicJson, "org"), city: text(publicJson, "city"), region: text(publicJson, "region"), country: text(publicJson, "country"), timezone: text(publicJson, "timezone"))
        }
        return NetworkNode(nodeId: id, stale: json.bool("stale"), ip: iface.str("ip"), cidr: iface.str("cidr"), gateway: text(iface, "gateway"), rxBps: whole(iface, "rx_bps"), txBps: whole(iface, "tx_bps"),
                           internet: internetState(internet), devices: json.objects("devices").compactMap(device), publicInfo: info)
    }

    private static func internetState(_ json: JSON) -> NetworkInternet {
        NetworkInternet(state: json.str("state", "unknown"), sinceMs: whole(json, "since_ms"), gatewayOk: json.has("gateway_ok") ? json.bool("gateway_ok") : nil, latencyMs: json.double("latency_ms"),
                        lossPercent: json.double("loss_percent"),
                        probes: json.objects("probes").map { NetworkProbe(target: $0.str("target"), kind: $0.str("kind"), ok: $0.bool("ok"), latencyMs: $0.double("latency_ms")) },
                        outages24h: json.int("outages_24h"), downtime24hS: json.int("downtime_24h_s"))
    }

    private static func device(_ json: JSON) -> NetworkDevice? {
        let id = json.str("id"), ip = json.str("ip")
        if id.isEmpty || ip.isEmpty { return nil }
        let note = json.object("note").map { NetworkNote(name: text($0, "name"), notes: text($0, "notes"), trusted: $0.bool("trusted"), kind: text($0, "kind")) }
        let ports = json.objects("ports").map { NetworkPort(port: $0.int("port"), proto: $0.str("proto", "tcp"), service: text($0, "service"), banner: text($0, "banner")) }
        let services = ((json["services"] as? [Any]) ?? []).compactMap { $0 as? String }
        return NetworkDevice(id: id, ip: ip, mac: text(json, "mac"), randomizedMac: json.bool("randomized_mac"), vendor: text(json, "vendor"), hostname: text(json, "hostname"), kind: json.str("kind", "unknown"),
                             os: text(json, "os"), online: json.bool("online"), firstSeenMs: json.int("first_seen_ms"), lastSeenMs: json.int("last_seen_ms"), latencyMs: json.double("latency_ms"),
                             ports: ports, services: services, note: note)
    }

    private static func event(_ json: JSON) -> NetworkEvent? {
        let id = json.str("id")
        if id.isEmpty { return nil }
        return NetworkEvent(id: id, nodeId: json.str("node_id"), kind: json.str("kind"), atMs: json.int("at_ms"), deviceId: text(json, "device_id"), port: json.has("port") ? json.int("port") : nil,
                            outageS: json.has("outage_s") ? json.int("outage_s") : nil, detail: text(json, "detail"))
    }
}

/// The wording of the network (the source phrases are Spanish; the translator gives them in the language chosen).
public enum NetworkText {
    /// The ports a house rarely wants open on a device anyone on the network can reach.
    public static let riskyPorts: Set<Int> = [21, 23, 445, 3306, 3389, 5432, 5900, 6379, 7547]

    public static func state(_ state: String, _ t: Translator) -> String {
        switch state {
        case "up": return t.tr("Hay internet")
        case "degraded": return t.tr("Internet va lento o pierde paquetes")
        case "down": return t.tr("Sin internet: el router responde y nada más allá")
        case "lan_down": return t.tr("La red local está caída: el router no responde")
        default: return t.tr("Comprobando internet…")
        }
    }

    /// Whose fault it is, when it is a fault.
    public static func hint(_ state: String, _ t: Translator) -> String? {
        switch state {
        case "down": return t.tr("La avería está más allá del router: el operador, la línea o la conexión del propio router.")
        case "lan_down": return t.tr("La avería está de este lado: el router apagado, un cable o un conmutador, o la máquina del nodo.")
        default: return nil
        }
    }

    public static func kind(_ kind: String, _ t: Translator) -> String {
        switch kind {
        case "router": return "Router"
        case "computer": return t.tr("Ordenador")
        case "phone": return t.tr("Móvil o tableta")
        case "tv": return t.tr("TV o reproductor")
        case "printer": return t.tr("Impresora")
        case "camera": return t.tr("Cámara")
        case "iot": return t.tr("Dispositivo inteligente")
        case "server": return t.tr("Servidor")
        case "nas": return t.tr("Almacenamiento (NAS)")
        case "network": return t.tr("Equipo de red")
        default: return t.tr("Desconocido")
        }
    }

    /// 45 -> "45 s", 200 -> "3 min", 7500 -> "2 h 5 min", 200000 -> "2 d 7 h".
    public static func duration(_ seconds: Int, _ t: Translator) -> String {
        let s = max(0, seconds)
        if s < 60 { return "\(s) s" }
        let m = Int((Double(s) / 60).rounded())
        if m < 60 { return "\(m) min" }
        let h = m / 60
        if h < 24 { return m % 60 != 0 ? t.trf("%s h %s min", h, m % 60) : "\(h) h" }
        let d = h / 24
        return h % 24 != 0 ? "\(d) d \(h % 24) h" : "\(d) d"
    }

    public static func bps(_ value: Int?, _ t: Translator) -> String {
        guard let value else { return "—" }
        if value >= 1_000_000_000 { return t.trf("%s Gbit/s", String(format: "%.2f", Double(value) / 1e9)) }
        if value >= 10_000_000 { return "\(Int((Double(value) / 1e6).rounded())) Mbit/s" }
        if value >= 1_000_000 { return t.trf("%s Mbit/s", String(format: "%.1f", Double(value) / 1e6)) }
        if value >= 1_000 { return "\(Int((Double(value) / 1e3).rounded())) kbit/s" }
        return "\(value) bit/s"
    }

    /// The sentence of an event; the device is named as the operator would call it.
    public static func event(_ event: NetworkEvent, _ devices: [NetworkDevice], _ t: Translator) -> String {
        let device = devices.first { $0.id == event.deviceId }
        let name = device.map { $0.name == $0.ip ? $0.ip : "\($0.name) (\($0.ip))" } ?? (event.deviceId ?? "")
        switch event.kind {
        case "new_device": return t.trf("Ha aparecido un dispositivo que nunca se había visto: %s", name)
        case "device_online": return t.trf("%s ha vuelto", name)
        case "device_offline": return t.trf("%s ha dejado de responder", name)
        case "ip_changed": return t.trf("%s ha cambiado de dirección", name)
        case "arp_conflict": return t.trf("Dos máquinas responden por una misma dirección: %s", event.detail ?? name)
        case "port_opened": return t.trf("%s ha abierto el puerto %s", name, event.port ?? 0)
        case "port_closed": return t.trf("%s ha cerrado el puerto %s", name, event.port ?? 0)
        case "internet_down": return t.tr("Se cayó internet")
        case "internet_up": return t.trf("Vuelve internet tras %s", duration(event.outageS ?? 0, t))
        case "gateway_down": return t.tr("El router ha dejado de responder")
        case "gateway_up": return t.tr("El router vuelve a responder")
        default: return event.kind
        }
    }

    /// The line the Status screen shows under the Network card: the state of the internet and how many devices there are.
    public static func summary(_ overview: NetworkOverview, _ t: Translator) -> String {
        guard let node = overview.nodes.first else { return "" }
        let devices = t.trf("%s/%s dispositivos", overview.totals.online, overview.totals.devices)
        let unknown = overview.totals.unknown > 0 ? t.trf(" · %s sin conocer", overview.totals.unknown) : ""
        return state(node.internet.state, t) + " · " + devices + unknown
    }

    /// A dotted address as a number, to order devices by address.
    public static func ipKey(_ ip: String) -> Int { ip.split(separator: ".").reduce(0) { $0 * 256 + (Int($1) ?? 0) } }
}

public struct NodeCandidate: Equatable, Sendable {
    public let ip: String
    public let mac: String?, hostname: String?, vendor: String?
    public let online: Bool
    public let nodeId: String?
}

/// Finding nodes on the network, for the Solar, Electrical and Radar screens: what the network node has found that looks like an ARMOR node (a host name starting with "armor-", which is what a node
/// calls itself, or an Espressif maker) and that is not yet known here.
public enum NodeFinder {
    static let hostPrefix = "armor-"

    public static func candidates(_ network: NetworkOverview?, knownIds: [String]) -> [NodeCandidate] {
        let ids = Set(knownIds.map { $0.lowercased() })
        var seen = Set<String>()
        var found: [NodeCandidate] = []
        for node in network?.nodes ?? [] {
            for device in node.devices {
                var host = device.hostname?.lowercased()
                if let h = host, h.hasSuffix(".local") { host = String(h.dropLast(6)) }
                if let h = host, h.hasSuffix(".") { host = String(h.dropLast()) }
                let named = host?.hasPrefix(hostPrefix) == true
                let espressif = device.vendor?.lowercased().contains("espressif") == true
                if !named && !espressif { continue }
                let nodeId: String? = named ? host.map { String($0.dropFirst(hostPrefix.count)) } : nil
                if let nodeId, ids.contains(nodeId) { continue }
                if seen.contains(device.ip) { continue }
                seen.insert(device.ip)
                found.append(NodeCandidate(ip: device.ip, mac: device.mac, hostname: device.hostname, vendor: device.vendor, online: device.online, nodeId: nodeId))
            }
        }
        return found.sorted { $0.online != $1.online ? $0.online : $0.ip < $1.ip }
    }
}
