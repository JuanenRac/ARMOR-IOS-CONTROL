// ARMOR-IOS-CONTROL - which sound each alarm makes: one per severity, and one per kind of alarm when the person wants it, from a sound file of their own.
// iOS gives an app no list of the phone's own sounds, and a notification can only play a sound file that is inside the app (Library/Sounds) in the formats iOS plays for notifications
// (linear PCM, IMA4, uLaw or aLaw in an .aiff, .wav or .caf file, 30 seconds at most), so the choice here is the default of the severity or a file of the person.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// What plays for a notice: the sound of its severity as it is (`default`: the critical sound of the system for a critical one, the notification sound for the rest), or a file the person chose
/// (`own`, kept in the Library/Sounds folder of the app under `file`).
public struct SoundChoice: Equatable, Sendable {
    public static let defaultKind = "default"
    public static let own = "own"

    public var kind: String
    public var file: String
    public var name: String
    public init(kind: String = SoundChoice.defaultKind, file: String = "", name: String = "") { self.kind = kind; self.file = file; self.name = name }

    public var isDefault: Bool { kind == SoundChoice.defaultKind }
}

/// The sounds of the person: one per severity and, above it, one per kind of notice (the kinds of `NoticeKinds`). Nothing chosen is the way it was before: the default of each severity.
public struct SoundSettings: Equatable, Sendable {
    public var bySeverity: [String: SoundChoice]
    public var byKind: [String: SoundChoice]
    public init(bySeverity: [String: SoundChoice] = [:], byKind: [String: SoundChoice] = [:]) { self.bySeverity = bySeverity; self.byKind = byKind }

    /// The severities that have a sound of their own, from the most to the least grave.
    public static let severities = ["critical", "high", "warning"]

    /// The kind comes first (it is the more specific choice), then the severity, then the default.
    public func choiceFor(severity: String, kind: String) -> SoundChoice { byKind[kind] ?? bySeverity[severity] ?? SoundChoice() }

    public func withSeverity(_ severity: String, _ choice: SoundChoice) -> SoundSettings {
        SoundSettings(bySeverity: SoundSettings.update(bySeverity, severity, choice, SoundSettings.severities), byKind: byKind)
    }
    public func withKind(_ kind: String, _ choice: SoundChoice) -> SoundSettings {
        SoundSettings(bySeverity: bySeverity, byKind: SoundSettings.update(byKind, kind, choice, NoticeKinds.choices))
    }

    private static func update(_ map: [String: SoundChoice], _ key: String, _ choice: SoundChoice, _ known: [String]) -> [String: SoundChoice] {
        var copy = map
        if !known.contains(key) { return map }
        if choice.isDefault || !OwnSound.isStoredName(choice.file) { copy.removeValue(forKey: key) } else { copy[key] = choice }
        return copy
    }

    /// The sound file a notice plays: nil for the default sound of its severity.
    public func fileFor(severity: String, kind: String) -> String? {
        let choice = choiceFor(severity: severity, kind: kind)
        return choice.isDefault ? nil : choice.file
    }

    /// One line per choice (`S` for a severity, `K` for a kind), the fields apart by a tab, so that the store needs no more than text.
    public func encode() -> String {
        (bySeverity.map { SoundSettings.line("S", $0.key, $0.value) } + byKind.map { SoundSettings.line("K", $0.key, $0.value) }).sorted().joined(separator: "\n")
    }

    private static func line(_ scope: String, _ key: String, _ choice: SoundChoice) -> String {
        [scope, key, choice.kind, clean(choice.file), clean(choice.name)].joined(separator: "\t")
    }

    private static func clean(_ text: String) -> String {
        let flat = text.map { $0 == "\t" || $0 == "\n" || $0 == "\r" ? " " : $0 }
        return String(String(flat).trimmingCharacters(in: .whitespaces).prefix(300))
    }

    /// Reads what `encode` wrote; anything else (nothing, a damaged line, a kind that is not known, a file name that is not one of ours) is skipped and leaves the default.
    public static func decode(_ text: String?) -> SoundSettings {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return SoundSettings() }
        var severities: [String: SoundChoice] = [:]
        var kinds: [String: SoundChoice] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if parts.count != 5 || parts[2] != SoundChoice.own || !OwnSound.isStoredName(parts[3]) { continue }
            let choice = SoundChoice(kind: SoundChoice.own, file: parts[3], name: parts[4])
            if parts[0] == "S", SoundSettings.severities.contains(parts[1]) { severities[parts[1]] = choice }
            else if parts[0] == "K", NoticeKinds.choices.contains(parts[1]) { kinds[parts[1]] = choice }
        }
        return SoundSettings(bySeverity: severities, byKind: kinds)
    }

    /// The settings with the choice put on the severity or the kind that is being chosen.
    public func applying(_ choice: SoundChoice, key: String, isKind: Bool) -> SoundSettings { isKind ? withKind(key, choice) : withSeverity(key, choice) }
}

/// The rules for a sound file of the person.
public enum OwnSound {
    /// The most a sound file may weigh: a sound for a notification is short, and it is copied.
    public static let maxBytes = 3 * 1024 * 1024
    /// The most a sound for a notification may last: iOS plays the default sound instead of a longer one.
    public static let maxSeconds = 30.0
    /// The containers iOS plays for a notification.
    public static let extensions = ["aiff", "aif", "wav", "caf"]
    static let prefix = "armor_"

    /// Whether a file can be a notification sound: a known container, not empty, under the weight and the length allowed (`seconds` is nil when it cannot be told).
    public static func accepts(fileName: String, bytes: Int, seconds: Double?) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard extensions.contains(ext), bytes > 0, bytes <= maxBytes else { return false }
        if let seconds { return seconds > 0 && seconds <= maxSeconds }
        return false
    }

    /// The name the file is kept under: only safe characters, the container it came in and a short fingerprint of its bytes so that two files of the same name do not overwrite each other.
    public static func storedName(fileName: String, content: Data) -> String {
        let ns = fileName as NSString
        let ext = ns.pathExtension.lowercased()
        let base = ns.deletingPathExtension.map { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") ? $0 : "_" }
        var hash: UInt32 = 2166136261
        for byte in content { hash = (hash ^ UInt32(byte)) &* 16777619 }
        return prefix + String(String(base).prefix(40)) + "_" + String(hash, radix: 16) + "." + ext
    }

    /// Whether a name is one that `storedName` makes (so that a damaged store can never point the app at another folder or file).
    public static func isStoredName(_ name: String) -> Bool {
        guard name.hasPrefix(prefix), !name.contains("/"), !name.contains("\\"), !name.contains("..") else { return false }
        return extensions.contains((name as NSString).pathExtension.lowercased())
    }
}
