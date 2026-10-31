// ARMOR-IOS-CONTROL - the facts an alarm carries (which device, which port, which panel...) with the label each one has in the table every client shares (Resources/alarm_facts.json is a copy of the one in ARMOR-COMMON, kept equal by a test and by tools/ios_lint.py).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The value of one fact as the server sent it. Anything that is not a text, a number or a yes/no is kept as the text it came as, so no fact is lost.
public enum AlarmFactValue: Equatable, Sendable {
    case text(String)
    case whole(Int)
    case decimal(Double)
    case flag(Bool)
    case raw(String)
}

public struct AlarmFact: Equatable, Sendable {
    public let key: String
    public let value: AlarmFactValue
    public init(key: String, value: AlarmFactValue) { self.key = key; self.value = value }
}

/// One fact ready to be read: [label] is the words of the person's language, or the key as it came when the table does not know it ([known] is false then).
public struct AlarmFactRow: Equatable, Sendable {
    public let key: String
    public let label: String
    public let value: String
    public let known: Bool
}

public enum AlarmFacts {
    /// fact -> language -> label, read once from the package; empty when the file cannot be read (every fact is then shown with its key).
    public static let shared: [String: [String: String]] = {
        guard let url = Bundle.module.url(forResource: "alarm_facts", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] }
        return parse(data)
    }()

    public static func parse(_ data: Data) -> [String: [String: String]] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let facts = root["facts"] as? [String: Any] else { return [:] }
        var table: [String: [String: String]] = [:]
        for (key, value) in facts {
            if let labels = value as? [String: String] { table[key] = labels }
        }
        return table
    }

    /// The facts of an alarm from the JSON of the server (the `detail` object): text, numbers and yes/no as they are, anything else as the text it came as.
    public static func facts(_ detail: JSON?) -> [AlarmFact] {
        guard let detail else { return [] }
        return detail.map { AlarmFact(key: $0.key, value: value(of: $0.value)) }.sorted { $0.key < $1.key }
    }

    static func value(of any: Any) -> AlarmFactValue {
        if let text = any as? String { return .text(text) }
        if any is NSNull { return .text("") }
        if let number = any as? NSNumber {
            if isBoolean(number) { return .flag(number.boolValue) }
            let double = number.doubleValue
            if double == double.rounded(), abs(double) < 1e15 { return .whole(Int(double)) }
            return .decimal(double)
        }
        if JSONSerialization.isValidJSONObject(any), let data = try? JSONSerialization.data(withJSONObject: any, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) { return .raw(text) }
        return .raw(String(describing: any))
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        #if canImport(Darwin)
        return CFGetTypeID(number) == CFBooleanGetTypeID()
        #else
        return String(describing: type(of: number)).contains("Bool")
        #endif
    }

    /// The order the facts are told in; anything else the server sends follows, by name.
    static let order: [String] = [
        "device", "ip", "mac", "vendor", "hostname", "kind", "os", "online", "open_ports", "port", "risky", "opened_at", "first_seen", "mac_now", "mac_before", "what_happened",
        "arming_mode", "panel_profile", "panels", "panel_answers", "by",
        "latency_ms", "loss_percent", "failing", "router_answers", "since", "router", "interface", "node",
    ]
    private static let dates: Set<String> = ["since", "first_seen", "opened_at"]

    /// The label of [key] in [language]; English when that language lacks it; nil when the table does not know the fact.
    public static func label(_ key: String, _ language: String, table: [String: [String: String]] = shared) -> String? {
        guard let labels = table[key] else { return nil }
        return labels[language] ?? labels["en"]
    }

    /// The value as a person reads it: yes/no in words, units for the two measures that have one, a date in the clock of the phone; anything unexpected as it came.
    public static func text(_ key: String, _ value: AlarmFactValue, _ translator: Translator, timeZone: TimeZone = .current) -> String {
        switch value {
        case .flag(let on): return on ? translator.tr("sí") : translator.tr("no")
        case .whole(let n):
            if key == "latency_ms" { return "\(n) ms" }
            if key == "loss_percent" { return "\(n) %" }
            return String(n)
        case .decimal(let d):
            if key == "latency_ms" { return "\(d) ms" }
            if key == "loss_percent" { return "\(d) %" }
            return String(d)
        case .text(let s):
            return dates.contains(key) ? (clock(s, timeZone) ?? s) : s
        case .raw(let s): return s
        }
    }

    /// "2026-09-26T01:11:00Z" as "26/09 03:11" in the time zone given; nil when it is not a date.
    static func clock(_ iso: String, _ timeZone: TimeZone) -> String? {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = plain.date(from: iso) ?? fractional.date(from: iso) else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.timeZone = timeZone
        out.dateFormat = "dd/MM HH:mm"
        return out.string(from: date)
    }

    /// Every fact, ordered, each with its label. Nothing is dropped: a fact the table does not know keeps its key as label.
    public static func rows(_ detail: [AlarmFact], _ translator: Translator, table: [String: [String: String]] = shared, timeZone: TimeZone = .current) -> [AlarmFactRow] {
        func rank(_ key: String) -> Int { order.firstIndex(of: key) ?? order.count }
        return detail
            .sorted { (rank($0.key), $0.key) < (rank($1.key), $1.key) }
            .map { fact in
                let label = Self.label(fact.key, translator.language, table: table)
                return AlarmFactRow(key: fact.key, label: label ?? fact.key, value: text(fact.key, fact.value, translator, timeZone: timeZone), known: label != nil)
            }
    }
}
