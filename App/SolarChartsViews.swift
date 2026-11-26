// ARMOR-IOS-CONTROL - the charts of the Solar screen: the history the server keeps of the bank, each stack, each battery, its cells and each inverter, in sections that fold away and
// stay as the person left them (the same as the Android app).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

private let refreshSeconds: UInt64 = 30

/// A section with a header that folds it away; what is folded is not asked of the server, and the phone remembers it.
struct Foldable<Content: View>: View {
    @EnvironmentObject var model: AppModel
    @AppStorage private var open: Bool
    private let title: String
    private let content: () -> Content

    init(_ key: String, _ title: String, open: Bool, @ViewBuilder content: @escaping () -> Content) {
        _open = AppStorage(wrappedValue: open, "solar.open." + key)
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { open.toggle() } label: {
                HStack {
                    Image(systemName: open ? "chevron.up" : "chevron.down").foregroundColor(Theme.muted)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                    Spacer()
                }.contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityHint(open ? model.tr("Ocultar") : model.tr("Mostrar"))
            if open { content() }
        }
    }
}

private struct Curve: Identifiable {
    let key: String, label: String
    let color: Color
    var id: String { key }
}

/// A colour for each cell, spread around the wheel so neighbours differ.
private func cellColour(_ index: Int) -> Color { Color(hue: Double((index * 137) % 360) / 360, saturation: 0.6, brightness: 0.95) }

private func clock(_ t: Int64, span: Int64) -> String {
    let format = DateFormatter()
    format.dateFormat = span > 36 * 3_600_000 ? "dd/MM" : "HH:mm"
    return format.string(from: Date(timeIntervalSince1970: Double(t) / 1000))
}

/// An end of the time axis: over a day or more the hour alone would read the same at both ends.
private func edge(_ t: Int64, span: Int64) -> String {
    if span < 86_400_000 || span > 36 * 3_600_000 { return clock(t, span: span) }
    let format = DateFormatter()
    format.dateFormat = "dd/MM HH:mm"
    return format.string(from: Date(timeIntervalSince1970: Double(t) / 1000))
}

private func number(_ value: Double, _ decimals: Int) -> String { String(format: "%.\(decimals)f", value) }

/// The lines of one chart on one scale, the alarm levels dashed.
private struct Plot: View {
    let samples: [HistorySample]
    let curves: [Curve]
    let from: Int64, to: Int64
    let low: Double, high: Double
    let levels: [Double]
    var read: Int64? = nil

