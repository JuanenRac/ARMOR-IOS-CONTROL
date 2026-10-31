// ARMOR-IOS-CONTROL - what the server says, as values, and the parsing of it. A field that is missing or of the wrong type never crashes: it takes a harmless default.
// Camera passwords and RTSP URLs never enter these models: only ARMOR-SERVER holds them.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public typealias JSON = [String: Any]

extension Dictionary where Key == String, Value == Any {
    func str(_ key: String, _ fallback: String = "") -> String {
        if let value = self[key] as? String { return value }
        return fallback
    }
    func int(_ key: String, _ fallback: Int = 0) -> Int {
        if let value = self[key] as? Int { return value }
        if let value = self[key] as? Double { return Int(value) }
        return fallback
    }
    func double(_ key: String) -> Double? {
        if self[key] is NSNull { return nil }
        if let value = self[key] as? Double { return value }
        if let value = self[key] as? Int { return Double(value) }
        return nil
    }
    func bool(_ key: String, _ fallback: Bool = false) -> Bool {
        if let value = self[key] as? Bool { return value }
        return fallback
    }
    func objects(_ key: String) -> [JSON] { (self[key] as? [Any])?.compactMap { $0 as? JSON } ?? [] }
    func object(_ key: String) -> JSON? { self[key] as? JSON }
    func has(_ key: String) -> Bool { self[key] != nil && !(self[key] is NSNull) }
}

public enum Json {
    /// A JSON object from bytes; an empty body is an empty object, anything that is not an object is an error.
    public static func object(_ data: Data) throws -> JSON {
        if data.isEmpty { return [:] }
        guard let value = try JSONSerialization.jsonObject(with: data) as? JSON else { throw ArmorApiError(message: "The answer is not a JSON object", status: nil) }
        return value
    }
}

// MARK: errors

/// A refusal or a failure: [status] is the HTTP status (nil when there was no answer), [code] the short code the server gave ("wrong_pin", "elevation_required", ...), [detail] its words.
public struct ArmorApiError: Error, Equatable {
    public let message: String
    public let status: Int?
    public let code: String
    public let detail: String

    public init(message: String, status: Int?, body: String = "") {
        self.message = message
        self.status = status
        var found = ""
        var words = ""
        if let data = body.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? JSON {
            found = json.str("code")
            words = json.str("error")
        }
        if found.isEmpty, let range = body.range(of: #""code"\s*:\s*"([a-z_]+)""#, options: .regularExpression) {
            found = String(body[range]).split(separator: "\"").dropFirst(2).first.map(String.init) ?? ""
        }
        if found.isEmpty, body.contains("elevation_required") { found = "elevation_required" }
        code = found
        detail = words
    }
    public var isElevationRequired: Bool { code == "elevation_required" }
    public var isUnauthorized: Bool { status == 401 }
}

// MARK: sign-in and session

public enum SignIn: Equatable, Sendable {
    case done
    case needsCode(challenge: String)
}

/// What the session of the server tells about the signed-in person and the options in force for the phone.
public struct SessionFacts: Equatable, Sendable {
    public var role: String
    public var deviceLock: String
    public init(role: String = "", deviceLock: String = "user") { self.role = role; self.deviceLock = deviceLock }

    /// From the answer of `GET /api/v1/studio/session`.
    public static func parse(_ json: JSON) -> SessionFacts {
        let role = json.object("user")?.str("role") ?? ""
        let lock = json.object("capabilities")?.object("security")?.str("client.device_lock") ?? ""
        return SessionFacts(role: role, deviceLock: lock.isEmpty ? "user" : lock)
    }
    public var canChange: Bool { role == "admin" || role == "operator" }
    public var isAdmin: Bool { role == "admin" }
}

// MARK: status

public struct TargetPoint: Equatable, Sendable { public let x: Double; public let y: Double }

public struct FieldNode: Equatable, Sendable, Identifiable {
    public let id: String
    public let online: Bool
    public let lux: Double?
    public let targetCount: Int
    public let alertLevel: String
    public let stale: Bool
}

