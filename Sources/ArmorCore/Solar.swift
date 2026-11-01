// ARMOR-IOS-CONTROL - solar inverters and batteries: what the server reports, its parsing and its wording. The same reading as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The sums the server makes over the equipment that is reporting (a device that has gone quiet is left out of them).
public struct SolarTotals: Equatable, Sendable {
    public var inverters = 0
    public var batteries = 0
    public var stale = 0
    public var pvW = 0.0
    public var loadW = 0.0
    /// Positive while the batteries charge, negative while they discharge; nil when nothing reports it.
    public var batteryW: Double?
    public var socPercent: Int?
    public var capacityAh: Double?
    public var fullCapacityAh: Double?
    public var energyKwh: Double?
    public var gridPresent = false
    public var mode: String?
    public init() {}
}

/// One inverter of a parallel system, as the one on the node's port reports it.
public struct SolarUnit: Equatable, Sendable {
    public let unit: Int
    public let mode: String
    public let serial: String
    public let faultCode: String
    public let outW: Double?
    public let loadPercent: Double?
    public let batteryV: Double?
}

public struct SolarInverterReading: Equatable, Sendable {
    public let mode: String
    public let gridV: Double?, gridHz: Double?, outV: Double?, outHz: Double?, outVa: Double?, outW: Double?, loadPercent: Double?
    public let batteryV: Double?, batteryA: Double?, batteryPercent: Double?, pvV: Double?, pvA: Double?, pvW: Double?, heatsinkC: Double?
    public let acCharging: Bool, pvCharging: Bool, loadOn: Bool
    public let warnings: [String]
    /// A second PV input (pvW is already the sum of both) and, for a parallel system, the units the node reads and the total power of the system.
    public let pv2V: Double?, pv2A: Double?, pv2W: Double?
    public let units: [SolarUnit]
    public let totalOutW: Double?
}

/// One battery module of a stack; a BMS is one module.
public struct SolarModule: Equatable, Sendable {
    public let number: Int
    public let present: Bool
    public let voltageV: Double?, currentA: Double?, temperatureC: Double?
    public let socPercent: Int?
    public let state: String
    public let cellsV: [Double]
    public let temperaturesC: [Double]
    public let capacityAh: Double?, fullCapacityAh: Double?
    public let cycles: Int?, healthPercent: Int?
    /// The counters of the module's life by the console's own name (bat_ov_times ...); what they mean is not official.
    public let counters: [String: Int]
    /// What the module says about itself: its model (a stack may mix models), the versions of its board and software, its cells, the current it allows each way and its console's speed.
    public let model: String, boardVersion: String, mainSoftVersion: String, softVersion: String
    public let cellCount: Int?
    public let maxChargeA: Double?, maxDischargeA: Double?
    public let consoleBaud: Int?
    /// The state of health of each cell, in cell order, and the cells (0-based) the battery's console does not call Normal.
    public let sohCounts: [Int], sohAbnormal: [Int]
}

/// An entry of a battery's event log: the protection fields are the console's own words (a number and a mnemonic), never decoded.
public struct SolarEvent: Equatable, Sendable {
    public let index: Int
    public let time: String, voltageState: String, powerEvents: String, batteryEvents: String, systemFault: String
}

/// An entry of the log with the module it belongs to and the moment (milliseconds since 1970) the server saw it.
public struct LoggedEvent: Equatable, Sendable {
    public let module: Int
    public let seenAt: Int
    public let event: SolarEvent
}

public struct SolarBatteryReading: Equatable, Sendable {
    public let modules: Int
    public let model: String, state: String
    public let voltageV: Double?, currentA: Double?, temperatureMinC: Double?, temperatureMaxC: Double?, cellMinV: Double?, cellMaxV: Double?
    public let socPercent: Int?
    public let alarm: Bool
    public let capacityAh: Double?, fullCapacityAh: Double?, energyKwh: Double?
    public let cycles: Int?
    public let stack: [SolarModule]
    public let healthPercent: Int?
    /// Watts at the battery: positive while charging.
    public var powerW: Double? { if let voltageV, let currentA { return voltageV * currentA }; return nil }
}