    var body: some View {
        Canvas { context, size in
            let span = Double(max(1, to - from)), rise = max(1e-9, high - low)
            let gap = SolarHistoryMath.gapMs(samples)
            func x(_ t: Int64) -> CGFloat { CGFloat(Double(t - from) / span) * size.width }
            func y(_ value: Double) -> CGFloat { size.height - CGFloat((value - low) / rise) * size.height }
            for part in 1...3 {
                let at = size.height * CGFloat(part) / 4
                var line = Path(); line.move(to: CGPoint(x: 0, y: at)); line.addLine(to: CGPoint(x: size.width, y: at))
                context.stroke(line, with: .color(Theme.muted.opacity(0.25)), lineWidth: 0.5)
            }
            for level in levels {
                var line = Path(); line.move(to: CGPoint(x: 0, y: y(level))); line.addLine(to: CGPoint(x: size.width, y: y(level)))
                context.stroke(line, with: .color(Theme.danger), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            for curve in curves {
                var path = Path()
                var last: Int64?
                for sample in samples {
                    guard let value = sample.values[curve.key] else { continue }
                    let point = CGPoint(x: x(sample.t), y: y(value))
                    if let before = last, sample.t - before <= gap { path.addLine(to: point) } else { path.move(to: point) }
                    last = sample.t
                }
                context.stroke(path, with: .color(curve.color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            if let read = read {
                var line = Path(); line.move(to: CGPoint(x: x(read), y: 0)); line.addLine(to: CGPoint(x: x(read), y: size.height))
                context.stroke(line, with: .color(.white.opacity(0.7)), lineWidth: 1)
            }
        }
    }
}

/// One chart with its title, which folds it away, its axis ends, its legend and the figures under the finger (or the latest).
private struct HistoryChart: View {
    @EnvironmentObject var model: AppModel
    let id: String, title: String, unit: String
    let decimals: Int
    let samples: [HistorySample]
    let curves: [Curve]
    let from: Int64, to: Int64
    var levels: [Double] = []
    @State private var read: Int64?

    var body: some View {
        Foldable("chart/" + id, title, open: true) {
            let inside = samples.filter { $0.t >= from && $0.t <= to }
            let drawn = curves.filter { curve in inside.contains { $0.values[curve.key] != nil } }
            if inside.count < 2 || drawn.isEmpty {
                Text(model.tr("Sin historial todavía")).font(.caption).foregroundColor(Theme.muted)
            } else {
                chart(inside, drawn)
            }
        }
    }

    @ViewBuilder private func chart(_ inside: [HistorySample], _ drawn: [Curve]) -> some View {
        let values: [Double] = inside.flatMap { sample in drawn.compactMap { sample.values[$0.key] } }
        let shown = SolarHistoryMath.levelsInView(values, levels)
        let scale = SolarHistoryMath.scale(values + shown)
        let at = read.flatMap { SolarHistoryMath.nearest(inside, $0) }
        HStack {
            Text(number(scale.high, decimals) + " " + unit)
            Spacer()
            Text(clock(at?.t ?? inside[inside.count - 1].t, span: to - from)).foregroundColor(.white)
        }.font(.caption2).foregroundColor(Theme.muted)
        GeometryReader { box in
            Plot(samples: inside, curves: drawn, from: from, to: to, low: scale.low, high: scale.high, levels: shown, read: at?.t)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in read = from + Int64(Double(tap.location.x / max(1, box.size.width)) * Double(to - from)) })
        }
        .frame(height: 130)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.muted.opacity(0.35)))
        .accessibilityLabel(title)
        HStack {
            Text(number(scale.low, decimals) + " " + unit)
            Spacer()
            Text(edge(from, span: to - from) + " – " + edge(to, span: to - from))
        }.font(.caption2).foregroundColor(Theme.muted)
        if drawn.count <= 4 {
            ForEach(drawn) { curve in
                Text(legend(curve, inside, at)).font(.caption2).foregroundColor(curve.color)
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), alignment: .leading, spacing: 2) {
                ForEach(drawn) { curve in
                    let now = at?.values[curve.key] ?? inside.last { $0.values[curve.key] != nil }?.values[curve.key]
                    Text("● " + curve.label + " " + (now.map { number($0, decimals) } ?? "–")).font(.caption2).foregroundColor(curve.color)
                }
            }
        }
    }

    private func legend(_ curve: Curve, _ inside: [HistorySample], _ at: HistorySample?) -> String {
        let all = inside.compactMap { $0.values[curve.key] }
        let now = at?.values[curve.key] ?? all.last ?? 0
        let reach = model.tr("mín") + " " + number(all.min() ?? 0, decimals) + " · " + model.tr("máx") + " " + number(all.max() ?? 0, decimals)
        return "● " + curve.label + ": " + number(now, decimals) + " " + unit + " · " + reach
    }
}

private struct RangePicker: View {
    @Binding var minutes: Int
    var body: some View {
        Picker("", selection: $minutes) {
            ForEach(SolarHistoryMath.ranges, id: \.minutes) { range in Text(range.label).tag(range.minutes) }
        }.pickerStyle(.segmented).labelsHidden()
    }
}

private struct Loaded {
    let requests: [HistoryRequest]
    let answers: [SolarHistory?]
    let asked: Int64
}

/// Asks the server for some histories, again every half minute while the charts are open; an answer about something else is never drawn.
private struct HistoryReader<Content: View>: View {
    @EnvironmentObject var model: AppModel
    let requests: [HistoryRequest]
    @ViewBuilder let content: (_ answers: [SolarHistory?], _ now: Int64) -> Content
    @State private var loaded: Loaded?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let loaded = loaded, loaded.requests == requests {
                if loaded.answers.allSatisfy({ $0 == nil }) {
                    Text(model.tr("No se pudo leer el historial")).font(.caption).foregroundColor(Theme.amber)
                } else {
                    content(loaded.answers, loaded.asked)
                }
            } else {
                Text(model.tr("Cargando…")).font(.caption).foregroundColor(Theme.muted)
            }
        }
        .task(id: requests) {
            while !Task.isCancelled {
                var answers: [SolarHistory?] = []
                for request in requests {
                    guard let origin = model.activeOrigin else { answers.append(nil); continue }
                    answers.append(try? await model.controller.api.solarHistory(origin, request: request))
                }
                if Task.isCancelled { return }
                loaded = Loaded(requests: requests, answers: answers, asked: Int64(Date().timeIntervalSince1970 * 1000))
                try? await Task.sleep(nanoseconds: refreshSeconds * 1_000_000_000)
            }
        }
    }
}

