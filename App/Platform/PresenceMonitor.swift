// ARMOR-IOS-CONTROL - the circle around home that the phone watches for the reminder on leaving (CoreLocation region monitoring). iOS wakes the app when the phone leaves it, even if the app was closed.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import CoreLocation
import ArmorCore

final class PresenceMonitor: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let store: PresenceStore
    /// The one monitor of the app: it exists from the launch (see AppDelegate), so a leave that wakes a closed app is heard.
    static let shared = PresenceMonitor(store: PresenceStore(PreferencesStore()))
    /// A leave heard before anybody was ready to act on it.
    private var leftWhileWaiting = false
    /// Called when the phone leaves the circle around home.
    var onLeft: (() async -> Void)? {
        didSet { if onLeft != nil, leftWhileWaiting { leftWhileWaiting = false; Task { await onLeft?() } } }
    }
    /// Called with the word "home" or "away" when the phone crosses the circle and the person chose to tell the server.
    var onWord: ((String) async -> Void)? {
        didSet { if let word = wordWhileWaiting, onWord != nil { wordWhileWaiting = nil; Task { await onWord?(word) } } }
    }
    /// The last word heard before anybody was ready to act on it.
    private var wordWhileWaiting: String?
    /// Called with the place just read, or nil when it could not be read.
    private var onPlace: ((HomePlace?) -> Void)?
    /// Called when the answer about the permission changes.
    var onAuthorization: (() -> Void)?

    init(store: PresenceStore) {
        self.store = store
        super.init()
        manager.delegate = self   // set at once: a leave that happened while the app was closed is delivered when it starts
    }

    var authorized: Bool { manager.authorizationStatus == .authorizedAlways }
    var askedAndRefused: Bool { manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted }

    /// Asks for the permission: first while in use (to read the place), then always (to hear the leave with the app closed).
    func askPermission() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default: break
        }
    }

    /// Reads the place the phone is in once.
    func readPlace(_ done: @escaping (HomePlace?) -> Void) {
        onPlace = done
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestLocation()
    }

    /// Watches the circle around the saved home when the reminder or the word for the server is on, and stops when both are off.
    func apply() {
        for region in manager.monitoredRegions where region.identifier == PresenceConfig.regionId { manager.stopMonitoring(for: region) }
        guard PresenceShare.watching(reminder: store.enabled, share: store.share, hasHome: store.home != nil), let home = store.home, authorized, CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: home.lat, longitude: home.lon), radius: PresenceConfig.radiusM, identifier: PresenceConfig.regionId)
        region.notifyOnEntry = PresenceShare.notifyOnEntry(share: store.share)
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        if store.share { manager.requestState(for: region) }   // announces the side the phone is on now, not only the next change
    }

    private func tell(_ word: String) {
        if onWord == nil { wordWhileWaiting = word } else { Task { await onWord?(word) } }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == PresenceConfig.regionId, store.share else { return }
        tell(PresenceShare.word(entered: true))
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == PresenceConfig.regionId, store.share, state != .unknown else { return }
        tell(PresenceShare.word(entered: state == .inside))
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == PresenceConfig.regionId else { return }
        if store.share { tell(PresenceShare.word(entered: false)) }
        guard store.enabled else { return }
        if onLeft == nil { leftWhileWaiting = true } else { Task { await onLeft?() } }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let place = locations.last.map { HomePlace(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
        onPlace?(place); onPlace = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { onPlace?(nil); onPlace = nil }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { apply(); onAuthorization?() }
}
