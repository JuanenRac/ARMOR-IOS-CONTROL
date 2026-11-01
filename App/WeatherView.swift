// ARMOR-IOS-CONTROL - the weather of the chosen place: now, the rain of the next hour, warnings, 24 hours, ten days, the air and pollen, the sun and the moon, and the live rain-and-cloud radar map.
// It talks to Open-Meteo directly, never to the server; nothing is asked until a place is chosen, and only its coordinates (or the text of a search) leave the phone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import WebKit
import ArmorCore

@MainActor
final class WeatherState: ObservableObject {
    @Published var place: Place?
    @Published var forecast: Forecast?
    @Published var air: AirQuality?
    @Published var loading = false
    @Published var failed = false
    @Published var results: [Place] = []
    private let client = WeatherApiClient(session: WeatherApiClient.makeSession())
    private static let key = "weather.place"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Place.self, from: data) { place = saved }
    }

    func load() async {
        guard let place else { return }
        loading = true; failed = false
        defer { loading = false }
        do {
            forecast = try await client.forecast(place)
            air = await client.airQuality(place)
        } catch { failed = true }
    }

    func choose(_ chosen: Place) async {
        place = chosen; results = []; forecast = nil; air = nil
        if let data = try? JSONEncoder().encode(chosen) { UserDefaults.standard.set(data, forKey: Self.key) }
        await load()
    }

    func changePlace() {
        place = nil; forecast = nil; air = nil; failed = false
        UserDefaults.standard.removeObject(forKey: Self.key)
    }

    func search(_ text: String, language: String) async {
        results = (try? await client.search(text, language: language)) ?? []
    }
}

/// The radar page (Leaflet, bundled in the app) shown in a web view; the place and the language come in the address of the page.
struct RadarMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let name: String
    let language: String
    let height: Int

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.04, green: 0.10, blue: 0.13, alpha: 1)
        view.scrollView.isScrollEnabled = false
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard let folder = Bundle.main.url(forResource: "Radar", withExtension: nil) else { return }
        let page = folder.appendingPathComponent("weather_radar.html")
        var parts = URLComponents(url: page, resolvingAgainstBaseURL: false)
        parts?.queryItems = [URLQueryItem(name: "lat", value: String(latitude)), URLQueryItem(name: "lon", value: String(longitude)), URLQueryItem(name: "name", value: name),
                             URLQueryItem(name: "h", value: String(height)), URLQueryItem(name: "lang", value: language)]
        guard let address = parts?.url, context.coordinator.loaded != address else { return }
        context.coordinator.loaded = address
        view.loadFileURL(address, allowingReadAccessTo: folder)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var loaded: URL? }
}

