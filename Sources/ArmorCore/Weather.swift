// ARMOR-IOS-CONTROL - the weather of the place the person chooses, from Open-Meteo (no key; CC BY 4.0): now, the rain of the next hour, warnings the forecast implies, 48 hours, ten days, the air and
// pollen, and the sun and the moon. Nothing is asked until a place is chosen, and only its coordinates leave the phone; no ARMOR-SERVER call is involved. The same reading as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct Place: Equatable, Sendable, Codable {
    public let name: String
    public let region: String?, country: String?
    public let latitude: Double, longitude: Double
}

public struct WxCurrent: Equatable, Sendable {
    public let time: String
    public let temperature: Double?, apparent: Double?, humidity: Double?
    public let isDay: Bool
    public let precipitation: Double?
    public let code: Int?
    public let cloud: Double?, pressure: Double?, windSpeed: Double?, windDir: Double?, windGust: Double?
}

public struct WxHourly: Equatable, Sendable {
    public let time: [String]
    public let temperature: [Double?], precipProb: [Double?], precip: [Double?]
    public let code: [Int?]
    public let windSpeed: [Double?], cloud: [Double?]
    public let isDay: [Int?]
}

public struct WxDaily: Equatable, Sendable {
    public let time: [String]
    public let code: [Int?]
    public let tMax: [Double?], tMin: [Double?]
    public let sunrise: [String], sunset: [String]
    public let uvMax: [Double?], precipSum: [Double?], precipProbMax: [Double?], windMax: [Double?]
}

public struct WxMinutely: Equatable, Sendable {
    public let time: [String]
    public let precip: [Double?]
}

public struct Forecast: Equatable, Sendable {
    public let latitude: Double, longitude: Double
    public let timezone: String
    public let utcOffsetSeconds: Int
    public let current: WxCurrent?
    public let minutely: WxMinutely
    public let hourly: WxHourly
    public let daily: WxDaily
}

public struct AirQuality: Equatable, Sendable {
    public let europeanAqi: Int?
    public let pm10: Double?, pm25: Double?, o3: Double?, no2: Double?
    public let pollen: [String: Double]
}

public struct WeatherWarning: Equatable, Sendable {
    public let level: String
    public let key: String
    public let value: Double
    public let at: String
}

public enum WeatherParser {
    private static func doubles(_ any: Any?) -> [Double?] { ((any as? [Any]) ?? []).map { ($0 as? Double) ?? ($0 as? Int).map { Double($0) } } }
    private static func codes(_ any: Any?) -> [Int?] { doubles(any).map { $0.map { Int($0.rounded()) } } }
    private static func strings(_ any: Any?) -> [String] { ((any as? [Any]) ?? []).map { ($0 as? String) ?? "" } }

    public static func place(_ json: JSON) -> Place? {
        guard let lat = json.double("latitude"), let lon = json.double("longitude") else { return nil }
        let region = json.str("admin1"), country = json.str("country")
        return Place(name: json.str("name"), region: region.isEmpty ? nil : region, country: country.isEmpty ? nil : country, latitude: lat, longitude: lon)
    }

    public static func places(_ root: JSON) -> [Place] { root.objects("results").compactMap(place) }

