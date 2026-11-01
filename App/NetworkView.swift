// ARMOR-IOS-CONTROL - the local network as the network nodes see it: whether there is internet, the devices, the outages and what changed; and the panel that finds nodes on the network for the
// Solar and Electrical screens. It asks the server again every few seconds (the pace is in Resources/polling.json) while it is open.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

@MainActor
final class NetworkState: ObservableObject {
    @Published var overview: NetworkOverview?
    @Published var scanning = false

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.network(origin) { overview = value }
    }

    func watch(model: AppModel) async {
        let seconds = ScreenPolling.bundled().networkSeconds
        while !Task.isCancelled {
            await load(model: model)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }

    /// Asks the network node to sweep now, then reads the answer.
    func scan(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        scanning = true
        defer { scanning = false }
        try? await model.controller.api.scanNetworkNow(origin)
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await load(model: model)
    }
}

private func stateColor(_ state: String) -> Color {
    switch state {
    case "up": return Theme.ok
    case "degraded": return Theme.amber
    case "unknown": return Theme.muted
    default: return Theme.danger
    }
}

private func shortDate(_ ms: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
}

struct NetworkView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var network = NetworkState()
    @State private var onlyNew = false

    private var headline: String {
        guard let data = network.overview else { return model.tr("Buscando datos…") }
        if data.nodes.isEmpty { return model.tr("Sin nodos de red leyendo") }
        if data.totals.stale > 0 { return model.trf("%s sin señal de %s", data.totals.stale, data.nodes.count) }
        return model.trf("%s nodos en línea", data.nodes.count)
    }

    var body: some View {
        List {
            Section { Text(headline).font(.footnote).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface)
            if let data = network.overview {
                if data.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.tr("Aún no hay nodos de red")).font(.headline)
                            Text(model.tr("Cuando un nodo ARMOR-NETWORK vigile la red, aparecerán aquí: si hay internet, los dispositivos y lo que cambia.")).font(.footnote).foregroundColor(Theme.muted)
                        }
                    }.listRowBackground(Theme.surface)
                } else if let node = data.nodes.first {
                    internetSection(node, data)
                    devicesSection(node)
                    if !data.outages.isEmpty { outagesSection(data) }
                    if !data.events.isEmpty { eventsSection(data, node.devices) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Red"))
        .task { await network.watch(model: model) }
        .refreshable { await network.load(model: model) }
    }

    @ViewBuilder private func internetSection(_ node: NetworkNode, _ data: NetworkOverview) -> some View {
        let internet = node.internet
        let color = stateColor(internet.state)
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NetworkText.state(internet.state, model.translator)).font(.subheadline.weight(.semibold)).foregroundColor(color)
                    if let hint = NetworkText.hint(internet.state, model.translator) { Text(hint).font(.caption).foregroundColor(Theme.muted) }
                    if let since = internet.sinceMs { Text(model.trf("Desde %s", shortDate(since))).font(.caption2).foregroundColor(Theme.muted) }
                }
                Spacer()
                if let latency = internet.latencyMs { Text(String(Int(latency.rounded())) + " ms").font(.title3.bold()) }
            }
            Text(outagesLine(internet)).font(.caption).foregroundColor(Theme.muted)
            Text(model.trf("%s · red %s · router %s · ↓ %s ↑ %s", node.ip, node.cidr, node.gateway ?? "—", NetworkText.bps(node.rxBps, model.translator), NetworkText.bps(node.txBps, model.translator)))
                .font(.caption2).foregroundColor(Theme.muted)
            if let info = node.publicInfo {
                Text(model.trf("IP pública: %s", info.ip)).font(.subheadline.weight(.semibold))
                let place = [info.city, info.region, countryName(info.country)].compactMap { $0 }.joined(separator: ", ")
                let line = [info.org, place.isEmpty ? nil : place].compactMap { $0 }.joined(separator: " · ")
                if !line.isEmpty { Text(line).font(.caption2).foregroundColor(Theme.muted) }
            }
            if data.totals.unknown > 0 {
                Label(data.totals.unknown == 1 ? model.tr("Un dispositivo sin marcar como conocido") : model.trf("%s dispositivos sin marcar como conocidos", data.totals.unknown), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundColor(Theme.amber)
            }
        }.listRowBackground(Theme.surface)
    }

    private func outagesLine(_ internet: NetworkInternet) -> String {
        var line = model.trf("Cortes en 24 h: %s · sin internet %s", internet.outages24h, NetworkText.duration(internet.downtime24hS, model.translator))
        if let loss = internet.lossPercent { line += model.trf(" · pérdida %s %%", Int(loss.rounded())) }
        return line
    }

    private func countryName(_ code: String?) -> String? {
        guard let code else { return nil }
        let name = Locale(identifier: model.translator.language).localizedString(forRegionCode: code)
        return (name?.isEmpty == false) ? name : code
    }

    @ViewBuilder private func devicesSection(_ node: NetworkNode) -> some View {
        let shown = node.devices.sorted { NetworkText.ipKey($0.ip) < NetworkText.ipKey($1.ip) }.filter { !onlyNew || !$0.known }
        Section {
            ForEach(shown) { device in deviceRow(device, ownIp: node.ip) }
        } header: {
            HStack {
                Text(model.tr("Dispositivos"))
                Spacer()
                Button(onlyNew ? model.tr("Solo sin conocer") : model.tr("Todos")) { onlyNew.toggle() }.font(.caption)
            }
        }.listRowBackground(Theme.surface)
    }

    private func deviceRow(_ device: NetworkDevice, ownIp: String) -> some View {
        let risky = device.ports.filter { NetworkText.riskyPorts.contains($0.port) }
        let title = device.name + (device.ip == ownIp ? model.tr(" (este nodo)") : "")
        let kindLine = device.ip + " · " + NetworkText.kind(device.shownKind, model.translator) + (device.vendor.map { " · " + $0 } ?? "")
        let riskyText = risky.map { port in String(port.port) + (port.service.map { " (" + $0 + ")" } ?? "") }.joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(device.online ? model.tr("en línea") : model.tr("sin conexión")).font(.caption2).foregroundColor(device.online ? Theme.ok : Theme.muted)
            }
            Text(kindLine).font(.caption).foregroundColor(Theme.muted).lineLimit(1)
            if !device.ports.isEmpty {
                Text(model.tr("Puertos: ") + device.ports.map { String($0.port) }.joined(separator: ", ")).font(.caption2).foregroundColor(risky.isEmpty ? Theme.muted : Theme.danger)
            }
            if !risky.isEmpty { Text(model.trf("Puerto que una casa rara vez quiere abierto: %s", riskyText)).font(.caption2).foregroundColor(Theme.danger) }
            if !device.known { Text(model.tr("Sin marcar como conocido")).font(.caption2).foregroundColor(Theme.amber) }
        }.opacity(device.online ? 1 : 0.7).accessibilityElement(children: .combine)
    }

    @ViewBuilder private func outagesSection(_ data: NetworkOverview) -> some View {
        Section(header: Text(model.tr("Cortes"))) {
            ForEach(Array(data.outages.prefix(8).enumerated()), id: \.offset) { _, outage in
                let who = outage.kind == "gateway" ? model.tr("el router") : model.tr("internet")
                Text(shortDate(outage.startedMs) + " → " + shortDate(outage.endedMs) + " · " + NetworkText.duration(outage.durationS, model.translator) + " · " + who).font(.caption).foregroundColor(Theme.muted)
            }
        }.listRowBackground(Theme.surface)
    }

    @ViewBuilder private func eventsSection(_ data: NetworkOverview, _ devices: [NetworkDevice]) -> some View {
        Section(header: Text(model.tr("Qué ha cambiado"))) {
            ForEach(data.events.prefix(20)) { event in
                VStack(alignment: .leading) {
                    Text(NetworkText.event(event, devices, model.translator)).font(.caption)
                    Text(shortDate(event.atMs)).font(.caption2).foregroundColor(Theme.muted)
                }
            }
        }.listRowBackground(Theme.surface)
    }
}