struct WeatherView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var weather = WeatherState()
    @State private var query = ""

    var body: some View {
        Group {
            if weather.place == nil { picker } else { forecastList }
        }
        .navigationTitle(model.tr("Meteorología"))
        .task { if weather.forecast == nil { await weather.load() } }
    }

    private var language: String { model.translator.language }

    private var picker: some View {
        List {
            Section(footer: Text(model.tr("No se pide nada por Internet hasta que eliges un lugar; solo sale su coordenada."))) {
                Text(model.tr("Elige el lugar del que quieres ver el tiempo"))
                TextField(model.tr("Buscar un lugar"), text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: query) { value in Task { await weather.search(value, language: language) } }
            }.listRowBackground(Theme.surface)
            if !weather.results.isEmpty {
                Section {
                    ForEach(weather.results, id: \.latitude) { place in
                        Button { Task { await weather.choose(place) } } label: {
                            VStack(alignment: .leading) {
                                Text(place.name).foregroundColor(.white)
                                Text([place.region, place.country].compactMap { $0 }.joined(separator: ", ")).font(.caption).foregroundColor(Theme.muted)
                            }
                        }
                    }
                }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
    }

    private var forecastList: some View {
        List {
            if let place = weather.place {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(place.name).font(.headline)
                            Text([place.region, place.country].compactMap { $0 }.joined(separator: ", ")).font(.caption).foregroundColor(Theme.muted)
                        }
                        Spacer()
                        Button(model.tr("Cambiar lugar")) { weather.changePlace() }.font(.footnote)
                    }
                    if weather.loading && weather.forecast == nil { ProgressView() }
                    if weather.failed { Text(model.tr("No se pudo cargar el tiempo.")).font(.footnote).foregroundColor(Theme.danger) }
                }.listRowBackground(Theme.surface)
                if let forecast = weather.forecast { details(forecast, place) }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .refreshable { await weather.load() }
    }

    @ViewBuilder private func details(_ forecast: Forecast, _ place: Place) -> some View {
        let t = model.translator
        let nowIso = WeatherText.localIso(nowMs: Int(Date().timeIntervalSince1970 * 1000), utcOffsetSeconds: forecast.utcOffsetSeconds)
        let fromIndex = WeatherText.hourIndex(forecast.hourly.time, nowIso)
        Section { hero(forecast) }.listRowBackground(Theme.surface)
        let rain = WeatherText.nextHourRain(forecast.minutely, nowIso)
        if rain.mm > 0 || rain.raining {
            Section {
                Text(rain.raining ? model.trf("Está lloviendo ahora · %s mm en la próxima hora", rain.mm) : model.trf("Puede llover: %s mm en la próxima hora", rain.mm)).font(.subheadline)
            }.listRowBackground(Theme.surface)
        }
        let warnings = WeatherText.warnings(forecast, fromIndex: fromIndex, t)
        if !warnings.isEmpty {
            Section {
                ForEach(warnings, id: \.key) { warning in
                    Text((warning.level == "warning" ? "⚠️ " : "⚠ ") + warning.key + " · " + WeatherText.dayOf(warning.at, language) + " " + WeatherText.hourOf(warning.at))
                        .font(.footnote).foregroundColor(warning.level == "warning" ? Theme.danger : Theme.amber)
                }
            }.listRowBackground(Theme.surface)
        }
        Section(header: Text(model.tr("Radar en directo"))) {
            RadarMapView(latitude: place.latitude, longitude: place.longitude, name: place.name, language: language, height: 340).frame(height: 340).listRowInsets(EdgeInsets())
        }
        Section(header: Text(model.tr("Próximas horas"))) { hourly(forecast, fromIndex) }.listRowBackground(Theme.surface)
        Section(header: Text(model.tr("Diez días"))) {
            ForEach(Array(forecast.daily.time.indices), id: \.self) { index in dayRow(forecast, index) }
        }.listRowBackground(Theme.surface)
        if let air = weather.air { Section { airPanel(air) }.listRowBackground(Theme.surface) }
        Section { sunMoon(forecast) }.listRowBackground(Theme.surface)
    }

    private func degrees(_ value: Double?) -> String { value.map { String(Int($0.rounded())) + "°" } ?? "—°" }

    private func hero(_ forecast: Forecast) -> some View {
        let t = model.translator
        let current = forecast.current
        let whole: (Double?) -> String = { $0.map { String(Int($0.rounded())) } ?? "—" }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(WeatherText.icon(current?.code)).font(.largeTitle)
                VStack(alignment: .leading) {
                    Text(degrees(current?.temperature)).font(.largeTitle.bold())
                    Text(WeatherText.description(current?.code, t)).font(.subheadline).foregroundColor(Theme.muted)
                }
            }
            Text(model.trf("Sensación %s° · Humedad %s%% · Nubes %s%%", whole(current?.apparent), whole(current?.humidity), whole(current?.cloud))).font(.caption).foregroundColor(Theme.muted)
            Text(model.trf("Viento %s %s · %s km/h (ráfagas %s)", WeatherText.wind(current?.windSpeed, t), WeatherText.compass(current?.windDir, t) ?? "", whole(current?.windSpeed), whole(current?.windGust)))
                .font(.caption).foregroundColor(Theme.muted)
            Text(model.trf("Presión %s hPa", whole(current?.pressure))).font(.caption).foregroundColor(Theme.muted)
        }
    }

    private func hourly(_ forecast: Forecast, _ fromIndex: Int) -> some View {
        let end = min(fromIndex + 24, forecast.hourly.time.count)
        let indices = fromIndex < end ? Array(fromIndex..<end) : []
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(indices, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text(WeatherText.hourOf(forecast.hourly.time[i])).font(.caption2).foregroundColor(Theme.muted)
                        Text(WeatherText.icon(i < forecast.hourly.code.count ? forecast.hourly.code[i] : nil))
                        Text(degrees(i < forecast.hourly.temperature.count ? forecast.hourly.temperature[i] : nil)).font(.subheadline.weight(.semibold))
                        if i < forecast.hourly.precipProb.count, let probability = forecast.hourly.precipProb[i], probability > 0 {
                            Text(String(Int(probability)) + "%").font(.caption2).foregroundColor(Theme.accent)
                        }
                    }.frame(width: 52)
                }
            }
        }
    }

    private func dayRow(_ forecast: Forecast, _ i: Int) -> some View {
        let day = forecast.daily
        let probability: Double? = i < day.precipProbMax.count ? day.precipProbMax[i] : nil
        let low: Double? = i < day.tMin.count ? day.tMin[i] : nil
        let high: Double? = i < day.tMax.count ? day.tMax[i] : nil
        return HStack {
            Text(WeatherText.weekday(day.time[i], language) + " " + WeatherText.dayOf(day.time[i], language)).font(.footnote).frame(width: 96, alignment: .leading)
            Text(WeatherText.icon(i < day.code.count ? day.code[i] : nil))
            Text((probability ?? 0) > 0 ? String(Int(probability ?? 0)) + "%" : "").font(.caption2).foregroundColor(Theme.accent).frame(width: 40)
            Spacer()
            Text(degrees(low) + " / " + degrees(high)).font(.subheadline.weight(.semibold))
        }
    }

    private func airPanel(_ air: AirQuality) -> some View {
        let t = model.translator
        let whole: (Double?) -> String = { $0.map { String(Int($0)) } ?? "—" }
        let index = air.europeanAqi.map { String($0) } ?? "—"
        let present = air.pollen.filter { $0.value > 0 }.sorted { $0.key < $1.key }
        return VStack(alignment: .leading, spacing: 6) {
            Text(model.tr("Aire y polen")).font(.subheadline.weight(.semibold))
            Text(model.trf("Calidad del aire: %s (índice %s) · PM2.5 %s · PM10 %s · O₃ %s · NO₂ %s", WeatherText.aqi(air.europeanAqi, t), index, whole(air.pm25), whole(air.pm10), whole(air.o3), whole(air.no2)))
                .font(.caption).foregroundColor(Theme.muted)
            if present.isEmpty { Text(model.tr("Sin polen relevante ahora mismo.")).font(.caption).foregroundColor(Theme.muted) }
            else { Text(present.map { WeatherText.pollenName($0.key, t) + ": " + WeatherText.pollen($0.value, t) }.joined(separator: " · ")).font(.caption).foregroundColor(Theme.muted) }
        }
    }

    private func sunMoon(_ forecast: Forecast) -> some View {
        let moon = WeatherText.moonPhase(epochMs: Int(Date().timeIntervalSince1970 * 1000), model.translator)
        let rise = forecast.daily.sunrise.first.map(WeatherText.hourOf) ?? "—"
        let set = forecast.daily.sunset.first.map(WeatherText.hourOf) ?? "—"
        return HStack {
            VStack(alignment: .leading) {
                Text(model.trf("☀️ Amanece %s", rise)).font(.footnote)
                Text(model.trf("Anochece %s", set)).font(.footnote)
            }
            Spacer()
            Text(moon.icon + " " + moon.name).font(.footnote)
        }
    }
}
