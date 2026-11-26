// ARMOR-IOS-CONTROL - how the cells of a battery are judged: pure rules, with their levels read from Resources/solar_view.json (the same rules as the Android app).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The order matters: the worst of two levels is the greater one.
public enum CellLevel: Int, Comparable, Sendable {
    case ok = 0, warn, fault
    public static func < (a: CellLevel, b: CellLevel) -> Bool { a.rawValue < b.rawValue }
}

/// The voltages of a lithium iron phosphate cell: the ends of its bar, the range outside which it is worth a look and the range outside which it is a fault.
public struct CellLimits: Equatable, Sendable {
    public let barEmptyV: Double, barFullV: Double, lowV: Double, highV: Double, faultLowV: Double, faultHighV: Double
}

public struct SolarViewSettings: Equatable, Sendable {
    /// A blink is never faster than twice a second, whatever the file says.
    public static let fastestBlinkMs = 500

    public var cell = CellLimits(barEmptyV: 2.8, barFullV: 3.65, lowV: 2.9, highV: 3.6, faultLowV: 2.7, faultHighV: 3.7)
    public var spreadWarnMv = 100
    public var hotC = 55.0
    public var coldChargeC = 0.0
    public var blinkPeriodMs = 1000
    public var minCellTileDp = 76

    public init() {}

    /// The settings of the file; a value that is missing or a file that cannot be read keeps the defaults.
    public static func parse(_ data: Data) -> SolarViewSettings {
        var out = SolarViewSettings()
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return out }
        func number(_ object: [String: Any], _ key: String, _ fallback: Double) -> Double { (object[key] as? NSNumber)?.doubleValue ?? fallback }
        let c = root["lfp_cell"] as? [String: Any] ?? [:]
        let d = out.cell
        out.cell = CellLimits(barEmptyV: number(c, "bar_empty_v", d.barEmptyV), barFullV: number(c, "bar_full_v", d.barFullV), lowV: number(c, "low_v", d.lowV),
                              highV: number(c, "high_v", d.highV), faultLowV: number(c, "fault_low_v", d.faultLowV), faultHighV: number(c, "fault_high_v", d.faultHighV))
        out.spreadWarnMv = Int(number(root, "spread_warn_mv", Double(out.spreadWarnMv)))
        out.hotC = number(root, "hot_c", out.hotC)
        out.coldChargeC = number(root, "cold_charge_c", out.coldChargeC)
        out.blinkPeriodMs = max(fastestBlinkMs, Int(number(root, "blink_period_ms", Double(out.blinkPeriodMs))))
        out.minCellTileDp = max(60, Int(number(root, "min_cell_tile_dp", Double(out.minCellTileDp))))
        return out
    }

    /// The file shipped inside the package.
    public static func bundled() -> SolarViewSettings {
        guard let url = Bundle.module.url(forResource: "solar_view", withExtension: "json"), let data = try? Data(contentsOf: url) else { return SolarViewSettings() }
        return parse(data)
    }
}

/// One cell as the screen draws it; `number` is counted from 1, `fill` is the length of its bar (0 to 1).
public struct CellView: Equatable, Sendable, Identifiable {
    public let number: Int
    public let volts: Double
    public let level: CellLevel
    public let lowest: Bool, highest: Bool, abnormal: Bool
    public let fill: Double
    public var id: Int { number }
}

/// Why a module is not well; the cells are counted from 1.
public struct ModuleTrouble: Equatable, Sendable {
    public let abnormalCells: [Int], outOfRangeCells: [Int]
    public let spreadMv: Int?
    public let hot: Bool, cold: Bool
    public let state: String
    public let missingCells: Int
}

public struct ModuleView: Equatable, Sendable, Identifiable {
    public let module: SolarModule
    public let cells: [CellView]
    public let level: CellLevel
    public let spreadMv: Int?
    public let trouble: ModuleTrouble
    public var id: Int { module.number }
}

public struct BankView: Equatable, Sendable {
    public let modules: [ModuleView]
    public let level: CellLevel
    public let minV: Double?, maxV: Double?
    public let spreadMv: Int?
    public var faultModules: Int { modules.filter { $0.level == .fault }.count }
    public var warnModules: Int { modules.filter { $0.level == .warn }.count }
}

