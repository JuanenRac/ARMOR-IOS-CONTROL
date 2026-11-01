// ARMOR-IOS-CONTROL - how often the screens that watch live equipment ask the server again. The values live in Resources/polling.json, not in the code; a missing or odd file falls back to these defaults.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct ScreenPolling: Equatable, Sendable {
    public let solarSeconds: Double
    public let electricalSeconds: Double
    public let batterySeconds: Double

    public static let defaults = ScreenPolling(solarSeconds: 5, electricalSeconds: 5, batterySeconds: 2)

    /// Reads the values and keeps each between the minimum and the maximum of the file (never faster than once a second by default, so a typo cannot flood the server).
    public static func parse(_ json: JSON) -> ScreenPolling {
        let low = max(0.5, json.double("minimum_seconds") ?? 1)
        let high = max(low, json.double("maximum_seconds") ?? 300)
        func pick(_ key: String, _ fallback: Double) -> Double { min(high, max(low, json.double(key) ?? fallback)) }
        return ScreenPolling(solarSeconds: pick("solar_seconds", defaults.solarSeconds), electricalSeconds: pick("electrical_seconds", defaults.electricalSeconds), batterySeconds: pick("battery_seconds", defaults.batterySeconds))
    }

    /// The file shipped inside the package.
    public static func bundled() -> ScreenPolling {
        guard let url = Bundle.module.url(forResource: "polling", withExtension: "json"), let data = try? Data(contentsOf: url), let json = try? Json.object(data) else { return defaults }
        return parse(json)
    }
}