public struct ArmorSnapshot: Equatable, Sendable {
    public var mode: String = "disarmed"
    public var revision: Int = 0
    public var updatedAt: String = ""
    public var nodes: [FieldNode] = []
    /// The arming mode in force ("disarmed", "away", "home", "night") while the server has the arming modes on; nil otherwise.
    public var armingMode: String?
    public var armed: Bool { mode == "armed" }

    public static func parse(_ root: JSON) -> ArmorSnapshot {
        let nodeObject = root.object("nodes") ?? [:]
        let nodes = nodeObject.keys.sorted().compactMap { id -> FieldNode? in
            guard let node = nodeObject[id] as? JSON else { return nil }
            return FieldNode(id: id, online: node.bool("online"), lux: node.double("lux"), targetCount: node.int("target_count"),
                             alertLevel: node.str("alert_level", "normal"), stale: node.bool("stale"))
        }
        let armingMode = root.str("arming_mode")
        return ArmorSnapshot(mode: root.str("mode", "disarmed"), revision: root.int("revision"), updatedAt: root.str("updated_at"), nodes: nodes, armingMode: armingMode.isEmpty ? nil : armingMode)
    }
}

// MARK: alarms and history

public struct Alarm: Equatable, Sendable, Identifiable {
    public let id: String
    public let sourceType: String
    public let sourceId: String
    public let severity: String
    public let code: String
    public let raisedAt: String
    public let acknowledgedBy: String?
    public let cleared: Bool
    public var acknowledged: Bool { acknowledgedBy != nil }

    public static func parse(_ json: JSON) -> Alarm? {
        let id = json.str("id")
        guard let source = json.object("source"), !id.isEmpty, !source.str("id").isEmpty else { return nil }
        if AlarmPolicy.isSilent(json.str("code")) { return nil }   // the alarm of a duress PIN is not listed nor counted on a phone
        let by: String? = json.has("acknowledged_at") ? (json.str("acknowledged_by").isEmpty ? "?" : json.str("acknowledged_by")) : nil
        return Alarm(id: id, sourceType: source.str("type"), sourceId: source.str("id"), severity: json.str("severity", "warning"),
                     code: json.str("code"), raisedAt: json.str("raised_at"), acknowledgedBy: by, cleared: json.has("cleared_at"))
    }
}

public struct ArmorEvent: Equatable, Sendable, Identifiable {
    public let id: Int
    public let at: String
    public let type: String
    public let subject: String
    public let from: String?
    public let to: String?
    public let targets: Int?
    public let mode: String?
    public var severity: String? = nil
    public var code: String? = nil
    public var sourceType: String? = nil
    public var field: String? = nil

    static let known: Set<String> = ["alert", "node", "camera", "mode", "device", "alarm"]

    /// An event from the server's JSON, or nil when it is not a well-formed known event (never trusted blindly).
    public static func parse(_ json: JSON) -> ArmorEvent? {
        let id = json.int("id", -1)
        let type = json.str("type")
        if id < 1 || !known.contains(type) { return nil }
        if type == "alarm", AlarmPolicy.isSilent(json.str("code")) { return nil }
        let subject: String
        switch type {
        case "node", "alert": subject = json.str("node_id")
        case "camera": subject = json.str("camera_id")
        case "device": subject = json.str("device_id")
        case "alarm": subject = json.str("source")
        default: subject = ""
        }
        if type != "mode", subject.isEmpty { return nil }
        func text(_ key: String) -> String? {
            guard json.has(key) else { return nil }
            if let value = json[key] as? String { return value.isEmpty ? nil : value }
            if let value = json[key] { return "\(value)" }
            return nil
        }
        switch type {
        case "alarm":
            return ArmorEvent(id: id, at: json.str("at"), type: type, subject: subject, from: nil, to: text("state"), targets: nil, mode: nil,
                              severity: text("severity"), code: text("code"), sourceType: text("source_type"))
        case "device":
            return ArmorEvent(id: id, at: json.str("at"), type: type, subject: subject, from: text("from"), to: text("to"), targets: nil, mode: nil, code: text("kind"), field: text("field"))
        default:
            return ArmorEvent(id: id, at: json.str("at"), type: type, subject: subject, from: text("from"), to: text("to"),
                              targets: json.has("targets") ? json.int("targets") : nil, mode: text("mode"))
        }
    }
}