public enum SolarCells {
    private static let faultWords = ["alarm", "protect", "fault", "error", "fail"]

    /// The absolute voltage of a cell is only judged for the batteries known to be lithium iron phosphate (Pylontech and Pytes): a BMS of another make may sit on another
    /// chemistry, where the same volts are normal. The gap between cells and the state of health the battery reports are judged for all.
    public static func isLfp(deviceModel: String, readingModel: String) -> Bool {
        let device = deviceModel.lowercased()
        if device.hasPrefix("ant") || readingModel.uppercased().hasPrefix("ANT") { return false }
        return device.hasPrefix("pylontech") || device.hasPrefix("pytes") || SolarText.generation(readingModel) > 0
    }

    public static func module(_ m: SolarModule, lfp: Bool, settings: SolarViewSettings) -> ModuleView {
        let low = m.cellsV.min(), high = m.cellsV.max()
        let spread = SolarText.cellSpreadMv(m.cellsV)
        let limits = settings.cell
        let cells: [CellView] = m.cellsV.enumerated().map { index, volts in
            let abnormal = m.sohAbnormal.contains(index)
            let differs = (spread ?? 0) > 0
            var level = CellLevel.ok
            if abnormal || (lfp && (volts < limits.faultLowV || volts > limits.faultHighV)) { level = .fault }
            else if lfp && (volts < limits.lowV || volts > limits.highV) { level = .warn }
            let fill = min(1, max(0, (volts - limits.barEmptyV) / (limits.barFullV - limits.barEmptyV)))
            return CellView(number: index + 1, volts: volts, level: level, lowest: differs && volts == low, highest: differs && volts == high, abnormal: abnormal, fill: fill)
        }
        let temperatures = m.temperaturesC + [m.temperatureC].compactMap { $0 }
        let charging = m.state.lowercased().hasPrefix("charg")
        let lowered = m.state.lowercased()
        let trouble = ModuleTrouble(
            abnormalCells: m.sohAbnormal.map { $0 + 1 },
            outOfRangeCells: cells.filter { !$0.abnormal && $0.level != .ok }.map(\.number),
            spreadMv: spread.flatMap { $0 >= settings.spreadWarnMv ? $0 : nil },
            hot: temperatures.contains { $0 > settings.hotC },
            cold: charging && temperatures.contains { $0 < settings.coldChargeC },
            state: faultWords.contains { lowered.contains($0) } ? m.state : "",
            missingCells: m.cellsV.isEmpty ? 0 : max(0, (m.cellCount ?? 0) - m.cellsV.count))
        let fromCells = cells.map(\.level).max() ?? .ok
        var level = CellLevel.ok
        if fromCells == .fault || !trouble.abnormalCells.isEmpty || !trouble.state.isEmpty { level = .fault }
        else if fromCells == .warn || trouble.spreadMv != nil || trouble.hot || trouble.cold || trouble.missingCells > 0 { level = .warn }
        return ModuleView(module: m, cells: cells, level: level, spreadMv: spread, trouble: trouble)
    }

    /// The whole bank: its worst module, a fault when the battery itself says a protection is acting, and the extremes of all its cells.
    public static func bank(deviceModel: String, reading: SolarBatteryReading, settings: SolarViewSettings) -> BankView {
        let modules = reading.stack.map { item in
            module(item, lfp: isLfp(deviceModel: deviceModel, readingModel: item.model.isEmpty ? reading.model : item.model), settings: settings)
        }
        let level: CellLevel = reading.alarm ? .fault : (modules.map(\.level).max() ?? .ok)
        let all = reading.stack.flatMap(\.cellsV)
        let minV = all.min() ?? reading.cellMinV
        let maxV = all.max() ?? reading.cellMaxV
        var spread: Int?
        if let minV, let maxV { spread = Int(((maxV - minV) * 1000).rounded()) }
        return BankView(modules: modules, level: level, minV: minV, maxV: maxV, spreadMv: spread)
    }
}
