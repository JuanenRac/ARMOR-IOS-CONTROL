// ARMOR-IOS-CONTROL - the pictures of a battery: its state in words and colour and every cell of every module (the same as the Android app).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

func levelColor(_ level: CellLevel, stale: Bool = false) -> Color {
    if stale { return Theme.muted }
    switch level {
    case .fault: return Theme.danger
    case .warn: return Theme.amber
    case .ok: return Theme.ok
    }
}

func levelIcon(_ level: CellLevel) -> String {
    switch level {
    case .fault: return "exclamationmark.octagon.fill"
    case .warn: return "exclamationmark.triangle.fill"
    case .ok: return "checkmark.circle.fill"
    }
}

/// A soft pulse (once a second by default) for a fault; steady when there is none or when the person asked the phone to reduce motion.
struct FaultBlink: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let active: Bool
    let periodMs: Int
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(active && !reduceMotion && dim ? 0.4 : 1)
            .onAppear {
                guard active && !reduceMotion else { return }
                let half = Double(max(periodMs, SolarViewSettings.fastestBlinkMs)) / 2000
                withAnimation(.easeInOut(duration: half).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

/// Icon, word and colour together: the state is never told by the colour alone.
struct LevelChip: View {
    @EnvironmentObject var model: AppModel
    let level: CellLevel
    let stale: Bool
    let settings: SolarViewSettings

    var body: some View {
        let color = levelColor(level, stale: stale)
        HStack(spacing: 4) {
            Image(systemName: levelIcon(level)).modifier(FaultBlink(active: level == .fault && !stale, periodMs: settings.blinkPeriodMs))
            Text(word)
        }
        .font(.caption2.weight(.bold)).foregroundColor(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(color, lineWidth: 1))
        .id(level)
    }

    private var word: String {
        switch level {
        case .fault: return model.tr("Fallo")
        case .warn: return model.tr("Aviso")
        case .ok: return model.tr("Correcto")
        }
    }
}

private struct CellTile: View {
    @EnvironmentObject var model: AppModel
    let cell: CellView
    let stale: Bool
    let settings: SolarViewSettings

    private var color: Color { levelColor(cell.level, stale: stale) }
    private var calm: Bool { cell.level == .ok }

    private var mark: String {
        if cell.highest { return "▲ " + model.tr("máx") }
        if cell.lowest { return "▼ " + model.tr("mín") }
        return ""
    }

    private var spokenLevel: String {
        switch cell.level {
        case .fault: return model.tr("Fallo")
        case .warn: return model.tr("Aviso")
        case .ok: return model.tr("Correcto")
        }
    }

    private var spoken: String {
        let name: String = model.trf("Celda %s", cell.number)
        let volts: String = SolarText.cell(cell.volts) + " V"
        let extra: String = mark.isEmpty ? "" : ", \(mark)"
        return "\(name): \(volts), \(spokenLevel)\(extra)"
    }

    private var header: some View {
        HStack(spacing: 3) {
            Text(String(cell.number)).font(.caption2).foregroundColor(Theme.muted)
            if !calm { Image(systemName: levelIcon(cell.level)).font(.caption2).foregroundColor(color) }
            Spacer(minLength: 0)
            Text(mark).font(.caption2).foregroundColor(cell.highest ? Theme.accent : Theme.amber)
        }
    }

    private var bar: some View {
        GeometryReader { space in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.muted.opacity(0.25))
                Capsule().fill(color).frame(width: space.size.width * CGFloat(cell.fill))
            }
        }.frame(height: 5)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(color.opacity(calm ? 0.35 : 1), lineWidth: calm ? 1 : 2)
            .modifier(FaultBlink(active: cell.level == .fault && !stale, periodMs: settings.blinkPeriodMs))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            Text(SolarText.cell(cell.volts) + " V").font(.system(.footnote, design: .monospaced)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            bar
        }
        .padding(6)
        .background(color.opacity(calm ? 0.10 : 0.22), in: RoundedRectangle(cornerRadius: 10))
        .overlay(border)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}

/// One module of a stack: its state, its numbers, what is wrong, every cell, and on request what it says about itself.
struct ModuleSection: View {
    @EnvironmentObject var model: AppModel
    @ScaledMetric(relativeTo: .footnote) private var scale: CGFloat = 1
    @State private var details = false
    let device: SolarDevice
    let view: ModuleView
    let settings: SolarViewSettings

    var body: some View {
        let module = view.module
        let color = levelColor(view.level, stale: device.stale)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.trf("Módulo %s", module.number)).font(.subheadline.weight(.semibold))
                Spacer()
                LevelChip(level: view.level, stale: device.stale, settings: settings)
            }
            Text(summary).font(.caption).foregroundColor(Theme.muted)
            if let soc = module.socPercent { ProgressView(value: Double(min(100, max(0, soc))), total: 100).tint(device.stale ? Theme.muted : socColor(soc)) }
            ForEach(troubleLines, id: \.self) { line in
                Label(line, systemImage: levelIcon(view.level)).font(.caption2).foregroundColor(color)
            }
            if view.cells.isEmpty {
                Text(model.tr("Sin lectura de celdas")).font(.caption2).foregroundColor(Theme.muted)
            } else {
                // As many tiles to a row as fit without cutting a voltage; larger text, wider tiles.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: CGFloat(settings.minCellTileDp) * max(1, scale)), spacing: 6)], spacing: 6) {
                    ForEach(view.cells) { cell in CellTile(cell: cell, stale: device.stale, settings: settings) }
                }
            }
            if !module.temperaturesC.isEmpty {
                Text(model.tr("Sensores: ") + module.temperaturesC.map { SolarText.celsius($0) }.joined(separator: " · ")).font(.caption2).foregroundColor(Theme.muted)
            }
            if let today = device.dayCells?.modules.first(where: { $0.number == module.number }) {
                Text(todayLine(today)).font(.caption2).foregroundColor(Theme.muted)
            }
            Button(details ? model.tr("Ocultar detalles") : model.tr("Ver detalles")) { details.toggle() }
                .buttonStyle(.borderless).font(.caption)
            if details { detailLines(module) }
        }
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.45), lineWidth: 1))
    }

    private var summary: String {
        let module = view.module
        let state: String
        switch module.state {
        case "Charge": state = model.tr("Cargando")
        case "Dischg": state = model.tr("Descargando")
        case "Idle": state = model.tr("En reposo")
        default: state = module.state
        }
        var parts: [String] = []
        if let soc = module.socPercent { parts.append(SolarText.percent(soc)) }
        if let volts = module.voltageV { parts.append(SolarText.volts(volts, 2)) }
        if let amps = module.currentA { parts.append(SolarText.amps(amps, 2)) }
        if let temperature = module.temperatureC { parts.append(SolarText.celsius(temperature)) }
        parts.append(state)
        if let spread = view.spreadMv { parts.append("Δ \(spread) mV") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var troubleLines: [String] {
        let t = view.trouble
        var lines: [String] = []
        if !t.state.isEmpty { lines.append(model.trf("El módulo informa el estado %s", t.state)) }
        if !t.abnormalCells.isEmpty { lines.append(model.tr("Celda anormal") + ": " + t.abnormalCells.map(String.init).joined(separator: ", ")) }
        if !t.outOfRangeCells.isEmpty { lines.append(model.trf("Tensión fuera de rango en las celdas %s", t.outOfRangeCells.map(String.init).joined(separator: ", "))) }
        if let spread = t.spreadMv { lines.append(model.trf("Diferencia alta entre celdas: %s mV", spread)) }
        if t.hot { lines.append(model.tr("Temperatura alta")) }
        if t.cold { lines.append(model.tr("Demasiado frío para cargar")) }
        if t.missingCells > 0 { lines.append(model.trf("Leídas %s de %s celdas", view.cells.count, view.cells.count + t.missingCells)) }
        return lines
    }

    private func todayLine(_ today: ModuleDayCells) -> String {
        let word = model.tr("celda")
        let low = SolarText.reach(volts: today.minV, cell: today.minCell, atMs: today.minAt, cellWord: word)
        let high = SolarText.reach(volts: today.maxV, cell: today.maxCell, atMs: today.maxAt, cellWord: word)
        let gap = String(Int((today.deltaV * 1000).rounded()))
        return model.tr("Celdas hoy") + ": " + low + " – " + high + " · Δ " + gap + " mV"
    }

    private func allowedCurrent(_ module: SolarModule) -> String {
        let charge: String = module.maxChargeA.map { String(Int($0.rounded())) } ?? "–"
        let discharge: String = module.maxDischargeA.map { String(Int($0.rounded())) } ?? "–"
        return charge + " / " + discharge + " A"
    }

    @ViewBuilder private func detailLines(_ module: SolarModule) -> some View {
        if !module.model.isEmpty { ValueLine(label: model.tr("Modelo"), value: module.model) }
        let versions = [module.boardVersion, module.mainSoftVersion, module.softVersion].filter { !$0.isEmpty }
        if !versions.isEmpty { ValueLine(label: model.tr("Firmware"), value: versions.joined(separator: " · ")) }
        if let cells = module.cellCount { ValueLine(label: model.tr("Celdas"), value: String(cells)) }
        if module.maxChargeA != nil || module.maxDischargeA != nil {
            ValueLine(label: model.tr("Corriente admitida (carga / descarga)"), value: allowedCurrent(module))
        }
        if let baud = module.consoleBaud { ValueLine(label: model.tr("Velocidad de la consola"), value: String(baud)) }
        if !module.sohCounts.isEmpty {
            let weak = SolarText.abnormalCells(module)
            let counts = module.sohCounts.enumerated().map { "\($0.offset + 1):\($0.element)" }.joined(separator: " · ")
            Text(model.tr("Estado de salud de las celdas") + ": " + counts).font(.caption2).foregroundColor(weak.isEmpty ? Theme.muted : Theme.amber)
            Text(model.tr("El recuento de cada celda tal como lo informa la consola de la batería; Abnormal es la palabra de la propia consola para la celda débil. Solo lectura.")).font(.caption2).foregroundColor(Theme.muted)
        }
        let raised = SolarText.raisedCounters(module.counters)
        if !raised.isEmpty {
            Text(model.tr("Contadores de protección") + ": " + raised).font(.caption2).foregroundColor(Theme.amber)
            Text(model.tr("Nombres de la consola de la batería; su significado no es oficial.")).font(.caption2).foregroundColor(Theme.muted)
        }
    }
}
