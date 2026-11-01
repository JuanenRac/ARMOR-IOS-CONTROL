import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ArmorCore

final class WeatherTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    private let sample = """
    {"latitude":40.4,"longitude":-3.7,"timezone":"Europe/Madrid","utc_offset_seconds":7200,
     "current":{"time":"2026-03-05T14:00","temperature_2m":18.4,"apparent_temperature":17.1,"relative_humidity_2m":55,"is_day":1,"precipitation":0,"weather_code":2,"cloud_cover":40,"pressure_msl":1015.2,
                "wind_speed_10m":12,"wind_direction_10m":225,"wind_gusts_10m":30},
     "minutely_15":{"time":["2026-03-05T14:00","2026-03-05T14:15","2026-03-05T14:30","2026-03-05T14:45","2026-03-05T15:00"],"precipitation":[0.0,0.2,0.4,null,1.0]},
     "hourly":{"time":["2026-03-05T13:00","2026-03-05T14:00","2026-03-05T15:00","2026-03-05T16:00"],"temperature_2m":[17,18,-1.5,16],"precipitation_probability":[0,10,null,60],
               "precipitation":[0,0,5.2,0],"weather_code":[1,2,61,3],"wind_speed_10m":[10,12,55,20],"cloud_cover":[0,0,0,0],"is_day":[1,1,1,0]},
     "daily":{"time":["2026-03-05","2026-03-06"],"weather_code":[2,61],"temperature_2m_max":[19,15],"temperature_2m_min":[8,6],"sunrise":["2026-03-05T07:20","2026-03-06T07:19"],
              "sunset":["2026-03-05T18:55","2026-03-06T18:56"],"uv_index_max":[8.5,4],"precipitation_sum":[0,5],"precipitation_probability_max":[10,80],"wind_speed_10m_max":[30,40]}}
    """

    private func forecast() throws -> Forecast { try XCTUnwrap(WeatherParser.forecast(json(sample))) }

    func testTheForecastIsReadWithItsSeriesAndItsGaps() throws {
        let f = try forecast()
        XCTAssertEqual(f.timezone, "Europe/Madrid")
        XCTAssertEqual(f.utcOffsetSeconds, 7200)
        let current = try XCTUnwrap(f.current)
        XCTAssertEqual(current.temperature, 18.4)
        XCTAssertEqual(current.code, 2)
        XCTAssertTrue(current.isDay)
        XCTAssertEqual(f.hourly.time.count, 4)
        XCTAssertEqual(f.hourly.code, [1, 2, 61, 3] as [Int?])
        XCTAssertNil(f.hourly.precipProb[2])
        XCTAssertNil(f.minutely.precip[3])
        XCTAssertEqual(f.daily.sunrise.count, 2)
        XCTAssertNil(WeatherParser.forecast([:]))
    }

    func testAPlaceSearchKeepsTheResultsThatHaveCoordinates() {
        let places = WeatherParser.places(json(#"{"results":[{"name":"Madrid","admin1":"Madrid","country":"Spain","latitude":40.4,"longitude":-3.7},{"name":"x"}]}"#))
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].region, "Madrid")
        XCTAssertTrue(WeatherParser.places([:]).isEmpty)
    }

    func testTheAirAndThePollenAreRead() {
        let air = WeatherParser.airQuality(json(#"{"current":{"time":"t","european_aqi":35,"pm10":12.4,"pm2_5":6.1,"ozone":80,"nitrogen_dioxide":9,"alder_pollen":0,"grass_pollen":15.5}}"#))
        XCTAssertEqual(air?.europeanAqi, 35)
        XCTAssertEqual(air?.pm25, 6.1)
        XCTAssertEqual(air?.pollen["grass"], 15.5)
        XCTAssertEqual(air?.pollen["alder"], 0)
        XCTAssertNil(air?.pollen["birch"])
        XCTAssertNil(WeatherParser.airQuality(json(#"{"current":{"pm10":1}}"#)))
    }

    func testTheLocalTimeOfThePlaceAndTheHourToStartFrom() throws {
        XCTAssertEqual(WeatherText.localIso(nowMs: 1_772_712_000_000, utcOffsetSeconds: 7200), "2026-03-05T14:00")
        let f = try forecast()
        XCTAssertEqual(WeatherText.hourIndex(f.hourly.time, "2026-03-05T14:20"), 1)
        XCTAssertEqual(WeatherText.hourIndex(f.hourly.time, "2026-03-06T00:00"), 3)
        XCTAssertEqual(WeatherText.hourOf("2026-03-05T14:00"), "14:00")
        XCTAssertEqual(WeatherText.dayOf("2026-03-05", "en"), "5 Mar")
        XCTAssertEqual(WeatherText.weekday("2026-03-05", "en"), "Thu")
        XCTAssertEqual(WeatherText.dayOf("nonsense", "en"), "nonsense")
    }

    func testTheRainOfTheNextHourComesFromTheFifteenMinuteSeries() throws {
        let f = try forecast()
        let later = WeatherText.nextHourRain(f.minutely, "2026-03-05T14:20")
        XCTAssertEqual(later.mm, 1.6, accuracy: 0.0001)
        XCTAssertTrue(later.raining)
        let start = WeatherText.nextHourRain(f.minutely, "2026-03-05T14:00")
        XCTAssertEqual(start.mm, 0.6, accuracy: 0.0001)
        XCTAssertFalse(start.raining)
        let none = WeatherText.nextHourRain(f.minutely, "2026-03-06T00:00")
        XCTAssertEqual(none.mm, 0)
        XCTAssertFalse(none.raining)
    }

    func testThePlainThresholdWarningsOfTheNextHours() throws {
        let f = try forecast()
        let warnings = WeatherText.warnings(f, fromIndex: 1, plain("es"))
        XCTAssertEqual(warnings.map(\.key), ["Lluvia intensa", "Viento fuerte", "Riesgo de helada", "Índice UV muy alto"])
        XCTAssertEqual(warnings.map(\.level), ["warning", "watch", "watch", "watch"])
        XCTAssertEqual(warnings[0].at, "2026-03-05T15:00")
        XCTAssertEqual(warnings[3].at, "2026-03-05")
        XCTAssertTrue(WeatherText.warnings(f, fromIndex: 10, plain("es")).isEmpty)
    }

    func testTheWordsForTheCodesTheWindTheAirAndThePollen() {
        let t = plain("es")
        XCTAssertEqual(WeatherText.description(61, t), "Lluvia ligera")
        XCTAssertEqual(WeatherText.description(nil, t), "Desconocido")
        XCTAssertEqual(WeatherText.description(12345, t), "Desconocido")
        XCTAssertEqual(WeatherText.icon(0), "☀️")
        XCTAssertEqual(WeatherText.icon(nil), "❔")
        XCTAssertEqual(WeatherText.wind(1, t), "Calma")
        XCTAssertEqual(WeatherText.wind(25, t), "Moderado")
        XCTAssertEqual(WeatherText.wind(nil, t), "—")
        XCTAssertEqual(WeatherText.uv(9, t), "Muy alto")
        XCTAssertEqual(WeatherText.aqi(35, t), "Razonable")
        XCTAssertEqual(WeatherText.pollen(0.5, t), "Nulo")
        XCTAssertEqual(WeatherText.pollen(60, t), "Alto")
        XCTAssertEqual(WeatherText.pollenName("olive", t), "Olivo")
        XCTAssertEqual(WeatherText.pollenName("other", t), "other")
        XCTAssertEqual(WeatherText.pressureTrend(now: 1016, before: 1013, t), "Subiendo")
        XCTAssertEqual(WeatherText.pressureTrend(now: 1013.5, before: 1013, t), "Estable")
        XCTAssertNil(WeatherText.pressureTrend(now: nil, before: 1013, t))
    }

    func testTheWindComesFromTheRightPointOfTheCompass() {
        let t = plain("es")
        XCTAssertEqual(WeatherText.compass(225, t), "SO")
        XCTAssertEqual(WeatherText.compass(-45, t), "NO")
        XCTAssertEqual(WeatherText.compass(359, t), "N")
        XCTAssertNil(WeatherText.compass(nil, t))
    }

    func testTheDewPointAndThePhaseOfTheMoon() throws {
        XCTAssertEqual(try XCTUnwrap(WeatherText.dewPoint(celsius: 20, humidity: 50)), 9.3, accuracy: 0.11)
        XCTAssertNil(WeatherText.dewPoint(celsius: nil, humidity: 50))
        XCTAssertNil(WeatherText.dewPoint(celsius: 20, humidity: 0))
        let t = plain("es")
        XCTAssertEqual(WeatherText.moonPhase(epochMs: 947_168_640_000, t).name, "Luna nueva")
        XCTAssertEqual(WeatherText.moonPhase(epochMs: 948_444_361_400, t).name, "Luna llena")
    }

    func testTheSettingsOfTheClientComeFromTheFileAndRefuseAnAddressThatIsNotHttps() {
        XCTAssertEqual(WeatherSettings.bundled(), WeatherSettings.defaults)
        XCTAssertEqual(WeatherSettings.parse([:]), WeatherSettings.defaults)
        XCTAssertEqual(WeatherSettings.parse(["forecast_api": "http://example.org"]).forecastApi, WeatherSettings.defaults.forecastApi)
        XCTAssertEqual(WeatherSettings.parse(["forecast_api": "https://example.org"]).forecastApi, "https://example.org")
        XCTAssertEqual(WeatherSettings.parse(["forecast_days": 99]).forecastDays, 16)
        XCTAssertEqual(WeatherSettings.parse(["forecast_days": 0]).forecastDays, 1)
    }

    func testTheClientAsksOnlyForThePlaceAndReadsTheAnswer() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let client = WeatherApiClient(session: URLSession(configuration: configuration), settings: .defaults)
        let place = Place(name: "Madrid", region: nil, country: nil, latitude: 40.4, longitude: -3.7)
        StubProtocol.routes["GET /v1/forecast"] = (200, sample)
        let f = try await client.forecast(place)
        XCTAssertEqual(f.hourly.time.count, 4)
        let query = try XCTUnwrap(StubProtocol.seen.last?.url?.query)
        for piece in ["latitude=40.4", "longitude=-3.7", "forecast_days=10", "timezone=auto"] { XCTAssertTrue(query.contains(piece), piece) }
        XCTAssertNil(StubProtocol.seen.last?.value(forHTTPHeaderField: "Cookie"))
        let missing = await client.airQuality(place)
        XCTAssertNil(missing)
        StubProtocol.routes["GET /v1/search"] = (200, #"{"results":[{"name":"Madrid","latitude":40.4,"longitude":-3.7}]}"#)
        let found = try await client.search("Madr", language: "es")
        XCTAssertEqual(found.map(\.name), ["Madrid"])
        let count = StubProtocol.seen.count
        let tooShort = try await client.search("M", language: "es")
        XCTAssertTrue(tooShort.isEmpty)
        XCTAssertEqual(StubProtocol.seen.count, count)
    }
}
