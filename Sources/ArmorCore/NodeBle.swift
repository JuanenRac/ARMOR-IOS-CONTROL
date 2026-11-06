// ARMOR-IOS-CONTROL - the protocol of a field node's Bluetooth configuration channel (ARMOR-NODE-RADAR, docs/BLE_PROVISIONING.md), without the radio.
// The same rules as the Android app: the framing of the byte stream, the requests and answers, what a node says about itself, the set-up code of a board and the settings the app sends.
// The radio itself (CoreBluetooth) lives in the app target; this file has no UIKit, SwiftUI or CoreBluetooth in it, so it is tested without a phone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The GATT identifiers of a node: one service, a characteristic the app writes and one the node notifies.
public enum NodeGatt {
    public static let service = "a5c0de00-5261-4d4f-8000-41524d4f5200"
    /// The app writes its requests here.
    public static let rx = "a5c0de01-5261-4d4f-8000-41524d4f5200"
    /// The node notifies its answers here.
    public static let tx = "a5c0de02-5261-4d4f-8000-41524d4f5200"
    public static let preferredMtu = 247
    /// The name a node advertises starts with this.
    public static let namePrefix = "ARMOR-"
}

/// A message on the byte stream: [length: 2 bytes, big-endian][UTF-8 JSON], at most `maxMessage` bytes; the stream may be cut anywhere.
public enum BleFrame {
    public static let maxMessage = 6000

    /// The bytes to send for one message, or nil when it is empty or too long.
    public static func frame(_ json: String) -> [UInt8]? {
        let body = Array(json.utf8)
        if body.isEmpty || body.count > maxMessage { return nil }
        return [UInt8(body.count >> 8), UInt8(body.count & 0xFF)] + body
    }

    /// The pieces a framed message goes out in: at most `size` bytes each (an ATT payload, MTU - 3).
    public static func chunks(_ framed: [UInt8], size: Int) -> [[UInt8]] {
        precondition(size > 0)
        return stride(from: 0, to: framed.count, by: size).map { Array(framed[$0..<min($0 + size, framed.count)]) }
    }
}

/// Collects the notifications of the node and hands over whole messages. A length of zero or above the maximum discards what was collected.
public final class BleAssembler {
    private var buffer: [UInt8] = []
    public private(set) var errors = 0

    public init() {}

    /// Adds bytes and returns every message they complete, in order.
    public func feed(_ bytes: [UInt8]) -> [String] {
        buffer += bytes
        var messages: [String] = []
        while buffer.count >= 2 {
            let wanted = (Int(buffer[0]) << 8) | Int(buffer[1])
            if wanted == 0 || wanted > BleFrame.maxMessage { buffer = []; errors += 1; break }
            if buffer.count < 2 + wanted { break }
            messages.append(String(decoding: buffer[2..<(2 + wanted)], as: UTF8.self))
            buffer = Array(buffer[(2 + wanted)...])
        }
        return messages
    }

    public func reset() { buffer = [] }
}

/// An answer of the node: `ok` with its data, or an `error` code (see the protocol's list) and perhaps data.
public struct NodeReply: @unchecked Sendable {
    public let id: Int
    public let ok: Bool
    public let error: String
    public let data: JSON

    public init(id: Int, ok: Bool, error: String, data: JSON = [:]) { self.id = id; self.ok = ok; self.error = error; self.data = data }

    private static func problemText(_ path: String, _ code: String, _ t: Translator) -> String {
        if path == "uplink" && code == "not_available" { return t.tr("uplink: este nodo no tiene puerto Ethernet, usa el Wi-Fi") }
        if path == "sta.enabled" && code == "required" { return t.tr("sta.enabled: sin Wi-Fi ni punto de acceso el nodo quedaría inalcanzable") }
        return "\(path): \(code)"
    }

    /// The fields the node found wrong in a settings document, as "path: code".
    public func problems(_ t: Translator) -> [String] {
        data.objects("problems").map { NodeReply.problemText($0.str("path"), $0.str("code"), t) }
    }
}