/// The figures a stack, the bank or one battery have in common.
private struct BatteryFigures: View {
    @EnvironmentObject var model: AppModel
    let id: String
    let samples: [HistorySample]
    let temperatureKey: String
    let from: Int64, to: Int64
    let cellLevels: [Double]
    let settings: SolarViewSettings

    var body: some View {
        one("voltage", model.tr("Tensión"), "V", 2, [Curve(key: "voltage_v", label: model.tr("Tensión"), color: .cyan)])
        one("current", model.tr("Corriente"), "A", 1, [Curve(key: "current_a", label: model.tr("Corriente"), color: Theme.amber)])
        one("power", model.tr("Potencia"), "W", 0, [Curve(key: "power_w", label: model.tr("Potencia"), color: .blue)])
        one("soc", model.tr("Nivel de carga"), "%", 0, [Curve(key: "soc_percent", label: model.tr("Nivel de carga"), color: Theme.ok)])
        one("temperature", model.tr("Temperatura"), "°C", 1, [Curve(key: temperatureKey, label: model.tr("Temperatura"), color: Theme.danger)], [settings.hotC, settings.coldChargeC])
        one("range", model.tr("Celda más alta y más baja"), "V", 3, [Curve(key: "cell_max_v", label: model.tr("máx"), color: .cyan), Curve(key: "cell_min_v", label: model.tr("mín"), color: Theme.amber)], cellLevels)
        one("delta", model.tr("Diferencia"), "mV", 0, [Curve(key: "delta_mv", label: model.tr("Diferencia"), color: Theme.amber)], [Double(settings.spreadWarnMv)])
    }

    private func one(_ what: String, _ title: String, _ unit: String, _ decimals: Int, _ curves: [Curve], _ levels: [Double] = []) -> some View {
        HistoryChart(id: id + "/" + what, title: title, unit: unit, decimals: decimals, samples: samples, curves: curves, from: from, to: to, levels: levels)
    }
}

/// The whole bank: every stack added up, moment by moment.
struct BankCharts: View {
    @EnvironmentObject var model: AppModel
    let batteries: [SolarDevice]
    @AppStorage("solar.range.bank") private var minutes = 1440

    var body: some View {
        Foldable("bank", model.tr("Gráficas del banco"), open: false) {
            RangePicker(minutes: $minutes)
            HistoryReader(requests: batteries.map { HistoryRequest(node: $0.nodeId, device: $0.device, minutes: minutes) }) { answers, now in
                let samples = SolarHistoryMath.mergeBank(answers.map { $0?.samples ?? [] }, bucketMs: SolarHistoryMath.bankBucketMs(minutes))
                BatteryFigures(id: "bank", samples: samples, temperatureKey: "temperature_max_c", from: now - Int64(minutes) * 60_000, to: now, cellLevels: [], settings: SolarViewSettings.bundled())
            }
        }
    }
}

private enum Scope: Int, CaseIterable { case stack = 0, battery, cells }

/// The history of one socket: the stack as a whole, one of its batteries, or the cells of one of its batteries.
struct BatteryHistoryCharts: View {
    @EnvironmentObject var model: AppModel
    let device: SolarDevice
    let reading: SolarBatteryReading
    @AppStorage private var scope: Int
    @AppStorage private var minutes: Int
    @AppStorage private var chosen: Int

    init(device: SolarDevice, reading: SolarBatteryReading) {
        self.device = device
        self.reading = reading
        _scope = AppStorage(wrappedValue: 0, "solar.scope." + device.id)
        _minutes = AppStorage(wrappedValue: 1440, "solar.range." + device.id)
        _chosen = AppStorage(wrappedValue: 0, "solar.module." + device.id)
    }

