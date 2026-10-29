// ARMOR-IOS-CONTROL - how the phone says an alarm aloud: the voice (woman, man), the age, the style and the speed, the same choices as the voice of Studio and of the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// A voice of the phone's speech engine as far as the choice needs it: its identifier, the language it speaks and, when the system says it, its gender ("female", "male" or "").
public struct VoiceCandidate: Equatable, Sendable {
    public let name: String, language: String, gender: String
    public init(name: String, language: String, gender: String = "") { self.name = name; self.language = language; self.gender = gender }
}

/// The voice of the alarms. `gender` is "any", "female" or "male"; `age` is "child", "adult" or "senior"; `style` is "plain", "hero" or "dark"; `speed` is the percent of the normal pace
/// (50 to 200); `warnings` says whether the notices of low severity are spoken too (the critical and the high ones are, once the phone is set to speak).
/// The gender is read from the voice when the system says it and from its name when the name says it; when no voice of the language does, a higher or lower pitch stands for it.
public struct VoiceSettings: Equatable, Sendable {
    public var gender: String, age: String, style: String
    public var speed: Int
    public var warnings: Bool

    public static let genders = ["any", "female", "male"]
    public static let ages = ["child", "adult", "senior"]
    public static let styles = ["plain", "hero", "dark"]
    public static let minSpeed = 50
    public static let maxSpeed = 200
    /// What a speech engine of iOS takes for the pitch (AVSpeechUtterance.pitchMultiplier).
    public static let minPitch: Float = 0.5
    public static let maxPitch: Float = 2.0
    /// What the age and the style do to the pitch and the pace (the same numbers as Studio).
    private static let agePitch: [String: Float] = ["child": 1.6, "adult": 1, "senior": 0.7]
    private static let ageRate: [String: Float] = ["child": 1.1, "adult": 1, "senior": 0.88]
    private static let stylePitch: [String: Float] = ["plain": 1, "hero": 1.12, "dark": 0.55]
    private static let styleRate: [String: Float] = ["plain": 1, "hero": 1.22, "dark": 0.82]

    public init(gender: String = "any", age: String = "adult", style: String = "plain", speed: Int = 100, warnings: Bool = false) {
        self.gender = gender; self.age = age; self.style = style; self.speed = speed; self.warnings = warnings
    }

    public func speaks(_ severity: String) -> Bool { severity != "warning" || warnings }

    /// The pitch: the age's times the style's (and the gender's, only when no voice of that gender was found), kept where the engine can take it.
    public func pitch(genderFound: Bool) -> Float {
        let byGender: Float = genderFound ? 1 : (gender == "female" ? 1.12 : (gender == "male" ? 0.82 : 1))
        let value = (VoiceSettings.agePitch[age] ?? 1) * (VoiceSettings.stylePitch[style] ?? 1) * byGender
        return min(max(value, VoiceSettings.minPitch), VoiceSettings.maxPitch)
    }

    /// The pace as a multiple of the normal one: the age's times the style's times the speed that was set.
    public func rate() -> Float {
        let percent = Float(min(max(speed, VoiceSettings.minSpeed), VoiceSettings.maxSpeed)) / 100
        return min(max((VoiceSettings.ageRate[age] ?? 1) * (VoiceSettings.styleRate[style] ?? 1) * percent, 0.3), 3)
    }

    /// The rate that AVSpeechUtterance takes (its own scale, with `normal` as the usual pace): the multiple of the normal pace, kept between the slowest and the fastest the engine has.
    public func utteranceRate(normal: Float, minimum: Float, maximum: Float) -> Float { min(max(normal * rate(), minimum), maximum) }

    /// The voice of the language that has the wanted gender, else the first of the language, else none (the engine keeps its own). The second value says whether a voice of that gender was found.
    public func pick(_ voices: [VoiceCandidate], language: String) -> (voice: VoiceCandidate?, genderFound: Bool) {
        func base(_ code: String) -> String { String(code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "") }
        let ofLanguage = voices.filter { base($0.language) == base(language) }
        guard let first = ofLanguage.first else { return (nil, false) }
        if gender == "any" {
            let exact = ofLanguage.first { $0.language.lowercased().replacingOccurrences(of: "_", with: "-") == language.lowercased() }
            return (exact ?? first, false)
        }
        if let named = ofLanguage.first(where: { VoiceSettings.genderOf($0) == gender }) { return (named, true) }
        return (first, false)
    }

