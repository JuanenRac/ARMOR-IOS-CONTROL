// ARMOR-IOS-CONTROL - what a person reads for each alarm code, from the table every client shares (Resources/alarm_codes.json is a copy of the one in ARMOR-COMMON, kept equal by a test and by tools/ios_lint.py).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum AlarmCodes {
    /// code -> language -> sentence, read once from the package; empty when the file cannot be read (the phrases of `AlarmText` are used then).
    public static let shared: [String: [String: String]] = {
        guard let url = Bundle.module.url(forResource: "alarm_codes", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] }
        return parse(data)
    }()

    public static func parse(_ data: Data) -> [String: [String: String]] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let codes = root["codes"] as? [String: Any] else { return [:] }
        var table: [String: [String: String]] = [:]
        for (code, value) in codes {
            if let texts = value as? [String: String] { table[code] = texts }
        }
        return table
    }
}