    public static func forecast(_ root: JSON) -> Forecast? {
        guard let lat = root.double("latitude"), let lon = root.double("longitude") else { return nil }
        let c = root.object("current"), h = root.object("hourly"), d = root.object("daily"), m = root.object("minutely_15")
        var current: WxCurrent?
        if let c, c.has("time") {
            current = WxCurrent(time: c.str("time"), temperature: c.double("temperature_2m"), apparent: c.double("apparent_temperature"), humidity: c.double("relative_humidity_2m"), isDay: c.int("is_day") != 0,
                                precipitation: c.double("precipitation"), code: c.has("weather_code") ? c.int("weather_code") : nil, cloud: c.double("cloud_cover"), pressure: c.double("pressure_msl"),
                                windSpeed: c.double("wind_speed_10m"), windDir: c.double("wind_direction_10m"), windGust: c.double("wind_gusts_10m"))
        }
        let minutely = WxMinutely(time: strings(m?["time"]), precip: doubles(m?["precipitation"]))
        let hourly = WxHourly(time: strings(h?["time"]), temperature: doubles(h?["temperature_2m"]), precipProb: doubles(h?["precipitation_probability"]), precip: doubles(h?["precipitation"]),
                              code: codes(h?["weather_code"]), windSpeed: doubles(h?["wind_speed_10m"]), cloud: doubles(h?["cloud_cover"]), isDay: codes(h?["is_day"]))
        let daily = WxDaily(time: strings(d?["time"]), code: codes(d?["weather_code"]), tMax: doubles(d?["temperature_2m_max"]), tMin: doubles(d?["temperature_2m_min"]), sunrise: strings(d?["sunrise"]),
                            sunset: strings(d?["sunset"]), uvMax: doubles(d?["uv_index_max"]), precipSum: doubles(d?["precipitation_sum"]), precipProbMax: doubles(d?["precipitation_probability_max"]),
                            windMax: doubles(d?["wind_speed_10m_max"]))
        return Forecast(latitude: lat, longitude: lon, timezone: root.str("timezone", "UTC"), utcOffsetSeconds: root.int("utc_offset_seconds"), current: current, minutely: minutely, hourly: hourly, daily: daily)
    }

    static let pollenKinds = ["alder", "birch", "grass", "mugwort", "olive", "ragweed"]

    public static func airQuality(_ root: JSON) -> AirQuality? {
        guard let c = root.object("current"), c.has("time") else { return nil }
        var pollen: [String: Double] = [:]
        for kind in pollenKinds { if let value = c.double(kind + "_pollen") { pollen[kind] = value } }
        return AirQuality(europeanAqi: c.has("european_aqi") ? c.int("european_aqi") : nil, pm10: c.double("pm10"), pm25: c.double("pm2_5"), o3: c.double("ozone"), no2: c.double("nitrogen_dioxide"), pollen: pollen)
    }
}

/// The wording, icons and simple classifications of the Weather screen (the source phrases are Spanish; the translator gives them in the language chosen).
public enum WeatherText {
    private static func entry(_ code: Int, _ t: Translator) -> (String, String)? {
        switch code {
        case 0: return (t.tr("Despejado"), "☀️")
        case 1: return (t.tr("Poco nuboso"), "🌤️")
        case 2: return (t.tr("Parcialmente nublado"), "⛅")
        case 3: return (t.tr("Cubierto"), "☁️")
        case 45: return (t.tr("Niebla"), "🌫️")
        case 48: return (t.tr("Niebla helada"), "🌫️")
        case 51: return (t.tr("Llovizna ligera"), "🌦️")
        case 53: return (t.tr("Llovizna"), "🌦️")
        case 55: return (t.tr("Llovizna intensa"), "🌧️")
        case 56: return (t.tr("Llovizna helada"), "🌧️")
        case 57: return (t.tr("Llovizna helada intensa"), "🌧️")
        case 61: return (t.tr("Lluvia ligera"), "🌦️")
        case 63: return (t.tr("Lluvia"), "🌧️")
        case 65: return (t.tr("Lluvia intensa"), "🌧️")
        case 66: return (t.tr("Lluvia helada"), "🌧️")
        case 67: return (t.tr("Lluvia helada intensa"), "🌧️")
        case 71: return (t.tr("Nevada ligera"), "🌨️")
        case 73: return (t.tr("Nevada"), "🌨️")
        case 75: return (t.tr("Nevada intensa"), "❄️")
        case 77: return (t.tr("Granos de nieve"), "🌨️")
        case 80: return (t.tr("Chubascos ligeros"), "🌦️")
        case 81: return (t.tr("Chubascos"), "🌧️")
        case 82: return (t.tr("Chubascos violentos"), "⛈️")
        case 85: return (t.tr("Chubascos de nieve ligeros"), "🌨️")
        case 86: return (t.tr("Chubascos de nieve intensos"), "❄️")
        case 95: return (t.tr("Tormenta"), "⛈️")
        case 96: return (t.tr("Tormenta con granizo"), "⛈️")
        case 99: return (t.tr("Tormenta con granizo fuerte"), "⛈️")
        default: return nil
        }
    }