/// The lowest and the highest cell of a module today, with the cell number and the moment (milliseconds since 1970), and the widest gap of the module.
public struct ModuleDayCells: Equatable, Sendable {
    public let number: Int
    public let minV: Double, maxV: Double
    public let minCell: Int, maxCell: Int
    public let minAt: Int, maxAt: Int
    public let deltaV: Double
}

/// What the server kept of the cells of a battery today (its own day): per module, and the widest gap of the whole bank.
public struct DayCells: Equatable, Sendable {
    public let modules: [ModuleDayCells]
    public let bankDeltaV: Double
}

/// A piece of equipment that has reported: exactly one of `inverter` and `battery` is set.
public struct SolarDevice: Equatable, Sendable, Identifiable {
    public let nodeId: String, device: String, name: String, model: String
    public let stale: Bool, example: Bool
    public let receivedAt: String
    public let inverter: SolarInverterReading?
    public let battery: SolarBatteryReading?
    public let dayCells: DayCells?
    public let events: [LoggedEvent]
    public var id: String { nodeId + "/" + device }
    public var isInverter: Bool { inverter != nil }
}

/// Equipment an operator declared in Studio that no gateway node has reported yet.
public struct SolarWaiting: Equatable, Sendable, Identifiable {
    public let nodeId: String, device: String, name: String, kind: String, model: String
    public var id: String { nodeId + "/" + device }
}

public struct SolarOverview: Equatable, Sendable {
    public var devices: [SolarDevice] = []
    public var waiting: [SolarWaiting] = []
    public var totals = SolarTotals()
    public init() {}
    public var isEmpty: Bool { devices.isEmpty && waiting.isEmpty }
}

public enum SolarParser {
    private static func numbers(_ list: Any?) -> [Double] { (list as? [Any])?.compactMap { ($0 as? Double) ?? ($0 as? Int).map { Double($0) } } ?? [] }
    private static func whole(_ json: JSON, _ key: String) -> Int? { json.double(key).map { Int($0.rounded()) } }
    private static func strings(_ list: Any?) -> [String] { (list as? [Any])?.compactMap { $0 as? String }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? [] }
    private static func ints(_ list: Any?) -> [Int] { numbers(list).map { Int($0) }.filter { $0 >= 0 } }

    public static func overview(_ root: JSON) -> SolarOverview {
        var out = SolarOverview()
        out.devices = root.objects("devices").compactMap(device)
        out.waiting = root.objects("waiting").compactMap(waiting)
        if let sums = root.object("totals") { out.totals = totals(sums) }
        return out
    }

    public static func totals(_ json: JSON) -> SolarTotals {
        var t = SolarTotals()
        t.inverters = json.int("inverters"); t.batteries = json.int("batteries"); t.stale = json.int("stale")
        t.pvW = json.double("pv_w") ?? 0; t.loadW = json.double("load_w") ?? 0; t.batteryW = json.double("battery_w"); t.socPercent = whole(json, "soc_percent")
        t.capacityAh = json.double("capacity_ah"); t.fullCapacityAh = json.double("full_capacity_ah"); t.energyKwh = json.double("energy_kwh")
        t.gridPresent = json.bool("grid_present")
        t.mode = json.has("mode") ? json.str("mode") : nil
        return t
    }

    private static func waiting(_ json: JSON) -> SolarWaiting? {
        let node = json.str("node_id"), device = json.str("device")
        if node.isEmpty || device.isEmpty { return nil }
        let name = json.str("name")
        return SolarWaiting(nodeId: node, device: device, name: name.isEmpty ? device : name, kind: json.str("kind"), model: json.str("model"))
    }

