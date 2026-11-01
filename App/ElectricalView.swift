// ARMOR-IOS-CONTROL - the electrical network: the grid input, the circuits and the DC buses the electrical nodes measure. Reading only.
// It asks the server again every few seconds (the pace is in Resources/polling.json) while it is open.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

@MainActor
final class ElectricalState: ObservableObject {
    @Published var overview: ElectricalOverview?

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.electrical(origin) { overview = value }
    }

    func watch(model: AppModel) async {
        let seconds = ScreenPolling.bundled().electricalSeconds
        while !Task.isCancelled {
            await load(model: model)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
}

struct ElectricalView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var electrical = ElectricalState()

    private var headline: String {
        guard let data = electrical.overview else { return model.tr("Buscando datos…") }
        if data.nodes.isEmpty { return model.tr("Sin nodos eléctricos leyendo") }
        if data.totals.stale > 0 { return model.trf("%s sin señal de %s", data.totals.stale, data.nodes.count) }
        return model.trf("%s nodos en línea", data.nodes.count)
    }

    var body: some View {
        List {
            Section { Text(headline).font(.footnote).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface)
            if let data = electrical.overview {
                if data.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.tr("Aún no hay nodos eléctricos")).font(.headline)
                            Text(model.tr("Cuando un nodo con contadores publique sus lecturas, aparecerán aquí: la red, los circuitos y los buses de continua.")).font(.footnote).foregroundColor(Theme.muted)
                        }
                    }.listRowBackground(Theme.surface)
                } else {
                    totalsSection(data.totals)
                    ForEach(data.nodes) { node in nodeSection(node) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Eléctrica"))
        .task { await electrical.watch(model: model) }
        .refreshable { await electrical.load(model: model) }
    }

    @ViewBuilder private func totalsSection(_ totals: ElectricalTotals) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text(model.tr("Red eléctrica")).font(.subheadline.weight(.semibold))
                    Text(ElectricalText.gridFlow(totals.gridW, model.translator)).font(.caption).foregroundColor(Theme.muted)
                }
                Spacer()
                if let energy = totals.gridKwh { Text(ElectricalText.kwh(energy)).font(.caption).foregroundColor(Theme.muted) }
            }
            if totals.alarms > 0 {
                Label(totals.alarms == 1 ? model.tr("Un contador avisa de una alarma") : model.trf("%s contadores avisan de una alarma", totals.alarms), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundColor(Theme.amber)
            }
        }.listRowBackground(Theme.surface)
    }

    @ViewBuilder private func nodeSection(_ node: ElectricalNode) -> some View {
        Section {
            HStack {
                Text(node.nodeId).font(.headline).lineLimit(1)
                Spacer()
                Text(node.stale ? model.tr("sin señal") : model.tr("en línea")).font(.caption2).foregroundColor(node.stale ? Theme.amber : Theme.ok)
            }
            if node.switchingEnabled == false { Text(model.tr("Maniobra desactivada en el nodo")).font(.caption2).foregroundColor(Theme.amber) }
            if node.channels.isEmpty { Text(model.tr("No hay ningún contador leyendo")).font(.footnote).foregroundColor(Theme.muted) }
            ForEach(node.channels) { channel in channelRow(channel, stale: node.stale) }
            ForEach(node.switches) { item in switchRow(item) }
        }.listRowBackground(Theme.surface)
    }

    private func switchRow(_ item: ElectricalSwitch) -> some View {
        let fault = item.fault != "none"
        let t = model.translator
        let closed = model.tr("cerrado"), open = model.tr("abierto")
        var line = ElectricalText.switchSource(item, t) + " · A: " + (item.aClosed ? closed : open) + " · B: " + (item.bClosed ? closed : open)
        if item.closing { line += model.tr(" · maniobrando") }
        return VStack(alignment: .leading, spacing: 2) {
            Text(item.name).font(.subheadline.weight(.medium)).foregroundColor(fault ? Theme.danger : .white)
            Text(line).font(.caption).foregroundColor(Theme.muted)
            if let words = ElectricalText.switchFault(item.fault, t) { Text(words).font(.caption2).foregroundColor(Theme.danger) }
        }.accessibilityElement(children: .combine)
    }

    private func channelRow(_ channel: ElectricalChannel, stale: Bool) -> some View {
        let tint: Color = stale ? Theme.muted : (channel.alarm ? Theme.danger : .white)
        var details = [ElectricalText.volts(channel.voltageV), ElectricalText.amps(channel.currentA)]
        if let hertz = channel.frequencyHz { details.append(String(format: "%.1f Hz", hertz)) }
        if let factor = channel.powerFactor { details.append(model.trf("cos φ %s", String(format: "%.2f", factor))) }
        if let energy = channel.energyKwh { details.append(ElectricalText.kwh(energy)) }
        if let state = ElectricalText.switchState(channel.state, model.translator) { details.append(state) }
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(channel.name).font(.subheadline.weight(.medium)).foregroundColor(tint).lineLimit(1)
                Spacer()
                Text(channel.domain == "dc" ? model.tr("CC") : model.tr("CA")).font(.caption2).foregroundColor(Theme.muted)
                Text(ElectricalText.watts(channel.powerW)).font(.headline).foregroundColor(tint)
            }
            Text(details.joined(separator: " · ")).font(.caption).foregroundColor(Theme.muted)
            if channel.alarm { Text(model.tr("El contador avisa de una alarma")).font(.caption2).foregroundColor(Theme.amber) }
        }.accessibilityElement(children: .combine)
    }
}
