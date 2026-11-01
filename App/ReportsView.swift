// ARMOR-IOS-CONTROL - the reports of the server for administrators and operators: the summary of a day and the activity heat map of a camera.
// Each is off in the server until an administrator turns it on, and a refusal is told in words that say what to do. Nothing is invented when a report fails.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import UIKit
import ArmorCore

@MainActor
final class ReportsState: ObservableObject {
    @Published var summary: DailySummaryView?
    @Published var summaryRefusal: String?
    @Published var summaryBusy = false
    @Published var heatmap: HeatmapView?
    @Published var heatmapRefusal: String?
    @Published var heatmapBusy = false
    @Published var cameras: [CameraView] = []

    func loadCameras(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        cameras = (try? await model.controller.api.cameraViews(origin)) ?? cameras
    }

    func loadSummary(model: AppModel, date: String) async {
        guard let origin = model.activeOrigin else { return }
        summary = nil; summaryRefusal = nil
        guard ReportsParser.validDate(date) else { summaryRefusal = ReportRefusal.phrase(status: 422, error: "invalid_date"); return }
        summaryBusy = true
        defer { summaryBusy = false }
        let language = ReportsParser.languages.contains(model.language) ? model.language : "en"
        do { summary = try await model.controller.api.dailySummary(origin, date: date, language: language) }
        catch { summaryRefusal = ReportRefusal.phrase(for: error) }
    }

    func loadHeatmap(model: AppModel, camera: String?) async {
        guard let origin = model.activeOrigin else { return }
        heatmap = nil; heatmapRefusal = nil; heatmapBusy = true
        defer { heatmapBusy = false }
        do { heatmap = try await model.controller.api.heatmap(origin, camera: camera) }
        catch { heatmapRefusal = ReportRefusal.phrase(for: error) }
    }
}

struct ReportsView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var reports = ReportsState()
    @State private var date = Self.today()
    @State private var camera = ""

    static func today() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func findingName(_ kind: String) -> String {
        switch kind {
        case "hourly_repeat": return model.tr("La misma alarma a la misma hora cada hora")
        case "intermittent_sensor": return model.tr("Un sensor que falla a ratos")
        case "intermittent_link": return model.tr("Un nodo que pierde el enlace una y otra vez")
        case "recurrent_false_alarm": return model.tr("Una zona con falsas alarmas repetidas")
        case "anomalous_consumption": return model.tr("Consumo muy por encima de lo habitual")
        default: return kind
        }
    }

    private func findingLine(_ finding: ReportFinding) -> String { "• " + findingName(finding.kind) + " - " + finding.subject + " (" + model.trf("%s veces", finding.count) + ")" }
    private func noteLine(_ note: String) -> String { model.tr("Nota de la IA:") + " " + note }

    var body: some View {
        List {
            Section { Text(model.tr("Para administradores y operadores. Cada informe está apagado hasta que un administrador lo enciende en Seguridad, en Studio; es para que lo lea una persona y no cambia nada.")).font(.footnote).foregroundColor(Theme.muted) }
                .listRowBackground(Theme.surface)
            Section(header: Text(model.tr("Resumen de un día"))) {
                TextField(model.tr("Día (AAAA-MM-DD)"), text: $date).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.numbersAndPunctuation)
                Button(reports.summaryBusy ? model.tr("Cargando…") : model.tr("Mostrar")) { Task { await reports.loadSummary(model: model, date: date) } }.disabled(reports.summaryBusy)
                if let refusal = reports.summaryRefusal { Text(model.tr(refusal)).foregroundColor(Theme.danger) }
                if let summary = reports.summary {
                    HStack {
                        total(model.tr("Eventos"), summary.events); total(model.tr("Alarmas"), summary.alarms)
                        total(model.tr("Alarmas graves"), summary.serious); total(model.tr("Falsas alarmas"), summary.falseAlarms)
                    }
                    Text(summary.text).font(.body)
                    if !summary.findings.isEmpty {
                        Text(model.tr("Patrones encontrados")).font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(Array(summary.findings.enumerated()), id: \.offset) { _, finding in
                            Text(findingLine(finding)).font(.footnote)
                        }
                    }
                    if let note = summary.aiNote { Text(noteLine(note)).font(.footnote).foregroundColor(Theme.muted) }
                    Text(model.tr("Hecho con las alarmas que guardó el servidor, los enlaces perdidos, las falsas alarmas y, si el registro diario está activo, las lecturas y el consumo de la casa. Ningún nombre, texto ni dirección de la casa llega a la IA.")).font(.caption).foregroundColor(Theme.muted)
                }
            }.listRowBackground(Theme.surface)
            Section(header: Text(model.tr("Mapa de calor de actividad")), footer: Text(model.tr("Dónde se vio actividad en la escena de una cámara: solo posiciones contadas, nunca una imagen de nadie. Viene del servicio de visión en vivo."))) {
                Picker(model.tr("Cámara"), selection: $camera) {
                    Text(model.tr("La única / la primera")).tag("")
                    ForEach(reports.cameras) { item in Text(item.name.isEmpty ? item.id : item.name).tag(item.id) }
                }
                Button(reports.heatmapBusy ? model.tr("Cargando…") : model.tr("Mostrar")) { Task { await reports.loadHeatmap(model: model, camera: camera.isEmpty ? nil : camera) } }.disabled(reports.heatmapBusy)
                if let refusal = reports.heatmapRefusal { Text(model.tr(refusal)).foregroundColor(Theme.danger) }
                if let map = reports.heatmap {
                    if let data = map.png, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().interpolation(.none).aspectRatio(contentMode: .fit).accessibilityLabel(model.trf("Mapa de calor de la cámara %s", map.cameraId))
                    }
                    Text(model.trf("%s: %s posiciones contadas en una rejilla de %s x %s.", map.cameraId, map.positions, map.cols, map.rows)).font(.caption).foregroundColor(Theme.muted)
                }
            }.listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Informes"))
        .task { await reports.loadCameras(model: model) }
    }

    private func total(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2).foregroundColor(Theme.muted)
            Text(String(value)).font(.title3).bold()
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}