/// Lists what the network node has found that looks like an ARMOR node and is not yet known here, with a way to search now and to open a candidate's own panel.
struct NodeFinderPanel: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL
    @StateObject private var network = NetworkState()
    let knownIds: [String]

    var body: some View {
        let candidates = NodeFinder.candidates(network.overview, knownIds: knownIds)
        let hasWatcher = network.overview?.nodes.contains { !$0.stale } == true
        Section {
            HStack {
                Text(model.tr("Buscar nodos en la red")).font(.subheadline.weight(.semibold))
                Spacer()
                Button(network.scanning ? model.tr("Buscando…") : model.tr("Buscar ahora")) { Task { await network.scan(model: model) } }
                    .buttonStyle(.bordered).disabled(!hasWatcher || network.scanning)
            }
            if !hasWatcher { Text(model.tr("El nodo de red no informa, así que no hay con qué buscar.")).font(.caption2).foregroundColor(Theme.muted) }
            else if candidates.isEmpty { Text(model.tr("No se ha encontrado ningún nodo nuevo.")).font(.caption2).foregroundColor(Theme.muted) }
            ForEach(candidates, id: \.ip) { candidate in
                HStack {
                    VStack(alignment: .leading) {
                        Text(candidate.nodeId ?? candidate.hostname ?? candidate.ip).font(.subheadline.weight(.medium))
                        let parts = [candidate.ip, candidate.mac, candidate.vendor, candidate.online ? nil : model.tr("no responde ahora")].compactMap { $0 }
                        Text(parts.joined(separator: " · ")).font(.caption2).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    Button(model.tr("Panel")) { if let url = URL(string: "http://" + candidate.ip + "/") { openURL(url) } }
                }
            }
        }
        .listRowBackground(Theme.surface)
        .task { await network.watch(model: model) }
    }
}