    public static func description(_ code: Int?, _ t: Translator) -> String { code.flatMap { entry($0, t)?.0 } ?? t.tr("Desconocido") }
    public static func icon(_ code: Int?) -> String { code.flatMap { entry($0, plainSpanish)?.1 } ?? "❔" }
    private static let plainSpanish = Translator(language: "es", loader: { _ in [:] })

    public static func compass(_ degrees: Double?, _ t: Translator) -> String? {
        guard let degrees else { return nil }
        let words = [t.tr("N"), t.tr("NE"), t.tr("E"), t.tr("SE"), t.tr("S"), t.tr("SO"), t.tr("O"), t.tr("NO")]
        let wrapped = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return words[Int((wrapped / 45).rounded()) % 8]
    }

    public static func wind(_ kmh: Double?, _ t: Translator) -> String {
        guard let kmh else { return "—" }
        if kmh < 2 { return t.tr("Calma") }
        if kmh < 20 { return t.tr("Flojo") }
        if kmh < 39 { return t.tr("Moderado") }
        if kmh < 50 { return t.tr("Fresco") }
        if kmh < 62 { return t.tr("Fuerte") }
        if kmh < 88 { return t.tr("Muy fuerte") }
        if kmh < 118 { return t.tr("Temporal") }
        return t.tr("Huracanado")
    }

    public static func uv(_ index: Double?, _ t: Translator) -> String {
        guard let index else { return "—" }
        if index < 3 { return t.tr("Bajo") }
        if index < 6 { return t.tr("Moderado") }
        if index < 8 { return t.tr("Alto") }
        if index < 11 { return t.tr("Muy alto") }
        return t.tr("Extremo")
    }

    public static func aqi(_ index: Int?, _ t: Translator) -> String {
        guard let index else { return "—" }
        if index <= 20 { return t.tr("Buena") }
        if index <= 40 { return t.tr("Razonable") }
        if index <= 60 { return t.tr("Moderada") }
        if index <= 80 { return t.tr("Mala") }
        if index <= 100 { return t.tr("Muy mala") }
        return t.tr("Extrema")
    }

    public static func pollenName(_ key: String, _ t: Translator) -> String {
        switch key {
        case "alder": return t.tr("Aliso")
        case "birch": return t.tr("Abedul")
        case "grass": return t.tr("Gramíneas")
        case "mugwort": return t.tr("Artemisa")
        case "olive": return t.tr("Olivo")
        case "ragweed": return t.tr("Ambrosía")
        default: return key
        }
    }

    public static func pollen(_ grains: Double?, _ t: Translator) -> String {
        guard let grains else { return "—" }
        if grains < 1 { return t.tr("Nulo") }
        if grains < 10 { return t.tr("Bajo") }
        if grains < 50 { return t.tr("Moderado") }
        if grains < 200 { return t.tr("Alto") }
        return t.tr("Muy alto")
    }

    public static func pressureTrend(now: Double?, before: Double?, _ t: Translator) -> String? {
        guard let now, let before else { return nil }
        let change = now - before
        if change >= 1 { return t.tr("Subiendo") }
        if change <= -1 { return t.tr("Bajando") }
        return t.tr("Estable")
    }

    public static func dewPoint(celsius: Double?, humidity: Double?) -> Double? {
        guard let celsius, let humidity, humidity > 0 else { return nil }
        let a = 17.62, b = 243.12
        let gamma = log(humidity / 100) + (a * celsius) / (b + celsius)
        return (((b * gamma) / (a - gamma)) * 10).rounded() / 10
    }

    public static func moonPhase(epochMs: Int, _ t: Translator) -> (icon: String, name: String) {
        let days = Double(epochMs) / 86_400_000 + 2_440_587.5 - 2_451_550.1
        let phase = ((days / 29.530588853).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let index = Int((phase * 8).rounded()) % 8
        let icons = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]
        let names = [t.tr("Luna nueva"), t.tr("Creciente"), t.tr("Cuarto creciente"), t.tr("Gibosa creciente"), t.tr("Luna llena"), t.tr("Gibosa menguante"), t.tr("Cuarto menguante"), t.tr("Menguante")]
        return (icons[index], names[index])
    }

