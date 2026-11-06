// ARMOR-IOS-CONTROL - updating the programs of the machine that runs the server, from the phone, as the server reports it: whether the switch is on (here and on the maintenance helper), the
// programs the helper can update, the preview of one of them (what is installed against the newest release, and a plan that is good once for a few minutes) and the job that the apply starts.
// Nothing here runs a command: the phone only asks, and the server and the helper decide. Only a signed release is ever put in place. The same as the Android app.
// See ARMOR-SERVER src/routes/machine_update.ts.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The switch and the programs. `enabled` is true only when the server and the helper both have it on; `reason` says why not otherwise (switched_off, not_configured, agent_switched_off, not_answering, refused).
public struct MachineUpdateState: Equatable, Sendable {
    public let enabled: Bool, available: Bool, requireSigned: Bool
    public let projects: [String]
    public let reason: String
    public init(enabled: Bool, available: Bool, requireSigned: Bool, projects: [String], reason: String) {
        self.enabled = enabled; self.available = available; self.requireSigned = requireSigned; self.projects = projects; self.reason = reason
    }
}

/// What a program has installed against the newest release; `planId` is present only when an update is available and is good once, for `expiresInS` seconds.
public struct MachineUpdatePreview: Equatable, Sendable {
    public let project: String
    public let installed: Bool
    public let localVersion: String, githubVersion: String, state: String
    public let updateAvailable: Bool
    public let planId: String
    public let expiresInS: Int
}

public struct MachineJobStep: Equatable, Sendable, Identifiable {
    public let id: String, state: String
    public let percent: Double
}

/// The job an apply started, as the maintenance helper reports it: steps with a bar each, a total, the log from a point on and the error when it failed.
public struct MachineJobView: Equatable, Sendable {
    public let id: String, state: String
    public let percent: Double
    public let steps: [MachineJobStep]
    public let error: String
    public let log: [String]
    public let logTotal: Int
    public init(id: String, state: String, percent: Double, steps: [MachineJobStep], error: String, log: [String], logTotal: Int) {
        self.id = id; self.state = state; self.percent = percent; self.steps = steps; self.error = error; self.log = log; self.logTotal = logTotal
    }
    public var running: Bool { state == "running" }
    public var failed: Bool { state == "failed" }
}

public enum MachineUpdateParser {
    /// The lines of the log shown on the screen, so that a long update does not fill it.
    public static let logLines = 400

