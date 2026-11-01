// ARMOR-IOS-CONTROL - the two cards of the status screen for the solar installation and the electrical network: one line each, and a tap opens the full screen.
// Only for administrators and operators (the server answers the others with a refusal), and only when there is something to show.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct EquipmentCards: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var solar = SolarState()
    @StateObject private var electrical = ElectricalState()

    var body: some View {
        Group {
            if model.state.facts.canChange {
                if let data = solar.overview, !data.isEmpty { solarCard(data) }
                if let data = electrical.overview, !data.isEmpty { electricalCard(data) }
            }
        }
        .task {
            guard model.state.facts.canChange else { return }
            await solar.watch(model: model)
        }
        .task {
            guard model.state.facts.canChange else { return }
            await electrical.watch(model: model)
        }
    }

    private func solarCard(_ data: SolarOverview) -> some View {
        let tint = data.totals.stale > 0 ? Theme.amber : Theme.accent
        return NavigationLink { SolarView() } label: {
            Card {
                HStack {
                    Image(systemName: "sun.max.fill").foregroundColor(tint)
                    VStack(alignment: .leading) {
                        Text(model.tr("Solar")).font(.subheadline.weight(.semibold))
                        Text(data.devices.isEmpty ? model.tr("Esperando datos") : SolarText.summary(data.totals, model.translator)).font(.caption).foregroundColor(Theme.muted).lineLimit(1)
                    }
                    Spacer()
                    if let soc = data.totals.socPercent { Text("\(soc) %").font(.title3.bold()) }
                }
            }
        }.buttonStyle(.plain)
    }

    private func electricalCard(_ data: ElectricalOverview) -> some View {
        let tint = data.totals.alarms > 0 ? Theme.danger : (data.totals.stale > 0 ? Theme.amber : Theme.accent)
        return NavigationLink { ElectricalView() } label: {
            Card {
                HStack {
                    Image(systemName: "bolt.fill").foregroundColor(tint)
                    VStack(alignment: .leading) {
                        Text(model.tr("Eléctrica")).font(.subheadline.weight(.semibold))
                        Text(ElectricalText.gridFlow(data.totals.gridW, model.translator)).font(.caption).foregroundColor(Theme.muted).lineLimit(1)
                    }
                    Spacer()
                }
            }
        }.buttonStyle(.plain)
    }
}