    /// The hour of Open-Meteo's local, offset-less ISO strings ("2026-10-02T14:00" -> "14:00").
    public static func hourOf(_ iso: String) -> String { iso.count >= 16 ? String(iso.dropFirst(11).prefix(5)) : iso }

    private static func dateOf(_ iso: String) -> Date? {
        let parts = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    private static func format(_ date: Date, _ pattern: String, _ language: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == "pt" ? "pt-PT" : language)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    public static func dayOf(_ iso: String, _ language: String) -> String { dateOf(iso).map { format($0, "d MMM", language) } ?? iso }
    public static func weekday(_ iso: String, _ language: String) -> String { dateOf(iso).map { format($0, "EEE", language) } ?? "" }

    /// The place's current local time, as Open-Meteo's own ISO form, to find "now" in its hourly/daily series.
    public static func localIso(nowMs: Int, utcOffsetSeconds: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: Double(nowMs + utcOffsetSeconds * 1000) / 1000))
    }

    public static func hourIndex(_ times: [String], _ iso: String) -> Int {
        let hour = String(iso.prefix(13))
        if let at = times.firstIndex(where: { String($0.prefix(13)) >= hour }) { return at }
        return max(times.count - 1, 0)
    }

    /// The rain of the next hour from the 15-minute series: the millimetres expected and whether it is raining right now.
    public static func nextHourRain(_ minutely: WxMinutely, _ iso: String) -> (mm: Double, raining: Bool) {
        guard iso.count >= 16 else { return (0, false) }
        let minute = Int(iso.dropFirst(14).prefix(2)) ?? 0
        let quarter = String(iso.prefix(14)) + String(format: "%02d", minute / 15 * 15)
        guard let from = minutely.time.firstIndex(where: { $0 >= quarter }) else { return (0, false) }
        let steps = Array(minutely.precip.dropFirst(from).prefix(4))
        let mm = (steps.reduce(0.0) { $0 + ($1 ?? 0) } * 10).rounded() / 10
        return (mm, (steps.first.flatMap { $0 } ?? 0) >= 0.1)
    }

    /// A few plain-threshold warnings from the next 48 hours (not an official warning service): heavy rain, strong wind, high UV, frost.
    public static func warnings(_ forecast: Forecast, fromIndex: Int, hours: Int = 48, _ t: Translator) -> [WeatherWarning] {
        var out: [WeatherWarning] = []
        let end = min(fromIndex + hours, forecast.hourly.time.count)
        if fromIndex >= end { return out }
        func slice(_ values: [Double?]) -> [Double?] { fromIndex < values.count ? Array(values[fromIndex..<min(end, values.count)]) : [] }
        let rain = slice(forecast.hourly.precip), wind = slice(forecast.hourly.windSpeed), temp = slice(forecast.hourly.temperature)
        if let top = rain.enumerated().max(by: { ($0.element ?? 0) < ($1.element ?? 0) }), let v = top.element, v >= 4 {
            out.append(WeatherWarning(level: "warning", key: t.tr("Lluvia intensa"), value: v, at: forecast.hourly.time[fromIndex + top.offset]))
        }
        if let top = wind.enumerated().max(by: { ($0.element ?? 0) < ($1.element ?? 0) }), let v = top.element, v >= 50 {
            out.append(WeatherWarning(level: v >= 70 ? "warning" : "watch", key: t.tr("Viento fuerte"), value: v, at: forecast.hourly.time[fromIndex + top.offset]))
        }
        if let low = temp.enumerated().min(by: { ($0.element ?? 100) < ($1.element ?? 100) }), let v = low.element, v <= 0 {
            out.append(WeatherWarning(level: "watch", key: t.tr("Riesgo de helada"), value: v, at: forecast.hourly.time[fromIndex + low.offset]))
        }
        if let uv = forecast.daily.uvMax.first, let v = uv, v >= 8 {
            out.append(WeatherWarning(level: v >= 11 ? "warning" : "watch", key: t.tr("Índice UV muy alto"), value: v, at: forecast.daily.time.first ?? ""))
        }
        return out
    }
}