// MARK: preflight

public struct PreflightIssue: Equatable, Sendable {
    public let kind: String, level: String, code: String, id: String
    public let detail: String?
    public var blocks: Bool { level == "block" }
}

public struct Preflight: Equatable, Sendable {
    public let ready: Bool
    public let issues: [PreflightIssue]
    public var blocking: Int { issues.filter(\.blocks).count }

    public static func parse(_ root: JSON) -> Preflight {
        let issues = root.objects("issues").compactMap { item -> PreflightIssue? in
            let code = item.str("code")
            if code.isEmpty { return nil }
            let detail = item.str("detail")
            return PreflightIssue(kind: item.str("kind"), level: item.str("level", "warn"), code: code, id: item.str("id"), detail: detail.isEmpty ? nil : detail)
        }
        return Preflight(ready: root.bool("ready") && !issues.contains { $0.blocks }, issues: issues)
    }

    public static func describe(_ issue: PreflightIssue, _ t: Translator) -> String {
        switch issue.code {
        case "node_offline": return t.trf("El nodo de radar %s no responde.", issue.id)
        case "panel_silent": return t.trf("La central de alarma %s está en silencio.", issue.id)
        case "zone_open": return t.trf("La zona %s de la central %s está abierta.", issue.detail ?? "", issue.id)
        case "camera_down": return t.trf("La cámara %s no responde.", issue.id)
        case "opening_open": return t.trf("La puerta o ventana %s está abierta.", issue.id)
        case "device_offline": return t.trf("El dispositivo %s dejó de responder.", issue.id)
        case "alarm_unseen": return t.trf("Hay una alarma que nadie ha visto (%s).", issue.id)
        default: return issue.code
        }
    }
}

// MARK: alarm panels

public struct AlarmZoneView: Equatable, Sendable, Identifiable {
    public let id: String, name: String, kind: String, state: String
    public let bypassed: Bool
    public var title: String { name.isEmpty ? id : name }
}

public struct AlarmPanelView: Equatable, Sendable, Identifiable {
    public var id: String { nodeId }
    public let nodeId: String
    public let stale: Bool
    /// "disarmed", "exit_delay", "armed", "entry_delay" or "alarm".
    public let phase: String
    /// "disarmed", "away" or "stay".
    public let mode: String
    public let siren: Bool, lockedOut: Bool, commandsEnabled: Bool
    public let zones: [AlarmZoneView]
    public let openZones: [String]
    public let armProfiles: Bool
    public let profile: String?
    public var sounding: Bool { phase == "alarm" }
    public var guarding: Bool { phase == "armed" || phase == "exit_delay" || phase == "entry_delay" }
}

public struct ArmProfileView: Equatable, Sendable, Identifiable {
    public let id: String, name: String, base: String
    public var stay: Bool { base == "stay" }
}

public enum AlarmPanelsParser {
    public static func panels(_ root: JSON) -> [AlarmPanelView] {
        root.objects("nodes").compactMap { json in
            let id = json.str("node_id")
            guard let state = json.object("state"), !id.isEmpty else { return nil }
            let zones = state.objects("zones").compactMap { zone -> AlarmZoneView? in
                let zid = zone.str("id")
                if zid.isEmpty { return nil }
                return AlarmZoneView(id: zid, name: zone.str("name"), kind: zone.str("kind", "instant"), state: zone.str("state", "normal"), bypassed: zone.bool("bypassed"))
            }
            let open = (state["open_zones"] as? [Any])?.compactMap { $0 as? String }.filter { !$0.isEmpty } ?? []
            let profile = state.str("profile")
            return AlarmPanelView(nodeId: id, stale: json.bool("stale"), phase: state.str("phase", "disarmed"), mode: state.str("mode", "disarmed"),
                                  siren: state.bool("siren"), lockedOut: state.bool("locked_out"), commandsEnabled: state.bool("commands_enabled"),
                                  zones: zones, openZones: open, armProfiles: state.bool("arm_profiles"), profile: profile.isEmpty ? nil : profile)
        }
    }