    public static func device(_ json: JSON) -> SolarDevice? {
        let node = json.str("node_id"), device = json.str("device")
        guard let reading = json.object("reading"), !node.isEmpty, !device.isEmpty else { return nil }
        let registered = json.object("registered")
        let registeredName = registered?.str("name") ?? ""
        let name = registeredName.isEmpty ? device : registeredName
        let model = registered?.str("model") ?? ""
        func make(_ inverter: SolarInverterReading?, _ battery: SolarBatteryReading?) -> SolarDevice {
            SolarDevice(nodeId: node, device: device, name: name, model: model, stale: json.bool("stale"), example: json.bool("example"), receivedAt: json.str("received_at"), inverter: inverter, battery: battery,
                        dayCells: battery != nil ? dayCells(json.object("day_cells")) : nil, events: battery != nil ? events(json.objects("events")) : [])
        }
        switch json.str("kind") {
        case "inverter": return make(inverter(reading), nil)
        case "battery": return make(nil, battery(reading))
        default: return nil
        }
    }

    private static func events(_ list: [JSON]) -> [LoggedEvent] {
        list.compactMap { item -> LoggedEvent? in
            guard let e = item.object("event") else { return nil }
            let module = item.has("n") ? item.int("n", -1) : -1
            if module < 1 || e.str("time").isEmpty { return nil }
            return LoggedEvent(module: module, seenAt: item.int("seen_at"), event: SolarEvent(index: e.int("index"), time: e.str("time"), voltageState: e.str("voltage_state"), powerEvents: e.str("power_events"),
                                                                                              batteryEvents: e.str("battery_events"), systemFault: e.str("system_fault")))
        }
    }

    private static func dayCells(_ d: JSON?) -> DayCells? {
        guard let d else { return nil }
        let modules: [ModuleDayCells] = d.objects("modules").compactMap { m -> ModuleDayCells? in
            guard let low = m.object("min"), let high = m.object("max"), let minV = low.double("v"), let maxV = high.double("v") else { return nil }
            return ModuleDayCells(number: m.int("n"), minV: minV, maxV: maxV, minCell: low.int("cell"), maxCell: high.int("cell"), minAt: low.int("at"), maxAt: high.int("at"), deltaV: m.double("delta_v") ?? (maxV - minV))
        }
        return DayCells(modules: modules, bankDeltaV: d.double("bank_delta_v") ?? 0)
    }

    private static func inverter(_ r: JSON) -> SolarInverterReading {
        let mode = r.str("mode", "unknown")
        let units = r.objects("units").map { SolarUnit(unit: $0.int("unit"), mode: $0.str("mode", "unknown"), serial: $0.str("serial"), faultCode: $0.str("fault_code"), outW: $0.double("out_w"), loadPercent: $0.double("load_percent"), batteryV: $0.double("battery_v")) }
        return SolarInverterReading(mode: mode, gridV: r.double("grid_v"), gridHz: r.double("grid_hz"), outV: r.double("out_v"), outHz: r.double("out_hz"), outVa: r.double("out_va"), outW: r.double("out_w"), loadPercent: r.double("load_percent"),
                                    batteryV: r.double("battery_v"), batteryA: r.double("battery_a"), batteryPercent: r.double("battery_percent"), pvV: r.double("pv_v"), pvA: r.double("pv_a"), pvW: r.double("pv_w"), heatsinkC: r.double("heatsink_c"),
                                    acCharging: r.bool("ac_charging"), pvCharging: r.bool("pv_charging"), loadOn: r.bool("load_on"), warnings: strings(r["warnings"]),
                                    pv2V: r.double("pv2_v"), pv2A: r.double("pv2_a"), pv2W: r.double("pv2_w"), units: units, totalOutW: r.double("total_out_w"))
    }

