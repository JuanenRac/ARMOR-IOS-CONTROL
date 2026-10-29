// ARMOR-IOS-CONTROL - the sound files of the person and the voice that says the alarms.
// A notification can only play a sound file that is inside the app, in the folder Library/Sounds, so a file the person picks is copied there (under a name the rules of ArmorCore make) and the
// notification names it. The voice is AVSpeechSynthesizer, with the voice, pitch and pace that ArmorCore works out from the choices of the person.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import AVFoundation
import Foundation
import ArmorCore

/// The files of the sounds: keeping one, finding one, playing one to hear it.
@MainActor
final class AlarmSounds: NSObject {
    static let shared = AlarmSounds()
    private var player: AVAudioPlayer?

    /// Library/Sounds, where the system looks for the sound of a notification.
    static var folder: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds", isDirectory: true)
    }

    func url(of file: String) -> URL? { OwnSound.isStoredName(file) ? AlarmSounds.folder.appendingPathComponent(file) : nil }
    func exists(_ file: String) -> Bool { url(of: file).map { FileManager.default.fileExists(atPath: $0.path) } ?? false }

    /// Copies the file the person picked into the sounds of the app. Nil when it is too big, is not a sound iOS plays for a notification, lasts too long or could not be kept.
    func keep(_ source: URL) -> SoundChoice? {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        if let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > OwnSound.maxBytes { return nil }
        guard let data = try? Data(contentsOf: source), let probe = try? AVAudioPlayer(data: data) else { return nil }
        guard OwnSound.accepts(fileName: source.lastPathComponent, bytes: data.count, seconds: probe.duration) else { return nil }
        let stored = OwnSound.storedName(fileName: source.lastPathComponent, content: data)
        guard let target = url(of: stored) else { return nil }
        do {
            try FileManager.default.createDirectory(at: AlarmSounds.folder, withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
        } catch { return nil }
        return SoundChoice(kind: SoundChoice.own, file: stored, name: source.lastPathComponent)
    }

    /// Deletes the kept files that no choice uses any more.
    func prune(keeping settings: SoundSettings) {
        let used = Set((Array(settings.bySeverity.values) + Array(settings.byKind.values)).map(\.file))
        let names = (try? FileManager.default.contentsOfDirectory(atPath: AlarmSounds.folder.path)) ?? []
        for name in names where OwnSound.isStoredName(name) && !used.contains(name) {
            try? FileManager.default.removeItem(at: AlarmSounds.folder.appendingPathComponent(name))
        }
    }

    /// Plays a kept file so that the person hears it; a second call stops the first.
    func play(_ file: String) {
        stop()
        guard let url = url(of: file), exists(file) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func stop() { player?.stop(); player = nil }
}

/// Says an alarm aloud with the voice of the settings.
@MainActor
final class AlarmSpeaker {
    static let shared = AlarmSpeaker()
    private let synthesizer = AVSpeechSynthesizer()

    /// Queues a sentence in the language of the app (a code of ArmorCore) with the voice chosen.
    func say(_ text: String, voice: VoiceSettings, language: String) {
        let tag = SpeechLanguage.tag(for: language)
        let candidates = AVSpeechSynthesisVoice.speechVoices().map { VoiceCandidate(name: $0.identifier, language: $0.language, gender: AlarmSpeaker.gender(of: $0)) }
        let picked = voice.pick(candidates, language: tag)
        let utterance = AVSpeechUtterance(string: String(text.prefix(240)))
        if let chosen = picked.voice, let found = AVSpeechSynthesisVoice(identifier: chosen.name) { utterance.voice = found }
        else { utterance.voice = AVSpeechSynthesisVoice(language: tag) }
        utterance.pitchMultiplier = voice.pitch(genderFound: picked.genderFound)
        utterance.rate = voice.utteranceRate(normal: AVSpeechUtteranceDefaultSpeechRate, minimum: AVSpeechUtteranceMinimumSpeechRate, maximum: AVSpeechUtteranceMaximumSpeechRate)
        synthesizer.speak(utterance)
    }

    /// Stops what is being said (the person tests another voice).
    func stop() { synthesizer.stopSpeaking(at: .immediate) }

    /// The gender the system says for a voice (it only says it from iOS 17; before that the name is all there is).
    private static func gender(of voice: AVSpeechSynthesisVoice) -> String {
        if #available(iOS 17.0, *) {
            switch voice.gender {
            case .female: return "female"
            case .male: return "male"
            default: return ""
            }
        }
        return ""
    }
}