    public static func profiles(_ root: JSON) -> [ArmProfileView] {
        root.objects("profiles").compactMap { item in
            let id = item.str("id"), name = item.str("name"), base = item.str("base")
            if id.isEmpty || name.isEmpty || (base != "away" && base != "stay") { return nil }
            return ArmProfileView(id: id, name: name, base: base)
        }
    }

    /// Whether the server may command the panels at all.
    public static func commandsEnabled(_ root: JSON) -> Bool { root.bool("enabled") }
}

// MARK: the arming modes of the server (Away, Home, Night)

/// GET /api/v1/alarm/modes. `enabled` is false until an administrator turns the modes on in Studio (then the app arms and disarms as it always did); `current` is "disarmed", "away",
/// "home" or "night"; `available` is what can be asked; `unassigned` the modes that defend nothing yet; `defended` how many references Home and Night mark.
public struct ArmingModesView: Equatable, Sendable {
    public static let armed = ["away", "home", "night"]
    public var enabled = false
    public var current = "disarmed"
    public var available: [String] = []
    public var unassigned: [String] = []
    public var downgradePinRequired = true
    public var defended: [String: Int] = [:]
    public init() {}
    /// The armed modes that can be asked for, in the order Away, Home, Night.
    public var armable: [String] { Self.armed.filter { available.contains($0) } }

    public static func parse(_ root: JSON) -> ArmingModesView {
        let known = ["disarmed", "away", "home", "night"]
        func strings(_ key: String) -> [String] { ((root[key] as? [Any]) ?? []).compactMap { $0 as? String }.filter { !$0.isEmpty } }
        var view = ArmingModesView()
        view.enabled = root.bool("enabled")
        let current = root.str("current", "disarmed")
        view.current = known.contains(current) ? current : "disarmed"
        view.available = strings("available").filter { known.contains($0) }
        view.unassigned = strings("unassigned")
        view.downgradePinRequired = root.bool("downgrade_pin_required", true)
        let modes = root.object("modes")
        for mode in ["home", "night"] { view.defended[mode] = ((modes?.object(mode)?["defends"] as? [Any]) ?? []).count }
        return view
    }
}

/// The words of the arming modes of the server.
public enum ArmingText {
    public static func name(_ mode: String, _ t: Translator) -> String {
        switch mode {
        case "away": return t.tr("Modo fuera de casa")
        case "home": return t.tr("Modo en casa")
        case "night": return t.tr("Modo noche")
        default: return t.tr("Desarmado")
        }
    }
    /// What the picker says under each mode.
    public static func defends(_ view: ArmingModesView, _ mode: String, _ t: Translator) -> String {
        if mode == "away" { return t.tr("defiende todo") }
        if view.unassigned.contains(mode) { return t.tr("aún nada asignado") }
        return t.trf("%d marcados", view.defended[mode] ?? 0)
    }
    /// The refusal of a mode in words.
    public static func refusal(_ code: String, _ t: Translator) -> String {
        switch code {
        case "modes_disabled": return t.tr("Los modos de armado no están activados en el servidor.")
        case "no_zones_assigned": return t.tr("Ese modo no tiene nada asignado: no se armó.")
        case "wrong_pin": return t.tr("El PIN no es correcto")
        case "pin_locked": return t.tr("Demasiados PIN erróneos: espera un poco")
        case "pin_not_set": return t.tr("Este usuario no tiene PIN: lo pone un administrador")
        default: return t.tr("No se pudo cambiar el modo.")
        }
    }
    /// The refusals the picker answers by asking something more: the confirmation of a mode with nothing assigned, or the PIN.
    public static func isAskable(_ code: String) -> Bool { ["no_zones_assigned", "wrong_pin", "pin_locked", "pin_not_set"].contains(code) }
}