    private static func module(_ m: JSON) -> SolarModule {
        var counters: [String: Int] = [:]
        for (key, value) in (m.object("counters") ?? [:]) {
            if let number = (value as? Int) ?? (value as? Double).map({ Int($0) }), number >= 0 { counters[key] = number }
        }
        return SolarModule(number: m.int("n"), present: m.bool("present"), voltageV: m.double("voltage_v"), currentA: m.double("current_a"), temperatureC: m.double("temperature_c"), socPercent: whole(m, "soc_percent"), state: m.str("state"),
                           cellsV: numbers(m["cells_v"]), temperaturesC: numbers(m["temperatures_c"]), capacityAh: m.double("capacity_ah"), fullCapacityAh: m.double("full_capacity_ah"), cycles: whole(m, "cycles"),
                           healthPercent: whole(m, "health_percent"), counters: counters, model: m.str("model"), boardVersion: m.str("board_version"), mainSoftVersion: m.str("main_soft_version"), softVersion: m.str("soft_version"),
                           cellCount: whole(m, "cell_count"), maxChargeA: m.double("max_charge_a"), maxDischargeA: m.double("max_discharge_a"), consoleBaud: whole(m, "console_baud"),
                           sohCounts: ints(m["soh_counts"]), sohAbnormal: ints(m["soh_abnormal"]))
    }

    private static func battery(_ r: JSON) -> SolarBatteryReading {
        SolarBatteryReading(modules: r.int("modules"), model: r.str("model"), state: r.str("state"), voltageV: r.double("voltage_v"), currentA: r.double("current_a"), temperatureMinC: r.double("temperature_min_c"),
                            temperatureMaxC: r.double("temperature_max_c"), cellMinV: r.double("cell_min_v"), cellMaxV: r.double("cell_max_v"), socPercent: whole(r, "soc_percent"), alarm: r.bool("alarm"),
                            capacityAh: r.double("capacity_ah"), fullCapacityAh: r.double("full_capacity_ah"), energyKwh: r.double("energy_kwh"), cycles: whole(r, "cycles"),
                            stack: r.objects("stack").map(module).filter { $0.present }, healthPercent: whole(r, "health_percent"))
    }
}

/// The wording and the numbers of solar equipment. The source phrases are Spanish, as everywhere in the app (the translator gives them in the language chosen).
public enum SolarText {
    /// The counters of protections and errors: above zero they are worth a look (the same list the server tells a rise of).
    public static let severeCounters: Set<String> = [
        "lifealarm_times", "bat_ov_times", "bat_hv_times", "bat_uv_times", "input_ov_times", "pwr_ov_times", "pwr_hv_times", "pwr_uv_times", "coc_times", "coc2_times", "doc_times", "doc2_times",
        "sc_times", "cot_times", "dot_times", "bmicerr_times", "system_error_times",
    ]
    private static let acronyms: Set<String> = ["ov", "hv", "lv", "uv", "coc", "coc2", "doc", "doc2", "sc", "coca", "doca", "cot", "cut", "dot", "dut", "cht", "clt", "dht", "dlt", "ht", "lt", "slp", "rv", "bmicerr"]

    /// "bat_ov_times" -> "Bat OV Times": the name as the battery's console prints it.
    public static func counterLabel(_ key: String) -> String {
        key.split(separator: "_", omittingEmptySubsequences: false).map { word -> String in
            let w = String(word)
            return acronyms.contains(w) ? w.uppercased() : w.prefix(1).uppercased() + w.dropFirst()
        }.joined(separator: " ")
    }

    /// The protection counters of a module that are above zero, as "Bat OV Times 755 · COC Times 1"; empty when there are none.
    public static func raisedCounters(_ counters: [String: Int]) -> String {
        counters.filter { severeCounters.contains($0.key) && $0.value > 0 }.sorted { $0.key < $1.key }.map { counterLabel($0.key) + " " + String($0.value) }.joined(separator: " · ")
    }

