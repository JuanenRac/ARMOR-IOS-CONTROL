// ARMOR-IOS-CONTROL - controlling the nodes from the phone, as the server reports it: the orders given (restart, pause, resume, standby, identify, diagnostics, maintenance), for one node or for
// every node, and the line of each node (sent, acknowledged, applied, back...). The same as the Android app. The token that moves an order never reaches the phone. No operation erases settings
// or credentials or puts a node to deep sleep: the list below is the whole contract. See ARMOR-SERVER src/node_control.ts.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// One node's line of an order: how far it went and, once known, the state the node is in.
public struct ControlLineView: Equatable, Sendable, Identifiable {
    public let nodeId: String, family: String, stage: String, state: String
    public let maintenance: Bool
    public let refusal: String
    public let untilS: Int?, backAfterS: Int?
    public let firmwareBefore: String, firmwareAfter: String
    public let diagnostics: [String: String]
    public var id: String { nodeId }
    /// Over, one way or the other: the screen stops asking.
    public var finished: Bool { NodeControlParser.finalStages.contains(stage) }
}

public struct ControlOperationView: Equatable, Sendable, Identifiable {
    public let id: String, scope: String, operation: String, mode: String
    public let durationS: Int?
    public let actor: String, createdAt: String, updatedAt: String, state: String
    public let nodes: [ControlLineView]
    public var active: Bool { state != "done" }
}

public enum NodeControlParser {
    /// The eight operations of the contract, in the order the screen lists them.
    public static let operations = ["restart", "pause", "resume", "standby", "identify", "diagnostics", "maintenance_on", "maintenance_off"]
    /// The operations that leave the house less guarded or a node out of work: the node's name (or the word, for every node) is typed again.
    public static let needsConfirm: Set<String> = ["restart", "pause", "standby"]
    /// The word typed to give one of those three operations to every node.
    public static let confirmWord = ["restart": "RESTART", "pause": "PAUSE", "standby": "STANDBY"]
    /// Minimum, maximum and default seconds of the operations that take a duration.
    public static let durations: [String: (min: Int, max: Int, standard: Int)] = ["pause": (60, 3600, 3600), "identify": (5, 300, 30), "maintenance_on": (60, 28_800, 3600)]
    public static let finalStages: Set<String> = ["applied", "back", "refused", "no_answer", "not_back"]
    /// The families whose pause or standby leaves the house without protection.
    public static let guards: Set<String> = ["alarm", "radar"]

    /// What has to be typed for this order: the node's name for one node, the word for every node; nil when nothing is asked.
    public static func confirmation(operation: String, nodeId: String?) -> String? {
        if !needsConfirm.contains(operation) { return nil }
        return nodeId ?? confirmWord[operation]
    }

    /// The duration to send: the typed one when it is a number inside the operation's range, nil when the operation takes none or nothing was typed (the server uses its default).
    public static func duration(operation: String, typed: String) -> Int? {
        guard let span = durations[operation], let value = Int(typed.trimmingCharacters(in: .whitespaces)), value >= span.min, value <= span.max else { return nil }
        return value
    }

    /// True when the typed duration is acceptable for the operation: empty (the default is used) or inside its range, and nothing at all for an operation that takes none.
    public static func durationOk(operation: String, typed: String) -> Bool {
        let text = typed.trimmingCharacters(in: .whitespaces)
        guard let span = durations[operation] else { return text.isEmpty }
        if text.isEmpty { return true }
        guard let value = Int(text) else { return false }
        return value >= span.min && value <= span.max
    }

    public static func line(_ root: JSON) -> ControlLineView {
        var found: [String: String] = [:]
        if let diagnostics = root.object("diagnostics") {
            for (key, value) in diagnostics { found[key] = (value as? String) ?? String(describing: value) }
        }
        return ControlLineView(nodeId: root.str("node_id"), family: root.str("family"), stage: root.str("stage"), state: root.str("state"), maintenance: root.bool("maintenance"),
                               refusal: root.str("refusal"), untilS: root.has("until_s") ? root.int("until_s") : nil, backAfterS: root.has("back_after_s") ? root.int("back_after_s") : nil,
                               firmwareBefore: root.str("firmware_before"), firmwareAfter: root.str("firmware_after"), diagnostics: found)
    }

    public static func operation(_ root: JSON) -> ControlOperationView {
        ControlOperationView(id: root.str("id"), scope: root.str("scope"), operation: root.str("operation"), mode: root.str("mode", "now"), durationS: root.has("duration_s") ? root.int("duration_s") : nil,
                             actor: root.str("actor"), createdAt: root.str("created_at"), updatedAt: root.str("updated_at"), state: root.str("state"),
                             nodes: root.objects("nodes").map(line).filter { !$0.nodeId.isEmpty })
    }

    public static func list(_ root: JSON) -> [ControlOperationView] { root.objects("operations").map(operation).filter { !$0.id.isEmpty } }
}

/// The wording of the control of the nodes (the source phrases are Spanish; the translator gives them in the language chosen).
public enum NodeControlText {
    /// The name of an operation. Standby is never described as a power-off.
    public static func operationName(_ operation: String, _ t: Translator) -> String {
        switch operation {
        case "restart": return t.tr("Reiniciar")
        case "pause": return t.tr("Pausar (temporal)")
        case "resume": return t.tr("Reanudar")
        case "standby": return t.tr("Poner en espera (trabajo apagado, sigue conectado)")
        case "identify": return t.tr("Identificar (parpadeo y aviso)")
        case "diagnostics": return t.tr("Pedir un diagnóstico")
        case "maintenance_on": return t.tr("Activar el mantenimiento")
        case "maintenance_off": return t.tr("Terminar el mantenimiento")
        default: return operation
        }
    }

