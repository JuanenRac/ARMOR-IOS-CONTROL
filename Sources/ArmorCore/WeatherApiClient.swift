// ARMOR-IOS-CONTROL - talks to Open-Meteo directly (no key, CC BY 4.0), never to ARMOR-SERVER: the forecast, the air quality and a place search by name. Nothing is asked until the person chooses a place
// in the Weather screen, and only that place's coordinates (or the text they typed, for a search) leave the phone. The addresses and the fields asked for are in Resources/weather.json.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The services and the fields the weather client asks for, kept in a file and not in the code.
public struct WeatherSettings: Equatable, Sendable {
    public let forecastApi: String, airQualityApi: String, geocodingApi: String
    public let hourly: String, daily: String, current: String, air: String
    public let forecastDays: Int
    public let minutelySteps: Int

    public static let defaults = WeatherSettings(
        forecastApi: "https://api.open-meteo.com", airQualityApi: "https://air-quality-api.open-meteo.com", geocodingApi: "https://geocoding-api.open-meteo.com",
        hourly: "temperature_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m,cloud_cover,is_day",
        daily: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max",
        current: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m",
        air: "european_aqi,pm10,pm2_5,ozone,nitrogen_dioxide,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen", forecastDays: 10, minutelySteps: 8)

    /// Reads the file; a missing field takes the default, and an address that is not https is refused (the default is used instead).
    public static func parse(_ json: JSON) -> WeatherSettings {
        func text(_ key: String, _ fallback: String) -> String { let value = json.str(key); return value.isEmpty ? fallback : value }
        func address(_ key: String, _ fallback: String) -> String { let value = text(key, fallback); return value.hasPrefix("https://") ? value : fallback }
        let d = defaults
        return WeatherSettings(forecastApi: address("forecast_api", d.forecastApi), airQualityApi: address("air_quality_api", d.airQualityApi), geocodingApi: address("geocoding_api", d.geocodingApi),
                               hourly: text("hourly", d.hourly), daily: text("daily", d.daily), current: text("current", d.current), air: text("air", d.air),
                               forecastDays: min(16, max(1, json.has("forecast_days") ? json.int("forecast_days") : d.forecastDays)),
                               minutelySteps: min(48, max(1, json.has("minutely_steps") ? json.int("minutely_steps") : d.minutelySteps)))
    }

    public static func bundled() -> WeatherSettings {
        guard let url = Bundle.module.url(forResource: "weather", withExtension: "json"), let data = try? Data(contentsOf: url), let json = try? Json.object(data) else { return defaults }
        return parse(json)
    }
}

public final class WeatherApiClient: @unchecked Sendable {
    private let session: URLSession
    private let settings: WeatherSettings

    public init(session: URLSession, settings: WeatherSettings = .bundled()) {
        self.session = session
        self.settings = settings
    }

    /// A session with timeouts like the other client's and nothing kept (no cookies, no cache).
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    private func getJson(_ base: String, _ path: String, _ query: [(String, String)]) async throws -> JSON {
        guard var parts = URLComponents(string: base + path) else { throw ArmorApiError(message: "The address is not valid", status: nil) }
        parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = parts.url else { throw ArmorApiError(message: "The address is not valid", status: nil) }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw ArmorApiError(message: error.localizedDescription, status: nil) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 { throw ArmorApiError(message: "Weather service failed (HTTP \(status))", status: status) }
        return try Json.object(data)
    }

    public func forecast(_ place: Place) async throws -> Forecast {
        let root = try await getJson(settings.forecastApi, "/v1/forecast", [
            ("latitude", String(place.latitude)), ("longitude", String(place.longitude)), ("timezone", "auto"), ("forecast_days", String(settings.forecastDays)),
            ("forecast_minutely_15", String(settings.minutelySteps)), ("wind_speed_unit", "kmh"), ("current", settings.current), ("minutely_15", "precipitation"),
            ("hourly", settings.hourly), ("daily", settings.daily)])
        guard let forecast = WeatherParser.forecast(root) else { throw ArmorApiError(message: "not a forecast", status: nil) }
        return forecast
    }

    /// The air quality, or nil when the service does not answer: the screen simply leaves that panel out.
    public func airQuality(_ place: Place) async -> AirQuality? {
        guard let root = try? await getJson(settings.airQualityApi, "/v1/air-quality", [("latitude", String(place.latitude)), ("longitude", String(place.longitude)), ("timezone", "auto"), ("current", settings.air)]) else { return nil }
        return WeatherParser.airQuality(root)
    }

    public func search(_ query: String, language: String) async throws -> [Place] {
        let text = query.trimmingCharacters(in: .whitespaces)
        if text.count < 2 { return [] }
        let root = try await getJson(settings.geocodingApi, "/v1/search", [("name", String(text.prefix(80))), ("count", "8"), ("language", language), ("format", "json")])
        return WeatherParser.places(root)
    }
}
