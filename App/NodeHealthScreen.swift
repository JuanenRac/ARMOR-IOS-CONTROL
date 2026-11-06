// ARMOR-IOS-CONTROL - the health of the nodes: the same report from every radar, solar, electrical, alarm and wall-panel node (uptime, why it restarted, memory, link, how often it lost the
// broker, the last error) and the warnings the server raised about each. Reading only. The same screen as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

@MainActor
final class NodeHealthState: ObservableObject {
    @Published var overview: NodeHealthOverview?

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.nodeHealth(origin) { overview = value }
    }

    /// The pace is the one of the services screen (Resources/polling.json): the nodes report once a minute, so asking more often gains nothing.
    func watch(model: AppModel) async {
        let seconds = ScreenPolling.bundled().servicesSeconds
        while !Task.isCancelled {
            await load(model: model)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
}

struct NodeHealthScreen: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var health = NodeHealthState()

    private func tint(_ node: NodeHealthView) -> Color {
        switch node.status {
        case "ok": return Theme.ok
        case "warning": return Theme.amber
        default: return Theme.muted
        }
    }

    var body: some View {
        let t = model.translator
        List {
            if let data = health.overview {
                Section {
                    Text(NodeHealthText.summary(data, t)).font(.footnote).foregroundColor(data.totals.withWarnings > 0 ? Theme.amber : Theme.muted)
                }.listRowBackground(Theme.surface)
                if data.isEmpty {
                    Section {
                        Text(model.tr("Ningún nodo ha enviado aún un informe de salud")).font(.headline)
                        Text(model.tr("Un nodo con firmware reciente envía uno cada minuto, y el broker debe dejarle escribirlo.")).font(.caption).foregroundColor(Theme.muted)
                    }.listRowBackground(Theme.surface)
                }
                ForEach(NodeHealthText.orderedByNeed(data.nodes)) { node in card(node) }
                if !data.waiting.isEmpty {
                    Section {
                        Text(model.tr("Nodos conocidos que aún no han enviado informe (firmware antiguo, o el broker no les deja escribirlo):") + " " + data.waiting.map { "\($0.nodeId) (\(NodeHealthText.family($0.family, t)))" }.joined(separator: ", "))
                            .font(.caption2).foregroundColor(Theme.muted)
                    }.listRowBackground(Theme.surface)
                }
            } else {
                Section { Text(model.tr("Buscando datos…")).font(.footnote).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Salud de los nodos"))
        .task { await health.watch(model: model) }
        .refreshable { await health.load(model: model) }
    }

    private func fact(_ label: String, _ value: String, _ color: Color = Theme.muted) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.caption2).foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
            Text(value).font(.caption).foregroundColor(color).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func card(_ node: NodeHealthView) -> some View {
        let t = model.translator
        let unexpected = NodeHealthText.isUnexpected(node.resetReason)
        return Section {
            HStack {
                Circle().fill(tint(node)).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.nodeId).font(.subheadline.weight(.semibold))
                    Text(NodeHealthText.family(node.family, t) + " · " + node.firmware + (node.board.map { " · \($0)" } ?? "")).font(.caption).foregroundColor(Theme.muted)
                }
                Spacer()
                Text(NodeHealthText.status(node.status, t)).font(.caption).foregroundColor(tint(node))
            }
            ForEach(node.warnings, id: \.self) { code in Text("• " + NodeHealthText.warning(code, t)).font(.caption).foregroundColor(Theme.amber) }
            fact(model.tr("Encendido desde hace"), NodeHealthText.uptime(node.uptimeSeconds, t))
            fact(model.tr("Último arranque"), NodeHealthText.resetReason(node.resetReason, t) + (unexpected ? " · " + model.tr("inesperado") : ""), unexpected ? Theme.danger : Theme.muted)
            fact(model.tr("Memoria libre"), NodeHealthText.bytes(node.heapFree) + " · " + model.trf("mínimo %s", NodeHealthText.bytes(node.heapMin)), node.warnings.contains("node_low_memory") ? Theme.amber : Theme.muted)
            fact(model.tr("Enlace"), NodeHealthText.link(node, t))
            fact(model.tr("Conexiones al broker"), String(node.brokerConnections))
            fact(model.tr("Reinicios en 24 h"), String(node.restarts24h), node.restarts24h >= 3 ? Theme.amber : Theme.muted)
            if node.lowStackTasks > 0 { fact(model.tr("Tareas cortas de pila"), String(node.lowStackTasks), Theme.amber) }
            fact(model.tr("Último error"), node.lastError ?? model.tr("ninguno anotado"))
        }.listRowBackground(Theme.surface)
    }
}
