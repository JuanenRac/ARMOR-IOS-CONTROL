// ARMOR-IOS-CONTROL - the Solar screen: the sums, then every inverter and battery with its numbers; every cell of every battery with its state in words and colour, and the event log on demand. Reading only.
// It needs an operator session, and asks the server again every few seconds (the pace is in Resources/polling.json) while it is open.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

@MainActor
final class SolarState: ObservableObject {
    @Published var overview: SolarOverview?

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        if let value = try? await model.controller.api.solar(origin) { overview = value }
    }

    /// Asks again until the screen goes away (the task is cancelled with it).
    func watch(model: AppModel) async {
        let seconds = ScreenPolling.bundled().solarSeconds
        while !Task.isCancelled {
            await load(model: model)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
}

func socColor(_ percent: Int?) -> Color {
    switch SolarText.socLevel(percent) {
    case "alert": return Theme.danger
    case "warn": return Theme.amber
    case "ok": return Theme.ok
    default: return Theme.muted
    }
}

/// A label on the left and its value on the right.
struct ValueLine: View {
    let label: String
    let value: String
    var color: Color = .white
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.footnote).foregroundColor(Theme.muted)
            Spacer(minLength: 12)
            Text(value).font(.subheadline.weight(.semibold)).foregroundColor(color).multilineTextAlignment(.trailing)
        }.accessibilityElement(children: .combine)
    }
}

struct SolarView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var solar = SolarState()

    private var headline: String {
        guard let data = solar.overview else { return model.tr("Buscando datos…") }
        if data.devices.isEmpty { return model.tr("Sin equipos leyendo") }
        if data.totals.stale > 0 { return model.trf("%s sin señal de %s", data.totals.stale, data.devices.count) }
        return model.trf("%s equipos en línea", data.devices.count)
    }

    var body: some View {
        List {
            NodeFinderPanel(knownIds: (solar.overview?.devices.map(\.nodeId) ?? []) + (solar.overview?.waiting.map(\.nodeId) ?? []))
            Section { Text(headline).font(.footnote).foregroundColor(Theme.muted) }.listRowBackground(Theme.surface)
            if let data = solar.overview {
                if data.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.tr("Aún no hay equipos solares")).font(.headline)
                            Text(model.tr("Los inversores y las baterías se añaden desde Studio, y un nodo solar los lee y envía sus datos aquí.")).font(.footnote).foregroundColor(Theme.muted)
                        }
                    }.listRowBackground(Theme.surface)
                }
                if !data.devices.isEmpty { totalsSection(data.totals) }
                bankSection(data.devices)
                let batteries = data.devices.filter { $0.battery != nil && !$0.example }
                if !batteries.isEmpty { Section { BankCharts(batteries: batteries) }.listRowBackground(Theme.surface) }
                ForEach(data.devices) { device in
                    if let reading = device.inverter { InverterSection(device: device, reading: reading) }
                    else if let reading = device.battery { SolarBatterySection(device: device, reading: reading) }
                }
                if !data.waiting.isEmpty {
                    Section(header: Text(model.tr("Esperando datos"))) {
                        ForEach(data.waiting) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name).font(.subheadline.weight(.semibold))
                                    let fallback = item.kind == "inverter" ? model.tr("Inversor") : model.tr("Batería")
                                    let modelName = SolarText.model(item.model)
                                    Text(model.trf("%s · nodo %s", modelName.isEmpty ? fallback : modelName, item.nodeId)).font(.caption).foregroundColor(Theme.muted)
                                }
                                Spacer()
                                Text(model.tr("sin lecturas")).font(.caption2).foregroundColor(Theme.amber)
                            }
                        }
                    }.listRowBackground(Theme.surface)
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Solar"))
        .task { await solar.watch(model: model) }
        .refreshable { await solar.load(model: model) }
    }

    /// The state of all the batteries that are reporting at a glance.
    @ViewBuilder private func bankSection(_ devices: [SolarDevice]) -> some View {
        let settings = SolarViewSettings.bundled()
        let banks: [BankView] = devices.filter { !$0.stale }.compactMap { device in
            device.battery.map { SolarCells.bank(deviceModel: device.model, reading: $0, settings: settings) }
        }
        if let level = banks.map(\.level).max() {
            let faults = banks.reduce(0) { $0 + $1.faultModules }
            let warnings = banks.reduce(0) { $0 + $1.warnModules }
            Section {
                HStack {
                    Text(model.tr("Estado de las baterías")).font(.subheadline.weight(.semibold))
                    Spacer()
                    LevelChip(level: level, stale: false, settings: settings)
                }
                ValueLine(label: model.tr("Módulos"), value: String(banks.reduce(0) { $0 + $1.modules.count }))
                ValueLine(label: model.tr("Con fallo"), value: String(faults), color: faults > 0 ? Theme.danger : .white)
                ValueLine(label: model.tr("Con aviso"), value: String(warnings), color: warnings > 0 ? Theme.amber : .white)
            }.listRowBackground(Theme.surface)
        }
    }

    @ViewBuilder private func totalsSection(_ totals: SolarTotals) -> some View {
        Section {
            if totals.inverters > 0 {
                ValueLine(label: model.tr("Sol"), value: SolarText.watts(totals.pvW))
                ValueLine(label: model.tr("Consumo"), value: SolarText.watts(totals.loadW))
            }
            HStack {
                VStack(alignment: .leading) {
                    Text(model.tr("Baterías")).font(.subheadline.weight(.semibold))
                    Text(SolarText.batteryFlow(totals.batteryW, model.translator)).font(.caption).foregroundColor(Theme.muted)
                }
                Spacer()
                Text(SolarText.percent(totals.socPercent)).font(.title.bold()).foregroundColor(socColor(totals.socPercent))
            }
            if let soc = totals.socPercent { ProgressView(value: Double(min(100, max(0, soc))), total: 100).tint(socColor(soc)) }
            if totals.capacityAh != nil || totals.energyKwh != nil {
                Text(totalsLine(totals)).font(.caption).foregroundColor(Theme.muted)
            }
            if totals.inverters > 0 {
                HStack {
                    Image(systemName: totals.gridPresent ? "powerplug.fill" : "powerplug").foregroundColor(totals.gridPresent ? Theme.ok : Theme.amber)
                    Text(totals.gridPresent ? model.tr("Hay red eléctrica") : model.tr("Sin red eléctrica")).font(.footnote).foregroundColor(Theme.muted)
                    if let mode = totals.mode { Text("· " + SolarText.mode(mode, model.translator)).font(.footnote).foregroundColor(Theme.muted) }
                }
            }
        }.listRowBackground(Theme.surface)
    }

    private func totalsLine(_ totals: SolarTotals) -> String {
        var parts: [String] = []
        if let capacity = totals.capacityAh {
            let figures = totals.fullCapacityAh.map { model.trf("%s de %s", SolarText.ah(capacity), SolarText.ah($0)) } ?? SolarText.ah(capacity)
            parts.append((totals.fullEstimated ? "≈ " : "") + figures)
        }
        if let energy = totals.energyKwh { parts.append(model.trf("%s kWh guardados", String(format: "%.2f", energy))) }
        return parts.joined(separator: " · ")
    }
}

