// ARMOR-IOS-CONTROL - the detail of one alarm: what happened, where, when, and every fact it carries with its label in the language of the person.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct AlarmDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let alarm: Alarm

    var body: some View {
        NavigationStack {
            List {
                Section {
                    line(model.tr("Gravedad"), AlarmText.severityLabel(alarm.severity, model.translator))
                    line(model.tr("Origen"), alarm.sourceId)
                    line(model.tr("Hora"), alarm.raisedAt)
                    line(model.tr("Estado"), alarm.acknowledged ? model.tr("confirmada") : model.tr("Sin confirmar"))
                    if alarm.falseAlarm == true { line(model.tr("Falsa alarma"), model.tr("sí")) }
                    // what the alarm means and what to check, from the table every client shares; nothing when the code has none
                    if let help = AlarmFacts.help(alarm.code, model.translator.language) { Text(help).font(.footnote).accessibilityLabel(help) }
                }
                Section {
                    let facts = AlarmFacts.rows(alarm.detail, model.translator)
                    if facts.isEmpty { Text(model.tr("Esta alarma no trae más detalles.")).foregroundColor(Theme.muted) }
                    // a fact the table does not know is shown with its key as it came: nothing is hidden
                    ForEach(facts, id: \.key) { fact in line(fact.label, fact.value) }
                } header: {
                    Text(model.tr("Detalles")).accessibilityAddTraits(.isHeader)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(AlarmText.text(alarm.code, model.translator))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(model.tr("Cerrar")) { dismiss() } }
            }
        }
    }

    /// A label above its value, read by VoiceOver as one phrase.
    private func line(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(Theme.muted)
            Text(value)
        }
        .accessibilityElement(children: .combine)
        .listRowBackground(Theme.surface)
    }
}
