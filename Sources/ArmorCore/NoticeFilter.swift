// ARMOR-IOS-CONTROL - which notices the person wants to be told about, and how.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// What the phone does with a notice: show it as usual, show it without sound, or not show it at all (the history keeps everything either way).
public enum NoticeDecision: Equatable, Sendable { case show, silent, hide }

/// The kinds of notice the person can switch off, in the order of the settings. A notice of the app itself (the server does not answer) is of kind `system`.
public enum NoticeKinds {
    public static let system = "system"
    public static let choices = ["alert", "camera", "node", "alarm.device", "alarm.solar", "alarm.electrical", "alarm.network", "alarm.alarm", "alarm.other"]

    /// The kind of an alarm by where it comes from.
    public static func ofAlarm(_ sourceType: String?) -> String {
        switch sourceType {
        case "device", "solar", "electrical", "network", "alarm": return "alarm.\(sourceType ?? "")"
        default: return "alarm.other"
        }
    }
}

/// The choices of the person, which come before the sound: `muted` shows nothing at all; `silent` shows everything without sound and does not say it aloud; the rest takes some notices away
/// by severity or by kind. A critical notice is never taken away by severity or by kind (smoke, gas, water, panic: the one that matters most), only by `muted`, which asks for it on its own;
/// and it is the only one that `silent` leaves with its sound.
public struct NoticeSettings: Equatable, Sendable {
    public var muted: Bool
    public var silent: Bool
    public var mutedSeverities: Set<String>
    public var mutedKinds: Set<String>

    public static let severities = ["warning", "high"]

    public init(muted: Bool = false, silent: Bool = false, mutedSeverities: Set<String> = [], mutedKinds: Set<String> = []) {
        self.muted = muted; self.silent = silent; self.mutedSeverities = mutedSeverities; self.mutedKinds = mutedKinds
    }

    public func decide(_ notice: AlarmNotice) -> NoticeDecision {
        if muted { return .hide }
        let critical = notice.severity == "critical"
        if !critical && (mutedSeverities.contains(notice.severity) || mutedKinds.contains(notice.kind)) { return .hide }
        if silent && !critical { return .silent }
        return .show
    }

    public func withSeverity(_ severity: String, off: Bool) -> NoticeSettings {
        var copy = self
        if off { copy.mutedSeverities.insert(severity) } else { copy.mutedSeverities.remove(severity) }
        return copy
    }
    public func withKind(_ kind: String, off: Bool) -> NoticeSettings {
        var copy = self
        if off { copy.mutedKinds.insert(kind) } else { copy.mutedKinds.remove(kind) }
        return copy
    }

    /// One line per value, so that the store needs no more than text.
    public func encode() -> String {
        [String(muted), String(silent), mutedSeverities.sorted().joined(separator: ","), mutedKinds.sorted().joined(separator: ",")].joined(separator: "|")
    }

    /// Reads what `encode` wrote; anything else (nothing, a damaged text, a value that is not known) is the way it was before: everything shows.
    public static func decode(_ text: String?) -> NoticeSettings {
        guard let text else { return NoticeSettings() }
        let parts = text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if parts.count != 4 { return NoticeSettings() }
        func list(_ value: String, _ known: [String]) -> Set<String> { Set(value.split(separator: ",").map(String.init).filter { known.contains($0) }) }
        return NoticeSettings(muted: parts[0] == "true", silent: parts[1] == "true", mutedSeverities: list(parts[2], severities), mutedKinds: list(parts[3], NoticeKinds.choices))
    }
}