private struct SolarMarks: View {
    @EnvironmentObject var model: AppModel
    let device: SolarDevice
    var body: some View {
        HStack(spacing: 6) {
            if device.example { Text(model.tr("EJEMPLO")).font(.caption2.weight(.bold)).foregroundColor(Theme.amber) }
            if device.stale { Text(model.tr("SIN SEÑAL")).font(.caption2.weight(.bold)).foregroundColor(Theme.danger) }
        }
    }
}

private struct InverterSection: View {
    @EnvironmentObject var model: AppModel
    let device: SolarDevice
    let reading: SolarInverterReading

    var body: some View {
        let r = reading
        let modelName = SolarText.model(device.model)
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name).font(.headline).foregroundColor(device.stale ? Theme.muted : .white)
                    Text(SolarText.mode(r.mode, model.translator) + (modelName.isEmpty ? "" : " · " + modelName)).font(.caption).foregroundColor(Theme.muted)
                }
                Spacer()
                SolarMarks(device: device)
            }
            if !r.manufacturer.isEmpty { ValueLine(label: model.tr("Fabricante"), value: r.manufacturer + (r.manufacturerDeduced ? " (" + model.tr("deducido") + ")" : "")) }
            ValueLine(label: model.tr("Red"), value: SolarText.volts(r.gridV) + " · " + SolarText.hertz(r.gridHz))
            ValueLine(label: model.tr("Consumo"), value: SolarText.watts(r.outW) + " · " + SolarText.percent(r.loadPercent))
            ValueLine(label: model.tr("Paneles"), value: SolarText.watts(r.pvW) + " · " + SolarText.volts(r.pvV, 0))
            if let second = r.pv2W { ValueLine(label: model.tr("Segunda entrada"), value: SolarText.watts(second) + " · " + SolarText.volts(r.pv2V, 0)) }
            ValueLine(label: model.tr("Batería"), value: SolarText.percent(r.batteryPercent) + " · " + SolarText.volts(r.batteryV, 2) + " · " + SolarText.amps(r.batteryA),
                      color: socColor(r.batteryPercent.map { Int($0.rounded()) }))
            ValueLine(label: model.tr("Temperatura"), value: SolarText.celsius(r.heatsinkC))
            if let e = r.energy {
                if let panels = SolarText.periods(e.pvTodayWh, e.pvMonthWh, e.pvYearWh, e.pvTotalWh, model.translator) { ValueLine(label: model.tr("Energía de los paneles"), value: panels) }
                if let used = SolarText.periods(e.loadTodayWh, e.loadMonthWh, e.loadYearWh, e.loadTotalWh, model.translator) { ValueLine(label: model.tr("Energía consumida"), value: used) }
            }
            if !r.units.isEmpty {
                ValueLine(label: model.tr("Sistema en paralelo"), value: model.trf("%s unidades", r.units.count) + (r.totalOutW.map { " · " + SolarText.watts($0) } ?? ""))
                ForEach(r.units, id: \.unit) { unit in
                    let fault = unit.faultCode.isEmpty || unit.faultCode == "00" ? "" : model.trf(" · fallo %s", unit.faultCode)
                    ValueLine(label: model.trf("Unidad %s", unit.unit + 1), value: SolarText.mode(unit.mode, model.translator) + fault + " · " + SolarText.watts(unit.outW), color: unit.mode == "fault" ? Theme.danger : .white)
                }
            }
            if !r.warnings.isEmpty {
                Label(r.warnings.map(SolarText.warning).joined(separator: ", "), systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(Theme.amber)
            }
            if !device.example { InverterHistoryCharts(device: device) }
        }.listRowBackground(Theme.surface)
    }
}

