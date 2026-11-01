// ARMOR-IOS-CONTROL - writing to a Pylontech battery through its gateway node, as the server reports it: the operations that were ordered, how far each one is and how it ended.
// The app offers only the simple operations; the limits, the firmware and the expert console are done in Studio. The service password of the battery is not here and never reaches the phone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct BatteryDiff: Equatable, Sendable {
    public let label: String
    public let before: String
    public let after: String
}

public struct BatteryOperationView: Equatable, Sendable, Identifiable {
    public let id: String, node: String
    public let port: Int
    public let op: String, actor: String, updatedAt: String, stage: String, summary: String, risk: String
    public let atomic: Bool
    public let canonical: String, model: String, serial: String, softVersion: String, refusal: String, outcome: String, code: String
    public let stepsDone: Int, stepsTotal: Int, packetsSent: Int, packetsTotal: Int
    public let diff: [BatteryDiff]
    public let armedUntil: String
    public let restorable: Bool

    /// Still on its way: the screen asks the server again.
    public var active: Bool { BatteryOperationView.activeStages.contains(stage) }
    public var percent: Int {
        if stage == "done" { return 100 }
        if packetsTotal > 0 { return packetsSent * 100 / packetsTotal }
        if stepsTotal > 0 { return stepsDone * 100 / stepsTotal }
        return 0
    }
    public static let activeStages: Set<String> = ["arming", "armed", "starting", "running"]
}

public struct BatteryOverview: Equatable, Sendable {
    public var enabled = false
    public var operations: [BatteryOperationView] = []
    public init(enabled: Bool = false, operations: [BatteryOperationView] = []) { self.enabled = enabled; self.operations = operations }
}

public enum BatteryParser {
    /// The operations the phone offers: the ones that need no more than a choice. The rest are done in Studio, where the values can be checked on a larger screen.
    public static let phoneOperations: [String] = ["set_clock", "clear_stats", "clear_log", "restart", "shutdown", "soc_capacity", "mosfail_test", "fault_clear", "output_set"]
    public static let outputs: [String] = ["cfet", "dfet", "buzz", "heat"]

    public static func operation(_ root: JSON) -> BatteryOperationView {
        let battery = root.object("battery") ?? [:]
        let diff = root.objects("diff").map { BatteryDiff(label: $0.str("label"), before: $0.str("before"), after: $0.str("after")) }
        return BatteryOperationView(id: root.str("id"), node: root.str("node"), port: root.int("port"), op: root.str("op"), actor: root.str("actor"), updatedAt: root.str("updated_at"), stage: root.str("stage"),
                                    summary: root.str("summary"), risk: root.str("risk"), atomic: root.bool("atomic"), canonical: root.str("canonical"), model: battery.str("model"), serial: battery.str("serial"),
                                    softVersion: battery.str("soft_version"), refusal: root.str("refusal"), outcome: root.str("outcome"), code: root.str("code"), stepsDone: root.int("steps_done"),
                                    stepsTotal: root.int("steps_total"), packetsSent: root.int("packets_sent"), packetsTotal: root.int("packets_total"), diff: diff, armedUntil: root.str("armed_until"),
                                    restorable: root.object("restore") != nil)
    }

