// ARMOR-IOS-CONTROL - the history of the solar equipment the server keeps (GET /api/v1/solar/history): its parsing and the arithmetic of the charts, the same as the Android app and Studio.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// One moment of a history: the numbers it carries by the server's own names (voltage_v, soc_percent, cell1...). A number the server did not record is simply not there.
public struct HistorySample: Equatable, Sendable {
    public let t: Int64
    public let values: [String: Double]
    public init(t: Int64, values: [String: Double]) { self.t = t; self.values = values }
}

/// What the server answered: `module` is nil for a stack or an inverter, and also from a server that predates the history by battery.
public struct SolarHistory: Equatable, Sendable {
    public let module: Int?, everyS: Int?, retentionDays: Int?
    public let samples: [HistorySample]
    public init(module: Int?, everyS: Int?, retentionDays: Int?, samples: [HistorySample]) {
        self.module = module; self.everyS = everyS; self.retentionDays = retentionDays; self.samples = samples
    }
}

/// What is asked: the equipment, how far back and, for one battery and its cells, its module.
public struct HistoryRequest: Equatable, Hashable, Sendable {
    public let node: String, device: String
    public let minutes: Int
    public let module: Int?
    public init(node: String, device: String, minutes: Int, module: Int? = nil) {
        self.node = node; self.device = device; self.minutes = minutes; self.module = module
    }
}

public enum SolarHistoryMath {
    /// The ranges of Studio, in minutes: 1 h, 6 h, 24 h, 7 days and 30 days.
    public static let ranges: [(minutes: Int, label: String)] = [(60, "1 h"), (360, "6 h"), (1440, "24 h"), (10_080, "7 d"), (43_200, "30 d")]

    public static func parse(_ root: JSON) -> SolarHistory {
        let list = root["samples"] as? [Any] ?? []
        let samples: [HistorySample] = list.compactMap { entry in
            guard let item = entry as? [String: Any], let t = (item["t"] as? NSNumber)?.int64Value, t >= 0 else { return nil }
            var values: [String: Double] = [:]
            for (key, raw) in item where key != "t" {
                if let number = raw as? NSNumber, number.doubleValue.isFinite { values[key] = number.doubleValue }
            }
            return HistorySample(t: t, values: values)
        }
        func whole(_ key: String) -> Int? { (root[key] as? NSNumber)?.intValue }
        return SolarHistory(module: whole("module"), everyS: whole("every_s"), retentionDays: whole("retention_days"), samples: samples)
    }

    /// A stack's samples with the power and the spread of the cells worked out from what they carry.
    public static func derived(_ samples: [HistorySample]) -> [HistorySample] {
        samples.map { sample in
            var values = sample.values
            if let voltage = values["voltage_v"], let current = values["current_a"] { values["power_w"] = voltage * current }
            if let low = values["cell_min_v"], let high = values["cell_max_v"] { values["delta_mv"] = ((high - low) * 1000).rounded() }
            return HistorySample(t: sample.t, values: values)
        }
    }

    public static func bankBucketMs(_ minutes: Int) -> Int64 { max(60_000, (Int64(minutes) * 60_000 + 599) / 600) }

    /// The history of the whole bank from the histories of its stacks, in steps of `bucketMs`. A step is given only when every stack that has a history said something in it: a sum with a
    /// stack missing would look like a drop. Currents, powers and energies add up; the voltage and the charge are the mean; the extremes are the extremes.
    public static func mergeBank(_ histories: [[HistorySample]], bucketMs: Int64) -> [HistorySample] {
        let used = histories.filter { !$0.isEmpty }
        if used.isEmpty { return [] }
        var buckets: [Int64: [Int: HistorySample]] = [:]
        for (index, history) in used.enumerated() {
            for sample in derived(history) { buckets[(sample.t / bucketMs) * bucketMs, default: [:]][index] = sample }   // the last of the step
        }
        return buckets.keys.sorted().compactMap { t in
            let filled = Array(buckets[t, default: [:]].values)
            if filled.count < used.count { return nil }
            var merged: [String: Double] = [:]
            func put(_ key: String, everyStack: Bool, _ how: ([Double]) -> Double) {
                let values = filled.compactMap { $0.values[key] }
                if !values.isEmpty && (!everyStack || values.count == used.count) { merged[key] = how(values) }
            }
            let sum: ([Double]) -> Double = { $0.reduce(0, +) }
            let mean: ([Double]) -> Double = { $0.reduce(0, +) / Double($0.count) }
            put("current_a", everyStack: true, sum)
            put("power_w", everyStack: true, sum)
            put("energy_kwh", everyStack: true, sum)
            put("voltage_v", everyStack: false, mean)
            put("soc_percent", everyStack: false, mean)
            put("temperature_max_c", everyStack: false) { $0.max() ?? 0 }
            put("cell_min_v", everyStack: false) { $0.min() ?? 0 }
            put("cell_max_v", everyStack: false) { $0.max() ?? 0 }
            if let low = merged["cell_min_v"], let high = merged["cell_max_v"] { merged["delta_mv"] = ((high - low) * 1000).rounded() }
            return HistorySample(t: t, values: merged)
        }
    }

    /// The ends of the vertical axis: round numbers around the values; a flat line gets room above and below.
    public static func scale(_ values: [Double], ticks: Int = 4) -> (low: Double, high: Double) {
        guard var low = values.min(), var high = values.max() else { return (0, 1) }
        if low == high { low -= 1; high += 1 }
        if low > 0 && low < (high - low) * 0.5 { low = 0 }
        let raw = (high - low) / Double(max(1, ticks))
        let magnitude = pow(10.0, floor(log10(raw)))
        let norm = raw / magnitude
        let step = (norm < 1.5 ? 1.0 : norm < 3 ? 2.0 : norm < 7 ? 5.0 : 10.0) * magnitude
        return (floor(low / step) * step, ceil(high / step) * step)
    }

    /// The levels worth drawing: those no further from the data than the data is wide, so a far one never flattens the curves.
    public static func levelsInView(_ values: [Double], _ levels: [Double]) -> [Double] {
        guard let low = values.min(), let high = values.max() else { return [] }
        let reach = max(high - low, abs(high) * 0.1, 0.1)
        return levels.filter { $0 >= low - reach && $0 <= high + reach }
    }

    /// The sample nearest to a moment.
    public static func nearest(_ samples: [HistorySample], _ t: Int64) -> HistorySample? { samples.min { abs($0.t - t) < abs($1.t - t) } }

    /// A step longer than this between two samples is a gap: the line is broken there instead of being drawn across it.
    public static func gapMs(_ samples: [HistorySample]) -> Int64 {
        if samples.count < 3 { return Int64.max }
        let steps = zip(samples, samples.dropFirst()).map { $1.t - $0.t }.sorted()
        return max(1, steps[steps.count / 2]) * 4
    }
}
