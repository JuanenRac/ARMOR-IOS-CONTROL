// ARMOR-IOS-CONTROL - Control of the nodes, for administrators: restart, pause, resume, standby ("work off, still connected"), identify, diagnostics and maintenance, for one node or for all of them,
// and how far each node went. A restart, a pause and a standby ask for the node's name typed again (the word RESTART, PAUSE or STANDBY for all of them); the new proof of identity the server asks
// for is asked by the same sheet as for the other critical actions. Nothing here erases settings or credentials or puts a node to deep sleep. The same screen as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

/// Carries the answer out of the closure an order runs in.
private final class Started: @unchecked Sendable { var value: ControlOperationView? }

@MainActor
final class NodeControlState: ObservableObject {
    @Published var operations: [ControlOperationView] = []
    @Published var active: ControlOperationView?
    @Published var nodes: [NodeHealthView] = []
    @Published var busy = false
    @Published var message: String?

    func reload(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.nodeHealth(origin) { nodes = value.nodes }
        if let value = try? await model.controller.api.nodeControlOperations(origin) { operations = value }
    }

    /// Asks again until the screen goes away: the order under way, the list and the state of the nodes.
    func watch(model: AppModel) async {
        await reload(model: model)
        let seconds = ScreenPolling.bundled().servicesSeconds
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { break }
            guard let origin = model.activeOrigin else { continue }
            if let current = active, current.active, let fresh = try? await model.controller.api.nodeControlOperation(origin, id: current.id) { active = fresh }
            await reload(model: model)
        }
    }

    func orderNode(model: AppModel, nodeId: String, operation: String, confirm: String?, durationS: Int?) async {
        await give(model: model, reason: model.trf("Ordenar a %s", nodeId)) { api, origin in try await api.nodeControl(origin, nodeId: nodeId, operation: operation, confirm: confirm, durationS: durationS) }
    }

    func orderAll(model: AppModel, operation: String, mode: String, confirm: String?, durationS: Int?) async {
        await give(model: model, reason: model.tr("Ordenar a todos los nodos")) { api, origin in try await api.nodesControl(origin, operation: operation, mode: mode, confirm: confirm, durationS: durationS) }
    }

    private func give(model: AppModel, reason: String, _ call: @escaping @Sendable (ArmorApi, String) async throws -> ControlOperationView) async {
        busy = true; message = nil
        defer { busy = false }
        let started = Started()
        let api = model.controller.api
        let translator = model.translator
        let ok = await model.order { asker in
            do {
                try await model.controller.guarded(reason: reason, needs: CapabilityAction.administer, asker: asker) { origin in started.value = try await call(api, origin) }
            } catch let error as ArmorApiError {
                // a refusal of the server is told here, in the words of this screen; the lock and the proof of identity are told by `order`
                self.message = NodeControlText.errorText(error, translator)
            }
        }
        if ok, let value = started.value { active = value }
    }
}

