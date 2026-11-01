// ARMOR-IOS-CONTROL - every service of the system, running or not: the programs of the machine and the field nodes. Reading only.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

@MainActor
final class ServicesState: ObservableObject {
    @Published var overview: ServicesOverview?

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.services(origin) { overview = value }
    }

    func watch(model: AppModel) async {
        let seconds = ScreenPolling.bundled().servicesSeconds
        while !Task.isCancelled {
            await load(model: model)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
}

struct ServicesView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var services = ServicesState()

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "running", "online": return Theme.ok
        case "starting": return Theme.amber
        case "failed", "offline": return Theme.danger
        default: return Theme.muted
        }
    }

    var body: some View {
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        List {
            if let data = services.overview {
                Section { Text(ServicesText.summary(data, model.translator)).font(.footnote).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface)
                if !data.systemd {
                    Section { Text(model.tr("Esta máquina no usa systemd: los programas aparecen como desconocidos; los nodos de campo sí se leen.")).font(.caption).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface)
                }
                ForEach(ServicesText.familyOrder, id: \.self) { family in
                    let shown = data.services.filter { $0.family == family }
                    if !shown.isEmpty {
                        Section(header: Text(ServicesText.family(family, model.translator))) { ForEach(shown) { row($0, nowMs) } }.listRowBackground(Theme.surface)
                    }
                }
                let other = data.services.filter { !ServicesText.familyOrder.contains($0.family) }
                if !other.isEmpty { Section(header: Text(other[0].family)) { ForEach(other) { row($0, nowMs) } }.listRowBackground(Theme.surface) }
                if data.services.isEmpty { Section { Text(model.tr("No se ha leído ningún servicio.")).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface) }
            } else {
                Section { Text(model.tr("Buscando servicios…")).font(.footnote).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Servicios"))
        .task { await services.watch(model: model) }
        .refreshable { await services.load(model: model) }
    }

    private func row(_ service: ServiceInfo, _ nowMs: Int) -> some View {
        let t = model.translator
        let when = ServicesText.since(service.sinceMs, nowMs: nowMs, t)
        var line = service.kind == "field-node" ? model.trf("Última vez: %s", when) : model.trf("En marcha %s", when)
        if let pid = service.pid { line += " · PID " + String(pid) }
        if let port = service.port { line += model.trf(" · puerto %s", port) }
        if let memory = service.memoryBytes { line += " · " + ServicesText.memory(memory) }
        if (service.restarts ?? 0) > 0 { line += model.trf(" · %s reinicios", service.restarts ?? 0) }
        if service.enabled == true { line += model.tr(" · arranca solo") }
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle().fill(stateColor(service.state)).frame(width: 10, height: 10)
                Text(service.name).font(.subheadline.weight(.semibold))
                Spacer()
                Text(ServicesText.state(service.state, t)).font(.caption).foregroundColor(stateColor(service.state))
            }
            Text(service.description).font(.caption).foregroundColor(Theme.muted)
            Text(line).font(.caption2).foregroundColor(Theme.muted)
        }.accessibilityElement(children: .combine)
    }
}