    private static func letters(_ model: String) -> String { String(model.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }) }

    /// How new a model is, from the model a module reports: 1 the older ones, 2 the C, UP and US5000 models, 0 a model nobody knows.
    public static func generation(_ model: String) -> Int {
        let name = letters(model)
        if ["US2000", "US2000B", "US2000BPLUS", "US2000PLUS", "US2KBPL", "US3000"].contains(name) { return 1 }
        if ["US2000C", "US3000C", "US5000", "US5000B", "UP2500", "UP5000"].contains(name) { return 2 }
        return 0
    }

    /// What the makers' manuals say about mixing models in a group: the master (module 1) is the newest model, from the 9th module on only the C, UP and US5000 models are accepted, and a 24 V model
    /// (UP2500) does not share a group with 48 V ones. A warning (a code with the modules it is about), never a block; a model nobody knows is not judged.
    public static func composition(_ stack: [SolarModule]) -> [(code: String, modules: [Int])] {
        let known = stack.filter { $0.present && !$0.model.isEmpty }
        var out: [(code: String, modules: [Int])] = []
        let beyond = known.filter { $0.number >= 9 && generation($0.model) == 1 }.map(\.number)
        if !beyond.isEmpty { out.append(("beyond8", beyond)) }
        if let master = known.first(where: { $0.number == 1 }), generation(master.model) > 0 {
            let newer = known.filter { $0.number != 1 && generation($0.model) > generation(master.model) }.map(\.number)
            if !newer.isEmpty { out.append(("master", newer)) }
        }
        let small = known.filter { letters($0.model) == "UP2500" }
        let big = known.filter { letters($0.model) != "UP2500" && generation($0.model) > 0 }
        if !small.isEmpty && !big.isEmpty { out.append(("voltage", small.map(\.number))) }
        return out
    }

    /// The warning of `composition` in words.
    public static func compositionText(_ code: String, _ t: Translator) -> String {
        switch code {
        case "beyond8": return t.tr("A partir del 9.º módulo solo se admiten modelos C, UP y US5000; estos son modelos antiguos:")
        case "master": return t.tr("El maestro (módulo 1) debería ser el modelo más nuevo del grupo, pero hay un modelo más nuevo entre los esclavos:")
        default: return t.tr("Un modelo de 24 V (UP2500) no puede compartir grupo con modelos de 48 V:")
        }
    }

    /// The cells (counted from 1, as a person counts them) the battery's console calls abnormal in its state of health.
    public static func abnormalCells(_ module: SolarModule) -> [Int] { module.sohAbnormal.map { $0 + 1 } }

    /// "3.312 V (celda 5, 14:02)": a cell extreme of the day as a line; the time is the phone's own clock.
    public static func reach(volts: Double, cell: Int, atMs: Int, cellWord: String, timeZone: TimeZone = .current) -> String {
        let clock = DateFormatter()
        clock.locale = Locale(identifier: "en_US_POSIX")
        clock.timeZone = timeZone
        clock.dateFormat = "HH:mm"
        let time = clock.string(from: Date(timeIntervalSince1970: Double(atMs) / 1000))
        return String(format: "%.3f V", volts) + " (" + cellWord + " " + String(cell) + ", " + time + ")"
    }

    public static func mode(_ mode: String?, _ t: Translator) -> String {
        switch mode {
        case "power_on": return t.tr("Arrancando")
        case "standby": return t.tr("En espera")
        case "line": return t.tr("Con la red")
        case "battery": return t.tr("Con la batería")
        case "fault": return t.tr("Avería")
        case "power_saving": return t.tr("Ahorro de energía")
        case "shutdown": return t.tr("Apagado")
        default: return t.tr("Sin dato")
        }
    }

    public static func batteryState(_ state: String?, _ t: Translator) -> String {
        switch state {
        case "charging": return t.tr("Cargando")
        case "discharging": return t.tr("Descargando")
        case "idle": return t.tr("En reposo")
        default: return t.tr("Sin dato")
        }
    }

    /// The names of the models the server's catalogue lists (brands are the same in every language). An unknown model is its own identifier.
    private static let models: [String: String] = [
        "voltronic": "Voltronic", "mpp-solar": "MPP Solar", "axpert-vm-ii": "Voltronic Axpert VM II", "axpert-vm-iii": "Voltronic Axpert VM III",
        "axpert-mks": "Voltronic Axpert MKS / MKS II", "axpert-mks-iv": "Voltronic Axpert MKS IV / MKS V", "axpert-king": "Voltronic Axpert King",
        "pip-ms": "MPP Solar PIP MS / MSD / MSE / MSX", "pip-hs": "MPP Solar PIP HS / HSE / LV", "pip-gk": "MPP Solar PIP-GK / MK",
        "easun-isolar": "EASun iSolar SMG II / SMH II", "must-ph18": "Must PV18 / PH18", "revo-vm-iii": "Revo VM III / Revo II",
        "infinisolar-v": "MPP Solar InfiniSolar V", "lv5048-hybrid": "MPP Solar LV5048 Hybrid / LV6048", "sungoldpower": "SunGoldPower SPH / SPF",
        "pylontech-us2000": "Pylontech US2000", "pylontech-us2000c": "Pylontech US2000C", "pylontech-us2000b-plus": "Pylontech US2000B Plus",
        "pylontech-us2kbpl": "Pylontech US2KBPL", "pylontech-us3000": "Pylontech US3000", "pylontech-us3000c": "Pylontech US3000C",
        "pylontech-us5000": "Pylontech US5000", "pylontech-up2500": "Pylontech UP2500", "pylontech-up5000": "Pylontech UP5000",
        "pylontech-force-l1": "Pylontech Force L1", "pylontech-force-l2": "Pylontech Force L2", "pytes-e-box": "Pytes E-Box 48100R", "ant-bms": "ANT-BMS",
    ]

    public static func model(_ model: String) -> String {
        if model == "other" || model.isEmpty { return "" }
        if let known = models[model] { return known }
        if let range = model.range(of: #"^ant-bms-(\d{1,2})s-(\d{2,3})a$"#, options: .regularExpression) {
            let parts = model[range].split(separator: "-")
            if parts.count == 4, let cells = Int(parts[2].dropLast()), let amps = Int(parts[3].dropLast()) { return "ANT-BMS \(cells)S · \(amps) A" }
        }
        return model
    }

    /// A warning name of the inverter ("line_fail") as words.
    public static func warning(_ name: String) -> String { name.replacingOccurrences(of: "_", with: " ") }

    public static func watts(_ value: Double?) -> String {
        guard let value else { return "—" }
        return abs(value) >= 1000 ? String(format: "%.2f kW", value / 1000) : String(format: "%.0f W", value)
    }
    public static func volts(_ value: Double?, _ digits: Int = 1) -> String { value.map { String(format: "%.\(digits)f V", $0) } ?? "—" }
    public static func amps(_ value: Double?, _ digits: Int = 1) -> String { value.map { String(format: "%.\(digits)f A", $0) } ?? "—" }
    public static func percent(_ value: Double?) -> String { value.map { "\(Int($0.rounded())) %" } ?? "—" }
    public static func percent(_ value: Int?) -> String { value.map { "\($0) %" } ?? "—" }
    public static func hertz(_ value: Double?) -> String { value.map { String(format: "%.1f Hz", $0) } ?? "—" }
    public static func celsius(_ value: Double?) -> String { value.map { String(format: "%.0f °C", $0) } ?? "—" }
    public static func ah(_ value: Double?) -> String { value.map { String(format: "%.1f Ah", $0) } ?? "—" }
    public static func cell(_ value: Double) -> String { String(format: "%.3f", value) }

    /// What the batteries do as one short phrase: "Cargando · 340 W".
    public static func batteryFlow(_ watts: Double?, _ t: Translator) -> String {
        guard let watts else { return t.tr("Sin dato") }
        if watts > 20 { return t.trf("Cargando · %s", Self.watts(watts)) }
        if watts < -20 { return t.trf("Descargando · %s", Self.watts(-watts)) }
        return t.tr("En reposo")
    }

    /// The spread between the highest and the lowest cell, in millivolts: the number that tells an unbalanced pack.
    public static func cellSpreadMv(_ cells: [Double]) -> Int? {
        guard cells.count >= 2, let high = cells.max(), let low = cells.min() else { return nil }
        return Int(((high - low) * 1000).rounded())
    }

    /// The color class of a state of charge for the screens: "alert" under 20 %, "warn" under 40 %, "ok" above, "none" without a reading.
    public static func socLevel(_ percent: Int?) -> String {
        guard let percent else { return "none" }
        return percent < 20 ? "alert" : percent < 40 ? "warn" : "ok"
    }
}