struct NodeControlView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var control = NodeControlState()
    @State private var target = ""            // "" is every node
    @State private var operation = "identify"
    @State private var mode = "rolling"
    @State private var seconds = ""
    @State private var typed = ""

    private var isAdmin: Bool { model.state.facts.isAdmin }

    var body: some View {
        let t = model.translator
        let all = target.isEmpty
        let reporting = control.nodes.filter { !$0.silent }
        let effectiveMode = all && operation == "restart" ? mode : "now"
        let needed = NodeControlParser.confirmation(operation: operation, nodeId: all ? nil : target)
        let family = control.nodes.first { $0.nodeId == target }?.family ?? ""
        let guards = all ? reporting.contains { NodeControlParser.guards.contains($0.family) } : NodeControlParser.guards.contains(family)
        let ready = isAdmin && !control.busy && (all ? !reporting.isEmpty : control.nodes.contains { $0.nodeId == target })
            && NodeControlParser.durationOk(operation: operation, typed: seconds) && (needed == nil || typed == needed)
        List {
            Section {
                Text(model.tr("Ordena a un nodo, o a todos, reiniciarse, pausar su trabajo, ponerse en espera, identificarse, dar un diagnóstico o entrar en mantenimiento. Nunca borra ajustes ni credenciales y nunca apaga el nodo: sigue conectado."))
                    .font(.footnote).foregroundColor(Theme.muted)
                if !isAdmin { Text(model.tr("Solo un administrador puede usar esta pantalla.")).foregroundColor(Theme.danger) }
                if let message = control.message { Text(message).font(.footnote).foregroundColor(Theme.danger) }
            }.listRowBackground(Theme.surface)
            if isAdmin {
                if let active = control.active { operationSection(active) }
                else {
                    Section(header: Text(model.tr("Nodo"))) {
                        if control.nodes.isEmpty { Text(model.tr("Ningún nodo está informando.")).foregroundColor(Theme.muted) }
                        choice(all, model.tr("Todos los nodos")) { target = ""; typed = "" }
                        ForEach(control.nodes.sorted { $0.nodeId < $1.nodeId }) { node in
                            let where_ = NodeControlText.stateName(node.controlState, maintenance: node.maintenance, t)
                            choice(target == node.nodeId, node.nodeId + " · " + NodeHealthText.family(node.family, t) + (where_.isEmpty ? "" : " · " + where_)) { target = node.nodeId; typed = "" }
                        }
                    }.listRowBackground(Theme.surface)
                    Section(header: Text(model.tr("Operación"))) {
                        ForEach(NodeControlParser.operations, id: \.self) { item in
                            choice(operation == item, NodeControlText.operationName(item, t)) { operation = item; typed = ""; seconds = "" }
                        }
                    }.listRowBackground(Theme.surface)
                    if all && operation == "restart" {
                        Section(header: Text(model.tr("Modo"))) {
                            choice(mode == "rolling", model.tr("Escalonado: uno tras otro, la central de alarma la última (recomendado)")) { mode = "rolling" }
                            choice(mode == "now", model.tr("Todos a la vez")) { mode = "now" }
                        }.listRowBackground(Theme.surface)
                    }
                    Section {
                        if let span = NodeControlParser.durations[operation] {
                            TextField(model.trf("Duración en segundos (%s a %s, vacío: %s)", span.min, span.max, span.standard), text: $seconds)
                                .keyboardType(.numberPad).onChange(of: seconds) { value in seconds = String(value.filter(\.isNumber).prefix(5)) }
                        }
                        if let warning = NodeControlText.warning(operation: operation, all: all, mode: effectiveMode, guards: guards, t) {
                            let calm = operation == "diagnostics" || operation == "identify" || operation == "resume"
                            Text(warning).font(.footnote).foregroundColor(calm ? Theme.muted : Theme.amber)
                        }
                        if let needed {
                            TextField(all ? model.trf("Escribe la palabra %s para confirmar", needed) : model.tr("Escribe el nombre del nodo para confirmar"), text: $typed)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().onChange(of: typed) { value in typed = String(value.prefix(64)) }
                        }
                        Button(model.tr("Enviar la orden")) {
                            let duration = NodeControlParser.duration(operation: operation, typed: seconds)
                            let confirm = needed != nil ? typed : nil
                            typed = ""
                            Task {
                                if all { await control.orderAll(model: model, operation: operation, mode: effectiveMode, confirm: confirm, durationS: duration) }
                                else { await control.orderNode(model: model, nodeId: target, operation: operation, confirm: confirm, durationS: duration) }
                            }
                        }.disabled(!ready)
                    }.listRowBackground(Theme.surface)
                }
                Section(header: Text(model.tr("Órdenes recientes"))) {
                    if control.operations.isEmpty { Text(model.tr("Todavía no se ha dado ninguna orden a los nodos.")).font(.footnote).foregroundColor(Theme.muted) }
                    ForEach(control.operations.prefix(10)) { item in
                        Button { control.active = item } label: {
                            let who = item.scope == "all" ? model.tr("Todos los nodos") : (item.nodes.first?.nodeId ?? "")
                            Text(NodeControlText.operationName(item.operation, t) + " · " + who + " · " + (item.active ? model.tr("En curso") : model.tr("Terminada"))).font(.footnote).foregroundColor(.white)
                        }
                    }
                }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Control de nodos"))
        .task { await control.watch(model: model) }
        .refreshable { await control.reload(model: model) }
    }

    private func choice(_ selected: Bool, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(label).foregroundColor(.white).multilineTextAlignment(.leading); Spacer(); if selected { Image(systemName: "checkmark").foregroundColor(Theme.accent) } }
        }
    }

    private func lineColor(_ line: ControlLineView) -> Color {
        switch line.stage {
        case "refused", "no_answer", "not_back": return Theme.danger
        case "applied", "back": return Theme.ok
        default: return Theme.accent
        }
    }

    private func operationSection(_ operation: ControlOperationView) -> some View {
        let t = model.translator
        let target = operation.scope == "all" ? model.tr("Todos los nodos") : (operation.nodes.first?.nodeId ?? "")
        return Section {
            Text(NodeControlText.operationName(operation.operation, t) + " · " + target).font(.headline)
            Text(operation.active ? model.tr("En curso") : model.tr("Terminada")).font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
            if operation.active { ProgressView() }
            ForEach(operation.nodes) { line in lineRow(line) }
            if !operation.active { Button(model.tr("Nueva orden")) { control.active = nil } }
        }.listRowBackground(Theme.surface)
    }

    private func lineRow(_ line: ControlLineView) -> some View {
        let t = model.translator
        return VStack(alignment: .leading, spacing: 2) {
            Text(line.nodeId + " · " + NodeHealthText.family(line.family, t)).font(.footnote.weight(.semibold))
            Text(NodeControlText.stageName(line.stage, t)).font(.footnote).foregroundColor(lineColor(line))
            if !line.state.isEmpty { Text(model.trf("Estado: %s", NodeControlText.stateName(line.state, maintenance: line.maintenance, t))).font(.caption) }
            if let until = line.untilS, until > 0 { Text(model.trf("Quedan %s s", until)).font(.caption).foregroundColor(Theme.muted) }
            if let back = line.backAfterS { Text(model.trf("Volvió a los %s s", back)).font(.caption).foregroundColor(Theme.muted) }
            if !line.firmwareAfter.isEmpty { Text(model.trf("Firmware %s", line.firmwareAfter)).font(.caption).foregroundColor(Theme.muted) }
            if line.stage == "refused" && !line.refusal.isEmpty { Text(NodeControlText.refusal(line.refusal, t)).font(.caption).foregroundColor(Theme.danger) }
            if !line.diagnostics.isEmpty {
                let d = line.diagnostics
                let shown: (String) -> String = { key in (d[key] ?? "").isEmpty ? "-" : (d[key] ?? "-") }
                Text(model.trf("Diagnóstico: firmware %s · encendido %s s · memoria libre %s · mínima %s", shown("firmware"), shown("uptime_s"), shown("heap_free"), shown("heap_min"))).font(.system(.caption, design: .monospaced))
            }
        }
    }
}
