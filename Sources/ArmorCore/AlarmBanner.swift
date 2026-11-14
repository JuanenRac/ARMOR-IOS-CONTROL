// ARMOR-IOS-CONTROL - the alarm window of the open app: a pulsing banner over the screens while an alarm waits for a person (the same rules as the Android app).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// What the banner says: the worst alarm that nobody has confirmed, and how many wait. `key` changes whenever the set of waiting alarms changes, so a closed banner comes back for a new alarm.
public struct AlarmBannerModel: Equatable, Sendable {
    public let severity: String
    public let count: Int
    public let title: String
    public let detail: String
    public let key: String
    public let alarm: Alarm
}

public enum AlarmBannerPolicy {
    private static func rank(_ severity: String) -> Int {
        switch severity {
        case "critical": return 3
        case "high": return 2
        default: return 1
        }
    }

    /// The alarms that wait for a person: not confirmed, and not the silent kind (the alarm of a duress PIN is never shown on a phone).
    public static func waiting(_ alarms: [Alarm]) -> [Alarm] { alarms.filter { !$0.acknowledged && !AlarmPolicy.isSilent($0.code) } }

    public static func key(_ alarms: [Alarm]) -> String { waiting(alarms).map { $0.id }.sorted().joined(separator: ",") }

    /// The banner to show, or nil when nothing waits or the person closed this very set of alarms.
    public static func from(_ alarms: [Alarm], closedKey: String?, _ translator: Translator) -> AlarmBannerModel? {
        let open = waiting(alarms)
        if open.isEmpty { return nil }
        let setKey = key(alarms)
        if setKey == closedKey { return nil }
        let worst = open.sorted { a, b in
            let (ra, rb) = (rank(a.severity), rank(b.severity))
            return ra != rb ? ra > rb : a.raisedAt > b.raisedAt
        }[0]
        let title = open.count == 1 ? translator.trf("ALARMA %s", AlarmText.severityLabel(worst.severity, translator)) : translator.trf("%d alarmas sin confirmar", open.count)
        return AlarmBannerModel(severity: worst.severity, count: open.count, title: title, detail: "\(AlarmText.text(worst.code, translator)) · \(worst.sourceId)", key: setKey, alarm: worst)
    }

    /// How slow the pulse is, in seconds: a critical alarm beats faster.
    public static func pulseSeconds(_ severity: String) -> Double { severity == "critical" ? 0.6 : 1.1 }

    /// Critical is red and loud; the rest are amber.
    public static func isCritical(_ severity: String) -> Bool { severity == "critical" }
}
