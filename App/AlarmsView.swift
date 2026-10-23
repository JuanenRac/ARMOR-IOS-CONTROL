// ARMOR-IOS-CONTROL - the alarms (to confirm), the alarm panels (arm, disarm, silence) and the history.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct AlarmsView: View {
    @EnvironmentObject var model: AppModel
    @State private var section = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $section) {
                    Text(model.tr("Alarmas")).tag(0)
                    Text(model.tr("Centrales de alarma")).tag(1)
                    Text(model.tr("Historial")).tag(2)
                }
                .pickerStyle(.segmented).padding(.horizontal)
                switch section {
                case 0: ActiveAlarms()
                case 1: PanelsList()
                default: HistoryList()
                }
            }
            .background(Theme.background)
            .navigationTitle(model.tr("Alarmas"))
        }
    }
}

struct ActiveAlarms: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        List {
            if model.state.active.isEmpty { Text(model.tr("Sin alarmas")).foregroundColor(Theme.muted) }
            ForEach(model.state.active) { alarm in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Pill(text: AlarmText.severityLabel(alarm.severity, model.translator), color: Theme.severity(alarm.severity))
                        Spacer()
                        Text(alarm.acknowledged ? model.tr("confirmada") : model.tr("Sin confirmar")).font(.caption).foregroundColor(alarm.acknowledged ? Theme.muted : Theme.amber)
                    }
                    Text(AlarmText.text(alarm.code, model.translator))
                    Text("\(alarm.sourceId) · \(alarm.raisedAt)").font(.caption).foregroundColor(Theme.muted)
                    if !alarm.acknowledged, model.state.facts.canChange {
                        Button(model.tr("Confirmar")) { Task { await model.order { _ in try await model.controller.acknowledge(alarm.id) } } }.buttonStyle(.bordered).tint(Theme.accent)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            if model.state.unseenAlarms > 1, model.state.facts.canChange {
                Button(model.tr("Confirmar todas")) { Task { await model.order { _ in try await model.controller.acknowledgeAll() } } }
            }
            if !model.state.recent.isEmpty {
                Section(model.tr("Alarmas confirmadas")) {
                    ForEach(model.state.recent) { alarm in
                        VStack(alignment: .leading) {
                            Text(AlarmText.text(alarm.code, model.translator))
                            Text("\(alarm.sourceId) · \(alarm.raisedAt)").font(.caption).foregroundColor(Theme.muted)
                        }.listRowBackground(Theme.surface)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.refresh() }
    }
}

struct PanelsList: View {
    @EnvironmentObject var model: AppModel
    @State private var target: AlarmPanelView?
    @State private var mode = "away"
    @State private var force = false
    @State private var pin = ""
    @State private var action = ""

    var body: some View {
        List {
            if model.state.panels.isEmpty {
                Text(model.tr("Sin centrales de alarma")).foregroundColor(Theme.muted)
            }
            ForEach(model.state.panels) { panel in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(panel.nodeId).font(.headline)
                        Spacer()
                        Pill(text: phaseText(panel), color: panel.sounding ? Theme.danger : (panel.guarding ? Theme.ok : Theme.muted))
                    }
                    if panel.stale { Text(model.trf("La central de alarma %s está en silencio.", panel.nodeId)).font(.caption).foregroundColor(Theme.amber) }
                    if panel.lockedOut { Text(model.tr("La central de alarma está bloqueada tras PIN erróneos")).font(.caption).foregroundColor(Theme.danger) }
                    ForEach(panel.zones) { zone in
                        HStack {
                            Circle().fill(zone.state == "normal" ? Theme.ok : Theme.danger).frame(width: 8, height: 8)
                            Text(zone.title).font(.callout)
                            if zone.bypassed { Pill(text: "bypass", color: Theme.muted) }
                        }
                    }
                    if model.state.facts.canChange, panel.commandsEnabled, !panel.stale {
                        HStack {
                            if panel.guarding || panel.sounding {
                                Button(model.tr("Desarmar")) { open(panel, "disarm") }
                                if panel.siren || panel.sounding { Button(model.tr("Silenciar la alarma")) { open(panel, "silence") } }
                            } else {
                                Button(model.tr("Armar: fuera")) { Task { await arm(panel, "away") } }
                                Button(model.tr("Armar: en casa")) { Task { await arm(panel, "stay") } }
                            }
                        }.buttonStyle(.bordered).tint(Theme.accent)
                    } else if model.state.facts.canChange, !panel.commandsEnabled {
                        Text(model.tr("Armar desde aquí está apagado en el servidor")).font(.caption).foregroundColor(Theme.muted)
                    }
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.refresh() }
        .alert(action == "silence" ? model.tr("Silenciar la alarma") : model.tr("Desarmar el sistema"), isPresented: Binding(get: { target != nil }, set: { if !$0 { target = nil } })) {
            SecureField(model.tr("PIN (si tienes uno)"), text: $pin).keyboardType(.numberPad)
            Button(action == "silence" ? model.tr("Silenciar la alarma") : model.tr("Sí, desarmar"), role: .destructive) { Task { await send() } }
            Button(model.tr("Cancelar"), role: .cancel) { target = nil }
        }
    }

    private func phaseText(_ panel: AlarmPanelView) -> String {
        switch panel.phase {
        case "alarm": return model.tr("¡ALARMA!")
        case "armed": return model.tr("ARMADO")
        case "exit_delay": return model.tr("Saliendo…")
        case "entry_delay": return model.tr("Entrando…")
        default: return model.tr("Sin armar")
        }
    }

    private func open(_ panel: AlarmPanelView, _ what: String) { pin = ""; action = what; target = panel }

    private func arm(_ panel: AlarmPanelView, _ mode: String) async {
        await model.order(model.trf("%s: orden de armar enviada", panel.nodeId)) { asker in try await model.controller.armPanel(panel.nodeId, mode: mode, force: false, profile: nil, asker: asker) }
    }

    private func send() async {
        guard let panel = target else { return }
        let typed = pin.isEmpty ? nil : pin
        target = nil; pin = ""
        if action == "silence" {
            await model.order(nil) { asker in try await model.controller.silencePanel(panel.nodeId, pin: typed, asker: asker) }
        } else {
            await model.order(model.trf("%s: orden de desarmar enviada", panel.nodeId)) { asker in try await model.controller.disarmPanel(panel.nodeId, pin: typed, asker: asker) }
        }
    }
}

struct HistoryList: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        List {
            if model.state.events.isEmpty { Text(model.tr("Aquí verás los cambios de estado, las alarmas y las órdenes.")).foregroundColor(Theme.muted) }
            ForEach(model.state.events) { event in
                VStack(alignment: .leading) {
                    Text(AlarmPolicy.describe(event, model.translator))
                    Text(event.at).font(.caption).foregroundColor(Theme.muted)
                }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.refresh() }
    }
}