// MARK: cameras

public struct CameraView: Equatable, Sendable, Identifiable {
    public let id: String, name: String
    public let liveVideoAvailable: Bool
    /// "split": the stream carries two lenses, one above the other, and the app shows them in two windows (see `withLensWindows`).
    public let layout: String?
    /// Which part of the picture a window shows: all of it, or the upper or the lower lens of a camera with two lenses in one stream.
    public let lens: LensHalf
    /// The real camera behind a window (the identifier the server knows).
    public let sourceId: String?

    public init(id: String, name: String, liveVideoAvailable: Bool, layout: String? = nil, lens: LensHalf = .whole, sourceId: String? = nil) {
        self.id = id; self.name = name; self.liveVideoAvailable = liveVideoAvailable; self.layout = layout; self.lens = lens; self.sourceId = sourceId
    }

    /// The identifier that the server knows for a camera of the list: what the stream, the snapshot and the movement ask for.
    public var serverId: String { sourceId ?? id }

    public static func parse(_ root: JSON) -> [CameraView] {
        root.objects("cameras").compactMap { camera in
            let id = camera.str("id")
            if id.isEmpty { return nil }
            let layout = camera.str("layout")
            return CameraView(id: id, name: camera.str("name", id), liveVideoAvailable: camera.bool("liveVideoAvailable"), layout: layout.isEmpty ? nil : layout)
        }
    }
}

public struct CameraHealth: Equatable, Sendable { public let id: String, status: String }

// MARK: devices

public struct SiteDevice: Equatable, Sendable, Identifiable {
    public let id: String, name: String, kind: String
    public let canCommand: Bool, online: Bool
    public let risk: String
    public let state: [String: Bool]

    public static func parse(_ root: JSON) -> [SiteDevice] {
        root.objects("devices").compactMap { json in
            let id = json.str("id")
            if id.isEmpty { return nil }
            var state: [String: Bool] = [:]
            for (key, value) in json.object("state") ?? [:] { if let flag = value as? Bool { state[key] = flag } }
            let name = json.str("name", id)
            return SiteDevice(id: id, name: name.isEmpty ? id : name, kind: json.str("kind"), canCommand: json.bool("can_command"), online: json.bool("online"),
                              risk: json.str("risk", "low").isEmpty ? "low" : json.str("risk", "low"), state: state)
        }
    }
}

// MARK: voice

public struct VoiceReply: Equatable, Sendable {
    public let accepted: Bool
    public let executed: Bool
    public let intent: String?
    /// `accepted`, `confirmation-needed`, `confirmation-refused` or `not-understood`.
    public let outcome: String
    public let speech: String
    public let confirmationToken: String?

    public static func parse(_ root: JSON) -> VoiceReply {
        let intent = root.str("intent"), token = root.str("confirmation_token")
        return VoiceReply(accepted: root.bool("accepted"), executed: root.bool("executed"), intent: intent.isEmpty ? nil : intent,
                          outcome: root.str("outcome"), speech: root.str("speech"), confirmationToken: token.isEmpty ? nil : token)
    }

    /// The sentence the person sees, with the question when the phrase must be confirmed.
    public func line(_ t: Translator) -> String {
        switch outcome {
        case "confirmation-needed":
            let question: String
            switch intent {
            case "arm": question = t.tr("¿Armo el sistema?")
            case "disarm": question = t.tr("¿Desarmo el sistema?")
            default: question = t.tr("¿Lo hago?")
            }
            return "\(speech). \(question)"
        case "not-understood": return t.tr("No lo he entendido. Di «ayuda» para saber qué puedo hacer.")
        default: return speech
        }
    }
}