    var body: some View {
        Foldable("battery/" + device.id, model.tr("Gráficas"), open: false) {
            Picker("", selection: $scope) {
                Text(model.tr("Pack")).tag(Scope.stack.rawValue)
                Text(model.tr("Batería")).tag(Scope.battery.rawValue)
                Text(model.tr("Celdas")).tag(Scope.cells.rawValue)
            }.pickerStyle(.segmented).labelsHidden()
            RangePicker(minutes: $minutes)
            let modules = reading.stack.filter { $0.present }
            let module = modules.first { $0.number == chosen } ?? modules.first
            if scope != Scope.stack.rawValue && modules.count > 1 {
                Picker(model.tr("Batería"), selection: Binding(get: { module?.number ?? 0 }, set: { chosen = $0 })) {
                    ForEach(modules, id: \.number) { item in Text(model.trf("Módulo %s", item.number)).tag(item.number) }
                }.pickerStyle(.menu)
            }
            let wanted = scope == Scope.stack.rawValue ? nil : module?.number
            Text(model.tr("Toca una gráfica para leer un momento.")).font(.caption2).foregroundColor(Theme.muted)
            HistoryReader(requests: [HistoryRequest(node: device.nodeId, device: device.device, minutes: minutes, module: wanted)]) { answers, now in
                if let answer = answers.first ?? nil { charts(answer, now: now, wanted: wanted, module: module) }
            }
        }
    }

    @ViewBuilder private func charts(_ answer: SolarHistory, now: Int64, wanted: Int?, module: SolarModule?) -> some View {
        if wanted != nil && answer.module == nil {
            Text(model.tr("Este servidor todavía no guarda el histórico por batería y celda: actualiza ARMOR-SERVER.")).font(.caption).foregroundColor(Theme.amber)
        } else {
            let settings = SolarViewSettings.bundled()
            let lfp = module.map { SolarCells.isLfp(deviceModel: device.model, readingModel: $0.model.isEmpty ? reading.model : $0.model) } ?? false
            let levels = lfp ? [settings.cell.faultHighV, settings.cell.faultLowV] : []
            let from = now - Int64(minutes) * 60_000
            let samples = wanted == nil ? SolarHistoryMath.derived(answer.samples) : answer.samples
            let id = device.id + "/" + String(module?.number ?? 0)
            if wanted != nil { Text(note(answer)).font(.caption2).foregroundColor(Theme.muted) }
            if scope == Scope.cells.rawValue {
                CellCharts(id: id, device: device, view: module.map { SolarCells.module($0, lfp: lfp, settings: settings) }, samples: samples, from: from, to: now, levels: levels, settings: settings)
            } else if scope == Scope.battery.rawValue {
                BatteryFigures(id: id + "/battery", samples: samples, temperatureKey: "temperature_c", from: from, to: now, cellLevels: levels, settings: settings)
            } else {
                BatteryFigures(id: device.id + "/stack", samples: samples, temperatureKey: "temperature_max_c", from: from, to: now, cellLevels: levels, settings: settings)
            }
        }
    }

    private func note(_ answer: SolarHistory) -> String {
        if answer.retentionDays == 0 { return model.tr("Este servidor no registra histórico por batería y celda.") }
        return model.trf("El servidor registra cada batería y celda: un punto cada %s segundos durante el último día y medias de cinco minutos durante %s días.", answer.everyS ?? 0, answer.retentionDays ?? 0)
    }
}

/// The cells of one battery together, their spread and, if the person asks, one small chart for each cell on a common scale.
private struct CellCharts: View {
    @EnvironmentObject var model: AppModel
    let id: String
    let device: SolarDevice
    let view: ModuleView?
    let samples: [HistorySample]
    let from: Int64, to: Int64
    let levels: [Double]
    let settings: SolarViewSettings
    @AppStorage("solar.smallCells") private var small = false

    var body: some View {
        let cells = view?.cells ?? []
        Toggle(model.tr("Una gráfica pequeña por cada celda"), isOn: $small).font(.footnote)
        if small { smallCharts(cells) }
        HistoryChart(id: id + "/cells", title: model.tr("Celdas"), unit: "V", decimals: 3, samples: samples,
                     curves: cells.map { Curve(key: "cell\($0.number)", label: String($0.number), color: cellColour($0.number - 1)) }, from: from, to: to, levels: levels)
        HistoryChart(id: id + "/cells-delta", title: model.tr("Diferencia"), unit: "mV", decimals: 0, samples: samples,
                     curves: [Curve(key: "delta_mv", label: model.tr("Diferencia"), color: Theme.amber)], from: from, to: to, levels: [Double(settings.spreadWarnMv)])
    }

