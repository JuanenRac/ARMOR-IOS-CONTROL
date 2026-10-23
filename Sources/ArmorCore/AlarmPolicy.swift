// ARMOR-IOS-CONTROL - which events wake the operator, how they read, and the memory that keeps one event from being announced twice.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// `severity` is "critical", "high" or "warning".
public struct AlarmNotice: Equatable, Sendable {
    public let id: Int
    public let title: String
    public let text: String
    public let severity: String
}

public enum AlarmPolicy {
    /// Alarms a phone never announces, shows or counts (the server tells the people who must know in silence).
    public static func isSilent(_ code: String?) -> Bool { code == "duress_disarm" }

    /// The events worth a notification, oldest first: a node reaching HIGH, a camera that stops answering, and (only while armed) a node that goes offline or silent.
    /// An alarm raised by a device, by solar or electrical equipment, by an alarm panel or by a network node always wakes the operator.
    public static func notices(_ events: [ArmorEvent], armed: Bool, _ t: Translator) -> [AlarmNotice] {
        let sources: Set<String> = ["device", "solar", "electrical", "network", "alarm"]
        return events.sorted { $0.id < $1.id }.compactMap { event in
            if isSilent(event.code) { return nil }
            switch true {
            case event.type == "alert" && event.to == "high":
                return AlarmNotice(id: event.id, title: t.tr("ALERTA ALTA"), text: t.trf("%s: %s objetivos", event.subject, event.targets ?? 0), severity: "high")
            case event.type == "camera" && event.to == "offline":
                return AlarmNotice(id: event.id, title: t.tr("Cámara sin respuesta"), text: event.subject, severity: "high")
            case event.type == "node" && armed && event.to == "offline":
                return AlarmNotice(id: event.id, title: t.tr("Nodo fuera de línea"), text: event.subject, severity: "high")
            case event.type == "node" && armed && event.to == "stale":
                return AlarmNotice(id: event.id, title: t.tr("Nodo en silencio"), text: event.subject, severity: "high")
            case event.type == "alarm" && event.to == "raised" && sources.contains(event.sourceType ?? ""):
                let severity = event.severity ?? "warning"
                return AlarmNotice(id: event.id, title: t.trf("ALARMA %s", AlarmText.severityLabel(severity, t)),
                                   text: "\(AlarmText.text(event.code ?? "", t)) · \(event.subject)", severity: severity)
            default: return nil
            }
        }
    }

    private static func level(_ value: String?, _ t: Translator) -> String {
        switch value {
        case "normal": return "normal"
        case "review": return t.tr("revisar")
        case "high": return t.tr("ALTA")
        default: return value ?? ""
        }
    }
    private static func status(_ value: String?, _ t: Translator) -> String {
        switch value {
        case "online": return t.tr("en línea")
        case "offline": return t.tr("fuera de línea")
        case "stale": return t.tr("en silencio")
        case "unknown": return t.tr("desconocido")
        default: return value ?? ""
        }
    }
    private static func alarmState(_ value: String?, _ t: Translator) -> String {
        switch value {
        case "raised": return t.tr("generada")
        case "acknowledged": return t.tr("confirmada")
        case "cleared": return t.tr("cerrada")
        default: return value ?? ""
        }
    }
    private static func fieldLabel(_ field: String?, _ t: Translator) -> String {
        switch field {
        case "triggered": return t.tr("activado")
        case "open": return t.tr("abierto")
        case "on": return t.tr("encendido")
        case "locked": return t.tr("cerrada")
        case "tamper": return t.tr("manipulación")
        case "online": return t.tr("conexión")
        default: return field ?? ""
        }
    }
    private static func value(_ value: String?, _ t: Translator) -> String {
        switch value {
        case "true": return t.tr("sí")
        case "false": return t.tr("no")
        default: return value ?? ""
        }
    }

    /// One line for the history list.
    public static func describe(_ event: ArmorEvent, _ t: Translator) -> String {
        switch event.type {
        case "mode": return event.mode == "armed" ? t.tr("Sistema ARMADO") : t.tr("Sistema DESARMADO")
        case "alert": return t.trf("%s: %s → %s (%s objetivos)", event.subject, level(event.from, t), level(event.to, t), event.targets ?? 0)
        case "camera": return "\(event.subject): \(status(event.from, t)) → \(status(event.to, t))"
        case "alarm": return "\(AlarmText.text(event.code ?? "", t)) · \(event.subject) · \(alarmState(event.to, t))"
        case "device":
            let before = event.from.map { value($0, t) + " → " } ?? ""
            return "\(event.subject): \(fieldLabel(event.field, t)) \(before)\(value(event.to, t))"
        default:
            let before = event.from.map { status($0, t) + " → " } ?? ""
            return "\(event.subject): \(before)\(status(event.to, t))"
        }
    }
}

/// Remembers the newest event already handled so that neither the open app nor a refresh announces the same event twice. The first call only records a baseline: opening the app for the
/// first time must not replay the whole history as alarms. The key is the event id the server gives, which is also what a push carries, so a push and a poll never announce one event twice.
public final class SeenEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var newest: Int?
    public init(newest: Int? = nil) { self.newest = newest }

    public var last: Int? { lock.lock(); defer { lock.unlock() }; return newest }

    /// The events not seen before, oldest first.
    public func fresh(_ events: [ArmorEvent]) -> [ArmorEvent] {
        lock.lock(); defer { lock.unlock() }
        let top = events.map(\.id).max()
        guard let baseline = newest else {
            newest = top ?? 0
            return []
        }
        let unseen = events.filter { $0.id > baseline }.sorted { $0.id < $1.id }
        if let top, top > baseline { newest = top }
        return unseen
    }
}