private struct SolarBatterySection: View {
    @EnvironmentObject var model: AppModel
    let device: SolarDevice
    let reading: SolarBatteryReading
    @AppStorage private var showCells: Bool
    @State private var showEvents = false
    private let settings = SolarViewSettings.bundled()

    init(device: SolarDevice, reading: SolarBatteryReading) {
        self.device = device
        self.reading = reading
        _showCells = AppStorage(wrappedValue: true, "solar.cells." + device.id)
    }

    var body: some View {
        let r = reading
        let bank = SolarCells.bank(deviceModel: device.model, reading: r, settings: settings)
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name).font(.headline).foregroundColor(device.stale ? Theme.muted : .white)
                    let modelName = SolarText.model(device.model)
                    Text([SolarText.batteryState(r.state, model.translator), modelName.isEmpty ? r.model : modelName,
                          r.manufacturer.isEmpty ? "" : r.manufacturer + (r.manufacturerDeduced ? " (" + model.tr("deducido") + ")" : "")].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundColor(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(SolarText.percent(r.socPercent)).font(.title2.bold()).foregroundColor(device.stale ? Theme.muted : socColor(r.socPercent))
                    SolarMarks(device: device)
                }
            }
            if let soc = r.socPercent { ProgressView(value: Double(min(100, max(0, soc))), total: 100).tint(socColor(soc)) }
            if r.modules == 0 {
                Text(model.tr("La batería no responde a los módulos.")).font(.footnote).foregroundColor(Theme.amber)
            } else {
                LevelChip(level: bank.level, stale: device.stale, settings: settings)
                ValueLine(label: model.tr("Tensión y corriente"), value: SolarText.volts(r.voltageV, 2) + " · " + SolarText.amps(r.currentA, 2))
                ValueLine(label: model.tr("Potencia"), value: SolarText.batteryFlow(r.powerW, model.translator))
                if r.temperatureMinC != nil { ValueLine(label: model.tr("Temperatura"), value: temperatureLine(r)) }
                if bank.minV != nil && bank.maxV != nil {
                    ValueLine(label: model.tr("Celdas"), value: cellsLine(bank), color: (bank.spreadMv ?? 0) >= settings.spreadWarnMv ? Theme.amber : Color.white)
                }
                if r.capacityAh != nil { ValueLine(label: model.tr("Capacidad"), value: capacityLine(r)) }
                if let cycles = r.cycles { ValueLine(label: model.tr("Ciclos"), value: String(cycles)) }
                if let health = r.healthPercent { ValueLine(label: model.tr("Salud (capacidad frente a nueva)"), value: "\(health) %") }
                if let says = r.stackSays {
                    if let figures = SolarText.stackFigures(says, model.translator) { ValueLine(label: model.tr("Según la pila"), value: figures) }
                    if let limits = SolarText.stackLimits(says, model.translator) { ValueLine(label: model.tr("Límites recomendados"), value: limits) }
                    if let asleep = says.modulesAsleep, asleep > 0 { ValueLine(label: model.tr("Módulos dormidos"), value: String(asleep)) }
                }
                if let bank = device.dayCells?.bankDeltaV, bank > 0 {
                    let mv = Int((bank * 1000).rounded())
                    ValueLine(label: model.tr("Mayor diferencia hoy (banco)"), value: "\(mv) mV", color: mv > 100 ? Theme.amber : Color.white)
                }
                if r.modules > 1 { ValueLine(label: model.tr("Módulos"), value: String(r.modules)) }
            }
            ForEach(SolarText.composition(r.stack), id: \.code) { warning in
                Text(compositionLine(warning.code, warning.modules, r.stack)).font(.caption2).foregroundColor(Theme.amber)
            }
            if r.alarm {
                Label(model.tr("La batería avisa de un problema (una protección está actuando)."), systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(Theme.danger)
            }
            if bank.modules.contains(where: { !$0.cells.isEmpty }) {
                Button(showCells ? model.tr("Ocultar celdas") : model.tr("Ver celdas")) { showCells.toggle() }
                if showCells { ForEach(bank.modules) { view in ModuleSection(device: device, view: view, settings: settings) } }
            }
            if !device.example { BatteryHistoryCharts(device: device, reading: reading) }
            if !device.events.isEmpty {
                Button(showEvents ? model.tr("Ocultar registro de eventos") : model.tr("Ver registro de eventos")) { showEvents.toggle() }
                if showEvents {
                    Text(model.tr("Solo lectura. Cada entrada nueva que el nodo lee del registro propio de un módulo, la más reciente primero, con las palabras de la batería: los nombres de las protecciones se muestran tal como se imprimen, sin traducir ni decodificar."))
                        .font(.caption2).foregroundColor(Theme.muted)
                    ForEach(Array(device.events.prefix(30).enumerated()), id: \.offset) { _, item in eventRow(item) }
                }
            }
        }.listRowBackground(Theme.surface)
    }

    private func temperatureLine(_ r: SolarBatteryReading) -> String {
        let low = SolarText.celsius(r.temperatureMinC)
        guard let high = r.temperatureMaxC, high != r.temperatureMinC else { return low }
        return low + " – " + SolarText.celsius(high)
    }

    private func cellsLine(_ bank: BankView) -> String {
        let low = bank.minV.map { SolarText.cell($0) } ?? "—"
        let high = bank.maxV.map { SolarText.cell($0) } ?? "—"
        let gap: String = bank.spreadMv.map { " (" + String($0) + " mV)" } ?? ""
        return low + " – " + high + " V" + gap
    }

    private func capacityLine(_ r: SolarBatteryReading) -> String {
        guard let full = r.fullCapacityAh else { return SolarText.ah(r.capacityAh) }
        return (r.fullEstimated ? "≈ " : "") + model.trf("%s de %s", SolarText.ah(r.capacityAh), SolarText.ah(full))
    }

    private func compositionLine(_ code: String, _ modules: [Int], _ stack: [SolarModule]) -> String {
        let names: [String] = modules.map { number in
            let name = stack.first { $0.number == number }?.model ?? "?"
            return model.trf("Módulo %s", number) + " (" + name + ")"
        }
        return SolarText.compositionText(code, model.translator) + " " + names.joined(separator: ", ")
    }

    private func eventRow(_ item: LoggedEvent) -> some View {
        let e = item.event
        var words: [String] = [e.voltageState]
        if !e.powerEvents.isEmpty { words.append(model.tr("Eventos de potencia") + " " + e.powerEvents) }
        if !e.batteryEvents.isEmpty { words.append(model.tr("Eventos de batería") + " " + e.batteryEvents) }
        if !e.systemFault.isEmpty { words.append(model.tr("Fallo del sistema") + " " + e.systemFault) }
        return VStack(alignment: .leading) {
            Text(model.trf("Módulo %s", item.module) + " · #\(e.index) · " + e.time).font(.system(size: 11, design: .monospaced))
            Text(words.filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.muted)
        }
    }
}
