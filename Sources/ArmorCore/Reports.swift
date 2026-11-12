// ARMOR-IOS-CONTROL - the two reports of the server for administrators and operators: the summary of a day and the activity heat map of a camera.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// A pattern the summary found: what kind, about what (a code and a zone, a node, a zone) and how many times.
public struct ReportFinding: Equatable, Sendable {
    public let kind: String
    public let subject: String
    public let count: Int
}

/// The summary of one day, as the server made it: the counts, the readable text in the language asked and, only when the settings turn it on, the note of the AI.
public struct DailySummaryView: Equatable, Sendable {
    public let date: String
    public let language: String
    public let events: Int
    public let alarms: Int
    public let serious: Int
    public let falseAlarms: Int
    public let text: String
    public let findings: [ReportFinding]
    public let aiNote: String?
}

/// The heat map of a camera: the grid it was counted on and the picture (PNG bytes) when it came. Only counted positions: never a picture of anybody.
public struct HeatmapView: Equatable, Sendable {
    public let cameraId: String
    public let cols: Int
    public let rows: Int
    public let positions: Int
    public let png: Data?
}

public enum ReportsParser {
    public static let languages = ["en", "es", "de", "fr", "it", "ja", "zh", "pt"]

    /// The summary of a day. A document that is the message `daily_summary` of the shared contract (an unknown member is ignored) is read through it; anything else is read by the
    /// tolerant reader below, so a summary the contract does not describe still shows what it has.
    public static func summary(_ json: JSON) -> DailySummaryView {
        if let message = Contract.parseTolerant("daily_summary", json) as? Contract.DailySummary {
            let findings = message.findings.map { item -> ReportFinding in
                let about = [item.subject.code, item.subject.zone, item.subject.node].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " / ")
                return ReportFinding(kind: item.kind, subject: about.isEmpty ? "-" : about, count: Int(item.count))
            }
            let totals = message.summary.totals
            return DailySummaryView(date: message.date, language: message.language, events: Int(totals.events), alarms: Int(totals.alarms), serious: Int(totals.serious_alarms),
                                    falseAlarms: Int(totals.false_alarms), text: message.text, findings: findings, aiNote: (message.ai_note ?? "").isEmpty ? nil : message.ai_note)
        }
        return legacySummary(json)
    }

    private static func legacySummary(_ json: JSON) -> DailySummaryView {
        let totals = json.object("summary")?.object("totals")
        let findings: [ReportFinding] = json.objects("findings").map { item in
            let subject = item.object("subject")
            let about = ["code", "zone", "node"].compactMap { key -> String? in
                let value = subject?.str(key) ?? ""
                return value.isEmpty ? nil : value
            }.joined(separator: " / ")
            return ReportFinding(kind: item.str("kind"), subject: about.isEmpty ? "-" : about, count: item.int("count"))
        }
        let note = json.str("ai_note")
        return DailySummaryView(date: json.str("date"), language: json.str("language"), events: totals?.int("events") ?? 0, alarms: totals?.int("alarms") ?? 0,
                                serious: totals?.int("serious_alarms") ?? 0, falseAlarms: totals?.int("false_alarms") ?? 0, text: json.str("text"), findings: findings, aiNote: note.isEmpty ? nil : note)
    }

    public static func heatmap(_ json: JSON, png: Data?) -> HeatmapView {
        if let message = Contract.parseTolerant("heatmap", json) as? Contract.Heatmap {
            return HeatmapView(cameraId: message.camera_id, cols: Int(message.cols), rows: Int(message.rows), positions: Int(message.accepted_positions), png: png)
        }
        return HeatmapView(cameraId: json.str("camera_id"), cols: json.int("cols"), rows: json.int("rows"), positions: json.int("accepted_positions"), png: png)
    }

    /// A day as YYYY-MM-DD that is a real day from the year 2000 (what the server accepts).
    public static func validDate(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return false }
        guard year >= 2000, (1...12).contains(month), day >= 1 else { return false }
        let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let longest = month == 2 ? (leap ? 29 : 28) : [4, 6, 9, 11].contains(month) ? 30 : 31
        return day <= longest
    }
}

/// Why a report was refused, as the Spanish phrase of the app (the key of its table) that says what to do.
public enum ReportRefusal {
    public static func phrase(status: Int?, error: String) -> String {
        if error == "daily_summary_disabled" { return "El resumen diario está apagado. Un administrador lo enciende en Configuración > Seguridad (\"Resumen de un día\")." }
        if error == "heatmap_disabled" { return "El mapa de calor está apagado. Un administrador lo enciende en Configuración > Seguridad (\"Mapa de calor de actividad\")." }
        if error == "invalid_date" { return "Eso no es un día (usa una fecha real desde el año 2000)." }
        if error == "invalid_language" || error == "invalid_query" { return "El servidor no ha entendido la petición." }
        if error == "unknown_camera" { return "El servicio de visión no conoce esa cámara." }
        if error == "heatmap_pipeline_off" { return "El flujo de actividad está apagado en el servicio de visión, así que no hay mapa." }
        if error == "heatmap_not_configured" { return "El mapa de calor no está configurado: falta la dirección del servicio de visión, es incorrecta o está en otra máquina sin permiso (Configuración > Seguridad)." }
        if error == "daily_summary_not_configured" { return "El resumen diario no está configurado en el servidor (el servicio de resumen y su archivo de ajustes)." }
        if error == "daily_summary_off_in_settings" { return "El propio servicio de resumen tiene el resumen apagado en su archivo de ajustes." }
        if error == "report_busy" { return "El servidor está haciendo otro informe. Inténtalo de nuevo en unos segundos." }
        if error == "daily_summary_failed" || error == "heatmap_failed" || status == 502 { return "No se pudo hacer el informe (el servicio falló o respondió algo que no es un informe). No se ha inventado nada." }
        if status == 429 { return "Demasiadas peticiones este minuto. Espera un poco e inténtalo de nuevo." }
        if status == 401 || status == 403 { return "Solo un administrador o un operador puede pedir los informes." }
        if status == 404 { return "Ese informe está apagado en el servidor." }
        if status == 503 { return "El informe no está configurado en el servidor." }
        if status == nil { return "El servidor no ha respondido. Inténtalo de nuevo en un momento." }
        return "El servidor ha rechazado la petición."
    }

    /// Every phrase this can give, for the tests that keep the translation tables whole.
    public static var all: [String] {
        var seen: [String] = []
        let cases: [(Int?, String)] = [(404, "daily_summary_disabled"), (404, "heatmap_disabled"), (422, "invalid_date"), (422, "invalid_query"), (404, "unknown_camera"), (404, "heatmap_pipeline_off"),
                                       (503, "heatmap_not_configured"), (503, "daily_summary_not_configured"), (503, "daily_summary_off_in_settings"), (503, "report_busy"), (502, "heatmap_failed"),
                                       (429, ""), (403, ""), (404, ""), (503, ""), (nil, ""), (418, "")]
        for (status, error) in cases { let text = phrase(status: status, error: error); if !seen.contains(text) { seen.append(text) } }
        return seen
    }

    public static func phrase(for error: Error) -> String {
        guard let api = error as? ArmorApiError else { return phrase(status: nil, error: "") }
        return phrase(status: api.status, error: api.detail)
    }
}