    /// The step of a node's line in words.
    public static func stageName(_ stage: String, _ t: Translator) -> String {
        switch stage {
        case "pending": return t.tr("Pendiente")
        case "armed": return t.tr("Preparada")
        case "sent": return t.tr("Enviada")
        case "acknowledged": return t.tr("El nodo la recibió y se reinicia")
        case "applied": return t.tr("Hecho")
        case "offline": return t.tr("Sin conexión (reiniciando)")
        case "back": return t.tr("De vuelta")
        case "refused": return t.tr("Rechazada")
        case "no_answer": return t.tr("No contestó")
        case "not_back": return t.tr("No volvió a tiempo")
        default: return stage
        }
    }

    /// The state a node is in after an order, in words.
    public static func stateName(_ state: String, maintenance: Bool, _ t: Translator) -> String {
        var parts: [String] = []
        switch state {
        case "running": parts.append(t.tr("En marcha"))
        case "paused": parts.append(t.tr("En pausa"))
        case "standby": parts.append(t.tr("En espera (sigue conectado)"))
        default: break
        }
        if maintenance { parts.append(t.tr("en mantenimiento")) }
        return parts.joined(separator: " · ")
    }

    /// What the server or the node refused, in words.
    public static func refusal(_ code: String, _ t: Translator) -> String {
        switch code {
        case "invalid_request": return t.tr("Revisa la orden: la confirmación, la duración o el modo no son válidos.")
        case "unknown_node": return t.tr("Ese nodo no ha informado todavía.")
        case "busy": return t.tr("Ya hay una orden en marcha para ese nodo.")
        case "node_unavailable": return t.tr("El nodo no ha informado hace un momento.")
        case "no_nodes": return t.tr("Ningún nodo ha informado hace un momento.")
        case "already_in_state": return t.tr("El nodo ya está en ese estado.")
        case "rate_limited": return t.tr("Demasiadas órdenes seguidas (un reinicio por minuto y nodo). Espera un poco.")
        case "mqtt_unavailable": return t.tr("El broker no está conectado, así que no se pudo enviar la orden.")
        case "too_many_nodes": return t.tr("Un reinicio escalonado admite hasta 64 nodos.")
        case "busy_update": return t.tr("El nodo está instalando un firmware.")
        case "busy_upload": return t.tr("El nodo está recibiendo una subida de ficheros.")
        case "busy_slot_copy": return t.tr("El nodo está copiando una versión de su firmware.")
        case "busy_battery": return t.tr("El nodo está haciendo una operación en una batería.")
        case "already_restarting": return t.tr("El nodo ya se está reiniciando.")
        case "not_armed", "invalid_token", "token_expired": return t.tr("El nodo no aceptó la orden a tiempo. Inténtalo de nuevo.")
        case "unavailable": return t.tr("El nodo no puede hacerlo ahora.")
        default: return t.tr("El nodo rechazó la orden.")
        }
    }

    /// The sentence for a failure of a call: the code the server gave, or a general one.
    public static func errorText(_ error: Error, _ t: Translator) -> String {
        if let api = error as? ArmorApiError { return refusal(api.code, t) }
        return t.tr("No se pudo completar.")
    }

    /// The warning to read before an order: what it leaves undone. `guards` says the node (or one of the nodes) is an alarm panel or a radar.
    public static func warning(operation: String, all: Bool, mode: String, guards: Bool, _ t: Translator) -> String? {
        let text: String
        switch operation {
        case "restart":
            if all && mode == "now" { text = t.tr("Con todos a la vez, la casa queda sin vigilar cerca de un minuto. El reinicio escalonado deja la central de alarma la última y es el recomendable.") }
            else if all { text = t.tr("El reinicio escalonado va nodo a nodo, con la central de alarma la última. Cada nodo tarda cerca de un minuto en volver.") }
            else if guards { text = t.tr("El nodo estará fuera de servicio cerca de un minuto: una central de alarma o un radar reiniciado deja la casa sin vigilar mientras tanto.") }
            else { text = t.tr("El nodo estará fuera de servicio cerca de un minuto.") }
        case "pause": text = t.tr("Mientras está en pausa el nodo no hace su trabajo, y se reanuda solo al terminar el tiempo. Sigue conectado.")
        case "standby": text = t.tr("En espera el nodo no hace su trabajo pero sigue conectado y contesta. No se reanuda solo, sigue así aunque se reinicie y hay que reanudarlo desde aquí o desde Studio. No es apagarlo.")
        case "maintenance_on": text = t.tr("En mantenimiento el servidor deja de avisar de que el nodo no responde. No cambia lo que hace el nodo.")
        case "identify": text = t.tr("El nodo parpadea o muestra un aviso. Nunca suena la sirena.")
        case "diagnostics": text = t.tr("Solo lee: no cambia nada en el nodo.")
        case "resume": text = t.tr("El nodo vuelve a su trabajo normal.")
        default: return nil
        }
        if guards && (operation == "pause" || operation == "standby") { return t.tr("Atención: con una central de alarma o un radar así, la casa NO está protegida.") + " " + text }
        return text
    }
}