public enum NodeProtocol {
    /// A request as JSON text.
    public static func request(id: Int, op: String, args: JSON? = nil) -> String {
        var object: JSON = ["id": id, "op": op]
        if let args { object["args"] = args }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Reads an answer; nil when the text is not one.
    public static func reply(_ text: String) -> NodeReply? {
        guard let bytes = text.data(using: .utf8), let json = (try? JSONSerialization.jsonObject(with: bytes)) as? JSON else { return nil }
        guard let id = json["id"] as? Int, let ok = json["ok"] as? Bool else { return nil }
        return NodeReply(id: id, ok: ok, error: json.str("error"), data: json.object("data") ?? [:])
    }

    /// Why a node could not join the Wi-Fi network it was given.
    public static func staErrorText(_ code: String, _ t: Translator) -> String {
        switch code {
        case "network_not_found": return t.tr("El nodo no encuentra esa red Wi-Fi: revisa el nombre, que esté al alcance y que sea de 2,4 GHz (el nodo no usa 5 GHz).")
        case "wrong_password": return t.tr("La contraseña del Wi-Fi no es correcta (o el router no acepta la conexión).")
        default: return t.tr("El nodo no consiguió conectarse al Wi-Fi.")
        }
    }

    /// The words for an error code of the node.
    public static func errorText(_ code: String, _ t: Translator) -> String {
        switch code {
        case "wrong_code": return t.tr("El código de configuración no es correcto.")
        case "wrong_credentials": return t.tr("Usuario o contraseña incorrectos.")
        case "too_many_attempts": return t.tr("Demasiados intentos: espera un momento.")
        case "invalid_name": return t.tr("El nombre de usuario no es válido (3 a 32 caracteres: a-z, 0-9, . _ -).")
        case "weak_password": return t.tr("La contraseña debe tener de 8 a 64 caracteres.")
        case "unauthorized": return t.tr("Hay que iniciar sesión.")
        case "forbidden": return t.tr("No tienes permiso para eso.")
        case "setup_required": return t.tr("El nodo aún no tiene usuarios: crea el administrador.")
        case "invalid": return t.tr("Algunos valores no son válidos.")
        case "storage": return t.tr("El nodo no pudo escribir en su memoria.")
        case "wifi_busy": return t.tr("La radio del nodo está ocupada: inténtalo de nuevo.")
        case "scan_failed": return t.tr("La búsqueda de redes ha fallado.")
        case "wifi_unavailable": return t.tr("No se pudo arrancar el Wi-Fi del nodo.")
        case "timeout": return t.tr("El nodo no respondió a tiempo.")
        case "network_not_found": return staErrorText(code, t)
        case "disconnected": return t.tr("Se perdió la conexión con el nodo.")
        default: return t.trf("El nodo respondió con un error (%s).", code)
        }
    }
}

/// The kinds of field node that answer on the configuration channel; they all speak the same protocol, so the app configures each of them the same way.
public enum NodeKind: Equatable, Sendable {
    case radar, solar, electrical, alarm, hmi, unknown

    public func label(_ t: Translator) -> String {
        switch self {
        case .radar: return t.tr("Nodo radar")
        case .solar: return t.tr("Nodo solar")
        case .electrical: return t.tr("Nodo eléctrico")
        case .alarm: return t.tr("Nodo de alarma")
        case .hmi: return t.tr("Panel táctil")
        case .unknown: return t.tr("Nodo ARMOR")
        }
    }

    /// From the `kind` a node declares in its `hello`; a node that predates it is told by its identifier when that says so, and is otherwise just an ARMOR node.
    public static func of(_ declared: String, nodeId: String = "") -> NodeKind {
        switch declared.lowercased() {
        case "radar": return .radar
        case "solar": return .solar
        case "electrical": return .electrical
        case "alarm": return .alarm
        case "hmi": return .hmi
        default: break
        }
        if declared.isEmpty && nodeId.lowercased().hasPrefix("solar-") { return .solar }
        if declared.isEmpty && nodeId.lowercased().hasPrefix("electrical-") { return .electrical }
        return .unknown
    }
}

/// What the node says about itself before anyone signs in.
public struct NodeHello: Equatable, Sendable {
    public let nodeId: String, name: String, mac: String, firmware: String
    public let setup: Bool, hasIp: Bool
    public let ip: String
    public let staConnected: Bool
    public let staSsid: String
    public let kind: NodeKind
    public let staError: String
    public let apActive: Bool