    public static func overview(_ root: JSON) -> BatteryOverview {
        BatteryOverview(enabled: root.bool("enabled"), operations: root.objects("operations").map(operation).filter { !$0.id.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    /// The nodes whose batteries report: where an operation can be ordered.
    public static func nodes(_ solar: SolarOverview?) -> [String] {
        Array(Set((solar?.devices ?? []).filter { $0.battery != nil }.map(\.nodeId))).sorted()
    }

    /// A serial number as the node takes it: 10 to 24 letters, digits, - or _ ; NOSERIAL for a battery that has none yet.
    public static func serialLooksRight(_ text: String) -> Bool {
        text == "NOSERIAL" || text.range(of: #"^[A-Za-z0-9_-]{10,24}$"#, options: .regularExpression) != nil
    }
}

/// The wording of the battery maintenance, in the language of the app (the source phrase is Spanish).
public enum BatteryText {
    public static func operationName(_ op: String, _ t: Translator) -> String {
        switch op {
        case "set_clock": return t.tr("Poner en hora el reloj")
        case "clear_stats": return t.tr("Borrar los contadores de estadísticas")
        case "clear_log": return t.tr("Borrar el registro")
        case "restart": return t.tr("Reiniciar el sistema de la batería")
        case "shutdown": return t.tr("Apagar la batería")
        case "soc_capacity": return t.tr("Escribir la capacidad total")
        case "mosfail_test": return t.tr("Activar la prueba de fallo de MOSFET")
        case "fault_clear": return t.tr("Borrar el fallo de fusible")
        case "output_set": return t.tr("Conmutar una salida")
        default: return t.tr("Otra operación (en Studio)")
        }
    }

    public static func outputName(_ output: String, _ t: Translator) -> String {
        switch output {
        case "cfet": return t.tr("MOSFET de carga")
        case "dfet": return t.tr("MOSFET de descarga")
        case "buzz": return t.tr("Zumbador")
        default: return t.tr("Calefacción")
        }
    }

    public static func stageName(_ stage: String, _ t: Translator) -> String {
        switch stage {
        case "arming": return t.tr("Comprobando")
        case "armed": return t.tr("Lista para hacer")
        case "starting": return t.tr("Empezando")
        case "running": return t.tr("En marcha")
        case "done": return t.tr("Terminada")
        case "rejected": return t.tr("Rechazada")
        case "expired": return t.tr("Caducada")
        case "lost": return t.tr("Contacto perdido")
        default: return t.tr("Retirada")
        }
    }

    public static func riskName(_ risk: String, _ t: Translator) -> String {
        switch risk {
        case "low": return t.tr("bajo")
        case "medium": return t.tr("medio")
        case "high": return t.tr("alto")
        default: return t.tr("no se puede deshacer")
        }
    }

    /// What the node or the server refused, in words.
    public static func refusalText(_ code: String, _ t: Translator) -> String {
        switch code {
        case "battery_write_disabled", "disabled": return t.tr("La escritura en baterías está desactivada: en el servidor, o en el panel del propio nodo.")
        case "unknown_node": return t.tr("Ninguna batería de ese nodo está informando.")
        case "invalid_request", "invalid_params": return t.tr("Revisa el nodo, el puerto, la operación y el número de serie.")
        case "busy": return t.tr("Otra operación en esta batería sigue en marcha.")
        case "serial_mismatch": return t.tr("Ese no es el número de serie que informa la batería de este puerto: puerto o batería equivocados.")
        case "serial_unreadable": return t.tr("La batería no tiene número de serie legible: escribe NOSERIAL solo en las operaciones que lo permiten.")
        case "not_armed", "expired", "bad_token": return t.tr("Prepara la operación de nuevo.")
        case "mqtt_unavailable": return t.tr("El broker no está conectado, así que no se pudo enviar la orden.")
        case "rate_limited": return t.tr("Demasiadas órdenes en un minuto. Espera un poco.")
        case "no_password": return t.tr("El nodo no tiene guardada la contraseña de servicio de las baterías.")
        case "login_failed": return t.tr("La batería no aceptó la contraseña de servicio guardada en el nodo.")
        case "not_idle": return t.tr("La batería está cargando o descargando: espera a que la corriente sea casi cero.")
        case "critical_alarm": return t.tr("La batería tiene una alarma o protección activa: solo se permiten recuperaciones.")
        case "cooldown": return t.tr("Se acaba de escribir algo: espera medio minuto.")
        case "locked": return t.tr("Varios intentos erróneos: el nodo rechaza toda orden durante cinco minutos.")
        case "no_battery", "not_pylontech": return t.tr("No hay una batería Pylontech respondiendo en ese puerto.")
        case "no_answer", "preflight_failed": return t.tr("El nodo no pudo leer la batería a tiempo.")
        case "clock_not_set": return t.tr("El nodo aún no sabe la hora, así que no puede poner en hora la batería.")
        case "no_official_value": return t.tr("El fabricante no da una capacidad para este modelo.")
        default: return t.tr("El nodo rechazó la operación.")
        }
    }

    /// The sentence for a failure of a call: the code the server gave, or a general one.
    public static func errorText(_ error: Error, _ t: Translator) -> String {
        if let api = error as? ArmorApiError { return refusalText(api.code, t) }
        return t.tr("No se pudo completar.")
    }

    public static func resultText(_ operation: BatteryOperationView, _ t: Translator) -> String {
        switch operation.outcome {
        case "ok": return t.tr("Funcionó: lo escrito se volvió a leer y coincide.")
        case "partial": return t.tr("Se detuvo a medias: la batería puede haber quedado a medio cambiar. Mira la transcripción en Studio antes de hacer nada más.")
        case "retry": return t.tr("La batería no respondió y no se escribió nada: puedes volver a intentarlo.")
        case "rejected": return t.tr("No se hizo nada: el nodo lo rechazó.")
        default: return t.tr("La lectura posterior no coincide, o falló un paso antes de escribir nada. Mira el estado real en Studio antes de hacer nada más.")
        }
    }
}
