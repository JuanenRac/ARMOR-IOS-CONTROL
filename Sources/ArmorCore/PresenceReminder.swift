// ARMOR-IOS-CONTROL - the reminder on leaving home, as the Android app has it: when the phone leaves the place the person saved as home and the alarm is not armed, a notice says so. Off until the person turns it on.
// Everything stays on the phone: the place is kept in the preferences of the app and is never sent to the server; the only thing asked of the server is whether the system is armed.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The numbers of the reminder, in one place (the same as the Android app).
public enum PresenceConfig {
    /// The radius of home, in metres: the phone has left when it is farther than this from the saved place.
    public static let radiusM: Double = 150
    /// After a reminder, the next one waits this long (milliseconds): a phone at the edge of the radius goes in and out.
    public static let cooldownMs: Int64 = 30 * 60_000
    public static let regionId = "armor-home"
    /// Where the reminder shows in the list of notices; one place, so a second reminder replaces the first.
    public static let noticeId = 9_100
}

/// What the reminder says.
public enum Reminder: Equatable, Sendable { case armNow, check }

public enum PresenceDecision {
    /// The phone left home. `mode` is what the server says ("armed", "disarmed"), or nil when it could not be read. Armed: nothing to say. Disarmed: remind to arm. Unknown: ask the person to check,
    /// because a reminder that stays silent when the server cannot be reached is the case that matters. Inside the quiet time after a reminder: nothing.
    public static func onLeft(mode: String?, lastReminderMs: Int64, nowMs: Int64) -> Reminder? {
        if lastReminderMs > 0 && nowMs - lastReminderMs >= 0 && nowMs - lastReminderMs < PresenceConfig.cooldownMs { return nil }
        switch mode {
        case "armed": return nil
        case "disarmed": return .armNow
        default: return .check
        }
    }
}

/// What the phone tells the server about being at home: only the word "home" or "away", chosen by the circle around the saved place (the same as the Android app). Off by default and apart from the reminder.
/// The place never leaves the phone; the server only learns which side of the circle the phone is on.
public enum PresenceShare {
    /// The word for crossing the circle: entering says "home", leaving says "away".
    public static func word(entered: Bool) -> String { entered ? "home" : "away" }
    /// Whether the circle is watched at all: something is on and a place is saved.
    public static func watching(reminder: Bool, share: Bool, hasHome: Bool) -> Bool { hasHome && (reminder || share) }
    /// Whether coming back is heard: only the word needs it (the reminder is about leaving).
    public static func notifyOnEntry(share: Bool) -> Bool { share }
    /// Whether the word is one the server accepts.
    public static func valid(_ word: String) -> Bool { word == "home" || word == "away" }
}

/// The place saved as home.
public struct HomePlace: Equatable, Sendable {
    public let lat: Double
    public let lon: Double
    public init(lat: Double, lon: Double) { self.lat = lat; self.lon = lon }
    public var valid: Bool { (-90.0...90.0).contains(lat) && (-180.0...180.0).contains(lon) && !(lat == 0 && lon == 0) }
}

/// What the person chose, kept in the preferences of the app. Off by default.
public final class PresenceStore: @unchecked Sendable {
    private let store: KeyValueStore
    public init(_ store: KeyValueStore) { self.store = store }

    public var enabled: Bool {
        get { store.get("presence_on") == "1" }
        set { if newValue { store.put("presence_on", "1") } else { store.remove("presence_on") } }
    }

    /// The phone tells the server "home" or "away" (PUT /api/v1/presence/me). Off by default, per person, and apart from the reminder.
    public var share: Bool {
        get { store.get("presence_share") == "1" }
        set { if newValue { store.put("presence_share", "1") } else { store.remove("presence_share") } }
    }

    public var home: HomePlace? {
        get {
            guard let lat = store.get("presence_lat").flatMap(Double.init), let lon = store.get("presence_lon").flatMap(Double.init) else { return nil }
            let place = HomePlace(lat: lat, lon: lon)
            return place.valid ? place : nil
        }
        set {
            if let place = newValue, place.valid { store.put("presence_lat", String(place.lat)); store.put("presence_lon", String(place.lon)) }
            else { store.remove("presence_lat"); store.remove("presence_lon") }
        }
    }

    public var lastReminderMs: Int64 {
        get { store.get("presence_last").flatMap(Int64.init) ?? 0 }
        set { store.put("presence_last", String(newValue)) }
    }
}