    public init(_ data: JSON) {
        nodeId = data.str("node_id"); name = data.str("name"); mac = data.str("mac"); firmware = data.str("firmware")
        setup = data.bool("setup"); hasIp = data.bool("has_ip"); ip = data.str("ip")
        staConnected = data.bool("sta_connected"); staSsid = data.str("sta_ssid")
        kind = NodeKind.of(data.str("kind"), nodeId: data.str("node_id"))
        staError = data.str("sta_error"); apActive = data.bool("ap_active")
    }
}

/// What a node has done with the connection it was given, read from its `hello` after it restarted.
public enum NodeOutcome: Equatable, Sendable {
    /// It has an address: `ssid` is the Wi-Fi network it joined (empty on a cable).
    case online(ip: String, ssid: String)
    /// It tried and could not: the reason is in plain words.
    case failed(reason: String)
    /// It is on, but has neither an address nor a reason yet.
    case waiting

    public static func of(_ hello: NodeHello, _ t: Translator) -> NodeOutcome {
        if hello.hasIp { return .online(ip: hello.ip, ssid: hello.staConnected ? hello.staSsid : "") }
        if !hello.staError.trimmingCharacters(in: .whitespaces).isEmpty { return .failed(reason: NodeProtocol.staErrorText(hello.staError, t)) }
        return .waiting
    }
}

/// A Wi-Fi network the node heard.
public struct WifiNetwork: Equatable, Sendable, Identifiable {
    public let ssid: String
    public let rssi: Int
    public let channel: Int
    public let security: String
    public var id: String { ssid }

    public static func list(_ data: JSON) -> [WifiNetwork] {
        data.objects("networks").map { WifiNetwork(ssid: $0.str("ssid"), rssi: $0.int("rssi"), channel: $0.int("channel"), security: $0.str("security")) }
    }
}

/// The set-up code of a board on a fleet: HMAC-SHA256 of its MAC (twelve lowercase hexadecimal digits) with the fleet secret, ten symbols of it. The node and tools/adopt_node.py make the same code.
public enum SetupCode {
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    /// The twelve hexadecimal digits of a MAC written any way ("A1:B2:...", "a1b2..."), lowercase; nil when it has not twelve.
    public static func macDigits(_ mac: String) -> String? {
        let digits = mac.lowercased().filter { ($0 >= "0" && $0 <= "9") || ($0 >= "a" && $0 <= "f") }
        return digits.count == 12 ? digits : nil
    }

    public static func derive(secret: String, mac: String) -> String? {
        guard let digits = macDigits(mac), secret.count >= 16 else { return nil }
        let digest = Sha256.hmac(key: Array(secret.utf8), message: Array(digits.utf8))
        return String((0..<10).map { alphabet[Int(digest[$0]) % 31] })
    }
}

/// The partial settings document the app sends, built from what the operator filled in; an empty field is left out, so it changes nothing.
public enum NodeSettingsPatch {
    public struct Form: Equatable, Sendable {
        public var name = ""
        public var useWifi = false
        public var wifiSsid = ""
        public var wifiPassword = ""
        public var fixedAddress = false
        public var address = ""
        public var netmask = "255.255.255.0"
        public var gateway = ""
        public var dns = ""
        public var brokerUri = ""
        public var brokerUser = ""
        public var brokerPassword = ""
        /// "", "setup", "always" or "off".
        public var bluetoothMode = ""
        public init() {}
    }

    private static func octets(_ text: String) -> [Int]? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ (1...3).contains($0.count) && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        let values = parts.compactMap { Int($0) }
        return values.count == 4 && values.allSatisfy({ (0...255).contains($0) }) ? values : nil
    }