    /// The names the server accepts for a program: the repository name, for example ARMOR-SERVER.
    public static func isProject(_ name: String) -> Bool { matches(name, #"^ARMOR-[A-Z0-9][A-Z0-9-]{0,39}$"#) }
    /// The plan the preview hands out: 24 lowercase hexadecimal digits.
    public static func isPlan(_ plan: String) -> Bool { matches(plan, #"^[0-9a-f]{24}$"#) }
    /// True for an empty code (the account may not have the second factor) or for six digits.
    public static func codeOk(_ code: String) -> Bool { code.isEmpty || matches(code, #"^[0-9]{6}$"#) }
    /// The name of the program typed again is the confirmation of the apply; it must be exactly the program's.
    public static func confirmationOk(project: String, typed: String) -> Bool { isProject(project) && typed == project }

    private static func matches(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }

    private static func strings(_ value: Any?) -> [String] {
        ((value as? [Any]) ?? []).compactMap { $0 as? String }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static func percent(_ root: JSON) -> Double {
        guard let value = root.double("percent"), !value.isNaN else { return 0 }
        return min(100, max(0, value))
    }

    public static func state(_ root: JSON) -> MachineUpdateState {
        MachineUpdateState(enabled: root.bool("enabled"), available: root.bool("available"), requireSigned: root.bool("require_signed", true),
                           projects: strings(root["projects"]).filter(isProject), reason: root.str("reason"))
    }

    public static func preview(_ root: JSON) -> MachineUpdatePreview {
        let plan = root.str("plan_id")
        return MachineUpdatePreview(project: root.str("project"), installed: root.bool("installed", true), localVersion: root.str("local_version"), githubVersion: root.str("github_version"),
                                    state: root.str("state"), updateAvailable: root.bool("update_available"), planId: isPlan(plan) ? plan : "", expiresInS: root.int("expires_in_s"))
    }

    /// The id of the job an apply started ("202 { id }"); empty when the answer has none.
    public static func startedId(_ root: JSON) -> String { root.str("id") }

    public static func job(_ root: JSON) -> MachineJobView {
        MachineJobView(id: root.str("id"), state: root.str("state", "running"), percent: percent(root),
                       steps: root.objects("steps").map { MachineJobStep(id: $0.str("id"), state: $0.str("state"), percent: percent($0)) }.filter { !$0.id.isEmpty },
                       error: root.str("error"), log: strings(root["log"]), logTotal: root.int("log_total"))
    }

    /// The log with the lines of an answer that starts at `since`: whatever was after that point is replaced and never added twice.
    public static func mergeLog(_ lines: [String], since: Int, fresh: [String]) -> [String] {
        fresh.isEmpty ? lines : Array(lines.prefix(min(max(since, 0), lines.count))) + fresh
    }

    /// The part of a step id after the program ("server.download" is "download").
    public static func stepPart(_ id: String) -> String { id.split(separator: ".", omittingEmptySubsequences: false).last.map(String.init) ?? id }

    /// The seconds left of a plan that was handed out `elapsedMs` ago, never below zero.
    public static func secondsLeft(expiresInS: Int, elapsedMs: Int) -> Int { max(0, expiresInS - max(0, elapsedMs) / 1000) }
}

/// The wording of the update of the machine (the source phrases are Spanish; the translator gives them in the language chosen).
public enum MachineUpdateText {
    /// Why the update is not on, in words. The switch is the owner's: off at the server (ARMOR_CM5_UPDATE) and on the maintenance helper until they turn it on.
    public static func reason(_ reason: String, _ t: Translator) -> String {
        switch reason {
        case "switched_off": return t.tr("La actualización desde el móvil está apagada en el servidor. Se enciende en el servidor, no desde la app.")
        case "not_configured": return t.tr("El servidor no tiene configurado el ayudante de mantenimiento.")
        case "agent_switched_off": return t.tr("El ayudante de mantenimiento tiene la actualización apagada.")
        case "not_answering": return t.tr("El ayudante de mantenimiento no contesta.")
        case "refused": return t.tr("El ayudante de mantenimiento rechazó la consulta.")
        default: return t.tr("La actualización desde el móvil no está disponible.")
        }
    }

    /// The sentence for a refusal of the server on this screen. The 202 of the apply is not a refusal; everything else the server can say has its words.
    public static func refusal(status: Int?, detail: String, _ t: Translator) -> String {
        switch (status, detail) {
        case (403, "machine_update_disabled"): return t.tr("La actualización desde el móvil está apagada en el servidor o en el ayudante de mantenimiento.")
        case (403, _): return t.tr("No se aceptó: puede faltar el código de un solo uso, o la actualización está apagada.")
        case (404, _): return t.tr("El plan ya no existe o ya se usó. Comprueba las versiones otra vez.")
        case (410, _): return t.tr("El plan ha caducado. Comprueba las versiones otra vez.")
        case (409, _): return t.tr("Ya hay otro trabajo en marcha en el equipo.")
        case (422, "confirmation_mismatch"): return t.tr("El nombre escrito no coincide con el del programa.")
        case (422, "bad_code"): return t.tr("El código de un solo uso tiene seis cifras.")
        case (422, "bad_plan"): return t.tr("El plan no es válido. Comprueba las versiones otra vez.")
        case (422, _): return t.tr("Ese programa no está en la lista de los que se pueden actualizar.")
        case (429, _): return t.tr("Se actualizó otro programa hace un momento. Espera unos minutos.")
        case (503, _): return t.tr("El ayudante de mantenimiento no está instalado o no contesta.")
        default: return t.tr("No se pudo completar.")
        }
    }

    /// The sentence for a failure of a call.
    public static func errorText(_ error: Error, _ t: Translator) -> String {
        guard let api = error as? ArmorApiError else { return t.tr("No se pudo completar.") }
        return refusal(status: api.status, detail: api.detail.isEmpty ? api.code : api.detail, t)
    }

    /// A step of the job in words: the part after the program ("server.download" is "download").
    public static func stepName(_ id: String, _ t: Translator) -> String {
        switch MachineUpdateParser.stepPart(id) {
        case "download": return t.tr("Descargar")
        case "verify": return t.tr("Comprobar la firma y el resumen")
        case "install": return t.tr("Instalar")
        case "stage": return t.tr("Probar antes de cambiar")
        case "restart": return t.tr("Reiniciar el servicio")
        case "check": return t.tr("Comprobar que funciona")
        default: return id
        }
    }

    /// The state of a step in words.
    public static func stepState(_ state: String, percent: Double, _ t: Translator) -> String {
        switch state {
        case "done": return t.tr("Hecho")
        case "running": return "\(Int(percent)) %"
        case "skipped": return t.tr("Omitido")
        case "failed": return t.tr("Falló")
        default: return t.tr("Pendiente")
        }
    }
}