    @ViewBuilder private func smallCharts(_ cells: [CellView]) -> some View {
        let inside = samples.filter { $0.t >= from && $0.t <= to }
        let all: [Double] = inside.flatMap { sample in cells.compactMap { sample.values["cell\($0.number)"] } }
        let shown = SolarHistoryMath.levelsInView(all, levels)
        let scale = SolarHistoryMath.scale(all + shown)
        Text(model.tr("Todas las gráficas pequeñas usan la misma escala; las líneas discontinuas son los niveles de alarma de las celdas.")).font(.caption2).foregroundColor(Theme.muted)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 6)], spacing: 6) {
            ForEach(cells) { cell in
                let color = levelColor(cell.level, stale: device.stale)
                let own = inside.compactMap { $0.values["cell\(cell.number)"] }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 3) {
                        if cell.level != .ok { Image(systemName: levelIcon(cell.level)).foregroundColor(color) }
                        Text(model.trf("Celda %s", cell.number) + " · " + number(cell.volts, 3) + " V")
                    }.font(.caption2)
                    if own.count < 2 {
                        Text(model.tr("Sin historial todavía")).font(.caption2).foregroundColor(Theme.muted)
                    } else {
                        Plot(samples: inside, curves: [Curve(key: "cell\(cell.number)", label: "", color: cell.level == .ok ? .cyan : color)], from: from, to: to, low: scale.low, high: scale.high, levels: shown)
                            .frame(height: 40)
                        Text(model.tr("mín") + " " + number(own.min() ?? 0, 3) + " · " + model.tr("máx") + " " + number(own.max() ?? 0, 3)).font(.caption2).foregroundColor(Theme.muted)
                    }
                }
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cell.level == .ok ? Theme.muted.opacity(0.35) : color, lineWidth: cell.level == .ok ? 1 : 2)
                    .modifier(FaultBlink(active: cell.level == .fault && !device.stale, periodMs: settings.blinkPeriodMs)))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The history of an inverter: the sun, the consumption, its battery and the grid.
struct InverterHistoryCharts: View {
    @EnvironmentObject var model: AppModel
    let device: SolarDevice
    @AppStorage private var minutes: Int

    init(device: SolarDevice) {
        self.device = device
        _minutes = AppStorage(wrappedValue: 1440, "solar.range." + device.id)
    }

    var body: some View {
        Foldable("inverter/" + device.id, model.tr("Gráficas"), open: false) {
            RangePicker(minutes: $minutes)
            HistoryReader(requests: [HistoryRequest(node: device.nodeId, device: device.device, minutes: minutes)]) { answers, now in
                let samples = (answers.first ?? nil)?.samples ?? []
                let from = now - Int64(minutes) * 60_000
                one("power", model.tr("Sol y consumo"), "W", 0, samples, [Curve(key: "pv_w", label: model.tr("Sol"), color: Theme.amber), Curve(key: "out_w", label: model.tr("Consumo"), color: .cyan)], from, now)
                one("battery-v", model.tr("Tensión de la batería"), "V", 2, samples, [Curve(key: "battery_v", label: model.tr("Tensión"), color: .cyan)], from, now)
                one("battery-a", model.tr("Corriente de la batería"), "A", 1, samples, [Curve(key: "battery_a", label: model.tr("Corriente"), color: Theme.amber)], from, now)
                one("battery-soc", model.tr("Nivel de carga"), "%", 0, samples, [Curve(key: "battery_percent", label: model.tr("Nivel de carga"), color: Theme.ok)], from, now)
                one("grid", model.tr("Tensión de la red"), "V", 1, samples, [Curve(key: "grid_v", label: model.tr("Red"), color: .blue)], from, now)
            }
        }
    }

    private func one(_ what: String, _ title: String, _ unit: String, _ decimals: Int, _ samples: [HistorySample], _ curves: [Curve], _ from: Int64, _ to: Int64) -> some View {
        HistoryChart(id: device.id + "/" + what, title: title, unit: unit, decimals: decimals, samples: samples, curves: curves, from: from, to: to)
    }
}