    private static func asInt(_ o: [Int]) -> Int { o.reduce(0) { ($0 << 8) | $1 } }

    /// What is wrong with the form before it is sent; empty when it can be sent. The node checks it again and says which field it refuses.
    public static func problems(_ form: Form, _ t: Translator) -> [String] {
        var found: [String] = []
        if form.useWifi {
            if form.wifiSsid.trimmingCharacters(in: .whitespaces).isEmpty { found.append(t.tr("Falta el nombre de la red Wi-Fi.")) }
            if !form.wifiPassword.isEmpty && !(8...63).contains(form.wifiPassword.count) { found.append(t.tr("La contraseña del Wi-Fi tiene de 8 a 63 caracteres.")) }
        }
        if form.fixedAddress {
            let address = octets(form.address), mask = octets(form.netmask), gateway = octets(form.gateway)
            if address == nil { found.append(t.tr("La dirección IP no es válida (por ejemplo 192.168.0.60).")) }
            if mask == nil { found.append(t.tr("La máscara no es válida (por ejemplo 255.255.255.0).")) }
            if gateway == nil { found.append(t.tr("La puerta de enlace no es válida (por ejemplo 192.168.0.1).")) }
            if !form.dns.trimmingCharacters(in: .whitespaces).isEmpty && octets(form.dns) == nil { found.append(t.tr("El DNS no es válido.")) }
            if let address, let mask, let gateway {
                let m = asInt(mask)
                if (asInt(address) & m) != (asInt(gateway) & m) { found.append(t.tr("La puerta de enlace tiene que estar en la misma red que la dirección.")) }
                if asInt(address) == asInt(gateway) { found.append(t.tr("La dirección del nodo y la puerta de enlace no pueden ser la misma.")) }
            }
        }
        return found
    }

    public static func build(_ form: Form) -> JSON {
        func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        var patch: JSON = [:]
        if !trimmed(form.name).isEmpty { patch["node"] = ["name": trimmed(form.name)] }
        patch["uplink"] = form.useWifi ? "wifi" : "ethernet"
        if form.useWifi {
            var sta: JSON = ["enabled": true, "ssid": form.wifiSsid]
            if !form.wifiPassword.isEmpty { sta["password"] = form.wifiPassword }
            patch["sta"] = sta
        }
        // DHCP or a fixed address, on whichever connection the node uses: the cable or the Wi-Fi station
        var ip: JSON = ["dhcp": !form.fixedAddress]
        if form.fixedAddress {
            ip["address"] = trimmed(form.address); ip["netmask"] = trimmed(form.netmask); ip["gateway"] = trimmed(form.gateway)
            ip["dns1"] = trimmed(form.dns).isEmpty ? trimmed(form.gateway) : trimmed(form.dns)
        }
        patch["ip"] = ip
        if !trimmed(form.brokerUri).isEmpty {
            var mqtt: JSON = ["enabled": true, "uri": trimmed(form.brokerUri)]
            if !trimmed(form.brokerUser).isEmpty { mqtt["username"] = trimmed(form.brokerUser) }
            if !form.brokerPassword.isEmpty { mqtt["password"] = form.brokerPassword }
            patch["mqtt"] = mqtt
        }
        if ["setup", "always", "off"].contains(form.bluetoothMode) { patch["ble"] = ["mode": form.bluetoothMode] }
        return patch
    }
}

/// How the pairing code read from a QR code relates to the node list and to this app's server.
public enum PairingMatch {
    /// A node found by Bluetooth matches the pairing code when its advertised name holds the node id of the code (case ignored).
    public static func matches(nodeName: String, pairing: Pairing?) -> Bool {
        guard let pairing else { return false }
        return nodeName.range(of: pairing.nodeId, options: .caseInsensitive) != nil
    }

    /// True when the server written in the code is not the one the app uses (so the person is told); false when the app has no server set.
    public static func otherServer(_ pairing: Pairing, origin: String) -> Bool {
        guard !origin.isEmpty else { return false }
        return PairingCode.cleanServer(origin) != pairing.server
    }
}