    private static func genderOf(_ voice: VoiceCandidate) -> String { voice.gender.isEmpty ? hint(voice.name) : voice.gender }

    /// "female" or "male" when the name of a voice says it, else "".
    public static func hint(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("female") || lower.contains("woman") { return "female" }
        if lower.contains("male") { return "male" }
        let letters = Array(lower)
        var i = 0
        while i + 3 <= letters.count {
            if String(letters[i..<i + 3]) == "man" {
                let before = i == 0 || !(letters[i - 1].isASCII && letters[i - 1].isLetter)
                let after = i + 3 == letters.count || !(letters[i + 3].isASCII && letters[i + 3].isLetter)
                if before && after { return "male" }
            }
            i += 1
        }
        return ""
    }

    public func encode() -> String { [gender, age, style, String(speed), String(warnings)].joined(separator: "|") }

    /// Reads what `encode` wrote; anything else (nothing, a damaged text, a value that is not known) is the way it was before.
    public static func decode(_ text: String?) -> VoiceSettings {
        guard let text else { return VoiceSettings() }
        let parts = text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if parts.count != 5 { return VoiceSettings() }
        return VoiceSettings(
            gender: genders.contains(parts[0]) ? parts[0] : "any",
            age: ages.contains(parts[1]) ? parts[1] : "adult",
            style: styles.contains(parts[2]) ? parts[2] : "plain",
            speed: min(max(Int(parts[3]) ?? 100, minSpeed), maxSpeed),
            warnings: parts[4] == "true")
    }
}

public enum SpeechLanguage {
    /// The language tag a speech engine knows for each language of the app (the Portuguese is the one of Portugal).
    public static func tag(for code: String) -> String {
        switch code {
        case "es": return "es-ES"
        case "de": return "de-DE"
        case "fr": return "fr-FR"
        case "it": return "it-IT"
        case "ja": return "ja-JP"
        case "zh": return "zh-CN"
        case "pt": return "pt-PT"
        default: return "en-US"
        }
    }
}

/// When a notice is said aloud: only a notice that is shown with its sound (not a silent one), when the person turned speaking on, and in the severities the voice says.
public enum AlarmSpeech {
    public static func shouldSpeak(_ decision: NoticeDecision, enabled: Bool, voice: VoiceSettings, severity: String) -> Bool {
        decision == .show && enabled && voice.speaks(severity)
    }
}

/// The choices kept in the preferences of the app, read by the open app and by the push that wakes it alike.
public enum NoticePreferences {
    public static func load(_ store: KeyValueStore) -> NoticeSettings { NoticeSettings.decode(store.get("notice_settings")) }
    public static func save(_ store: KeyValueStore, _ settings: NoticeSettings) { store.put("notice_settings", settings.encode()) }
}

public enum SoundPreferences {
    public static func load(_ store: KeyValueStore) -> SoundSettings { SoundSettings.decode(store.get("sound_settings")) }
    public static func save(_ store: KeyValueStore, _ settings: SoundSettings) { store.put("sound_settings", settings.encode()) }
}

public enum VoicePreferences {
    public static func load(_ store: KeyValueStore) -> VoiceSettings { VoiceSettings.decode(store.get("voice_settings")) }
    public static func save(_ store: KeyValueStore, _ settings: VoiceSettings) { store.put("voice_settings", settings.encode()) }
    /// Whether the phone says an alarm aloud as well as showing it (off by default).
    public static func speaks(_ store: KeyValueStore) -> Bool { store.get("speak_alarms") == "true" }
    public static func setSpeaks(_ store: KeyValueStore, _ on: Bool) { store.put("speak_alarms", String(on)) }
}
