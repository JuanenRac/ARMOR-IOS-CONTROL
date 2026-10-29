import XCTest
@testable import ArmorCore

final class AlarmVoiceTests: XCTestCase {
    private let voices = [
        VoiceCandidate(name: "com.apple.voice.compact.en-GB.Daniel", language: "en-GB"),
        VoiceCandidate(name: "es-es-x-eed-local#female_1", language: "es-ES"),
        VoiceCandidate(name: "es-es-x-eec-local#male_1", language: "es-ES"),
        VoiceCandidate(name: "com.apple.voice.compact.es-MX.Paulina", language: "es-MX"),
    ]

    func testTheVoiceByDefaultIsAnAdultPlainOneAtTheNormalPace() {
        let voice = VoiceSettings()
        XCTAssertEqual(voice.pitch(genderFound: false), 1, accuracy: 0.001)
        XCTAssertEqual(voice.rate(), 1, accuracy: 0.001)
        XCTAssertFalse(voice.speaks("warning"))
        XCTAssertTrue(voice.speaks("critical") && voice.speaks("high"))
    }

    func testTheAgeAndTheStyleMultiplyAsInStudio() {
        let child = VoiceSettings(age: "child", style: "hero")
        XCTAssertEqual(child.pitch(genderFound: false), 1.6 * 1.12, accuracy: 0.001)
        XCTAssertEqual(child.rate(), 1.1 * 1.22, accuracy: 0.001)
        let senior = VoiceSettings(age: "senior", style: "dark", speed: 50)
        XCTAssertEqual(senior.pitch(genderFound: false), 0.5, accuracy: 0.001)    // 0.7 * 0.55 is under what the engine of iOS takes: the pitch stops at 0.5
        XCTAssertEqual(senior.rate(), 0.88 * 0.82 * 0.5, accuracy: 0.001)
    }

    func testThePitchAndThePaceStayWhereASpeechEngineCanTakeThem() {
        let low = VoiceSettings(gender: "male", age: "senior", style: "dark")
        XCTAssertGreaterThanOrEqual(low.pitch(genderFound: false), VoiceSettings.minPitch)
        let high = VoiceSettings(gender: "female", age: "child", style: "hero", speed: 200)
        XCTAssertLessThanOrEqual(high.pitch(genderFound: false), VoiceSettings.maxPitch)
        XCTAssertLessThanOrEqual(high.rate(), 3)
        XCTAssertGreaterThanOrEqual(VoiceSettings(speed: 1).rate(), 0.3)
    }

    func testTheRateOfTheUtteranceStaysBetweenTheSlowestAndTheFastestOfTheEngine() {
        XCTAssertEqual(VoiceSettings().utteranceRate(normal: 0.5, minimum: 0, maximum: 1), 0.5, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings(speed: 200).utteranceRate(normal: 0.5, minimum: 0, maximum: 1), 1, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings(age: "child", style: "hero", speed: 200).utteranceRate(normal: 0.5, minimum: 0, maximum: 1), 1, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings(speed: 50).utteranceRate(normal: 0.5, minimum: 0.2, maximum: 1), 0.25, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings(age: "senior", style: "dark", speed: 50).utteranceRate(normal: 0.5, minimum: 0.3, maximum: 1), 0.3, accuracy: 0.001)
    }

    func testTheGenderChangesThePitchOnlyWhenNoVoiceSaidIt() {
        XCTAssertEqual(VoiceSettings(gender: "female").pitch(genderFound: false), 1.12, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings(gender: "male").pitch(genderFound: false), 0.82, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings(gender: "female").pitch(genderFound: true), 1, accuracy: 0.001)
    }

    func testANameThatSaysTheGenderIsRead() {
        XCTAssertEqual(VoiceSettings.hint("es-es-x-eed-local#female_1"), "female")
        XCTAssertEqual(VoiceSettings.hint("es-es-x-eec-local#male_1"), "male")
        XCTAssertEqual(VoiceSettings.hint("Microsoft Helena Woman"), "female")
        XCTAssertEqual(VoiceSettings.hint("Deep Man"), "male")
        XCTAssertEqual(VoiceSettings.hint("com.apple.voice.compact.en-GB.Daniel"), "")
        XCTAssertEqual(VoiceSettings.hint("human voice"), "")
        XCTAssertEqual(VoiceSettings.hint("Germano"), "")
    }

    func testTheVoiceOfTheLanguageWithTheWantedGenderIsPicked() {
        let woman = VoiceSettings(gender: "female").pick(voices, language: "es")
        XCTAssertEqual(woman.voice?.name, "es-es-x-eed-local#female_1")
        XCTAssertTrue(woman.genderFound)
        let man = VoiceSettings(gender: "male").pick(voices, language: "es")
        XCTAssertEqual(man.voice?.name, "es-es-x-eec-local#male_1")
        XCTAssertTrue(man.genderFound)
    }

    func testTheGenderThatTheSystemSaysCountsEvenWhenTheNameDoesNot() {
        let system = [VoiceCandidate(name: "id.daniel", language: "en-GB", gender: "male"), VoiceCandidate(name: "id.kate", language: "en-GB", gender: "female")]
        XCTAssertEqual(VoiceSettings(gender: "female").pick(system, language: "en").voice?.name, "id.kate")
        XCTAssertEqual(VoiceSettings(gender: "male").pick(system, language: "en-GB").voice?.name, "id.daniel")
    }

    func testWithoutAVoiceOfThatGenderTheFirstOfTheLanguageIsUsedAndThePitchStandsIn() {
        let picked = VoiceSettings(gender: "female").pick(voices, language: "en")
        XCTAssertEqual(picked.voice?.name, "com.apple.voice.compact.en-GB.Daniel")
        XCTAssertFalse(picked.genderFound)
    }

    func testAnyGenderPrefersTheVoiceOfTheExactRegion() {
        XCTAssertEqual(VoiceSettings().pick(voices, language: "es-MX").voice?.name, "com.apple.voice.compact.es-MX.Paulina")
        XCTAssertEqual(VoiceSettings().pick(voices, language: "es").voice?.name, "es-es-x-eed-local#female_1")
    }

    func testNoVoiceOfTheLanguageLeavesTheEnginesOwn() {
        XCTAssertNil(VoiceSettings().pick(voices, language: "ja").voice)
        XCTAssertNil(VoiceSettings().pick([], language: "es").voice)
    }

    func testTheChoicesSurviveBeingWrittenAndRead() {
        let voice = VoiceSettings(gender: "male", age: "senior", style: "dark", speed: 130, warnings: true)
        XCTAssertEqual(VoiceSettings.decode(voice.encode()), voice)
    }

    func testDamagedTextOrValuesThatAreNotKnownAreTheDefaultOnes() {
        XCTAssertEqual(VoiceSettings.decode(nil), VoiceSettings())
        XCTAssertEqual(VoiceSettings.decode("x|y"), VoiceSettings())
        XCTAssertEqual(VoiceSettings.decode("robot|ancient|chaos|abc|false"), VoiceSettings())
        XCTAssertEqual(VoiceSettings.decode("any|adult|plain|900|false").speed, 200)
        XCTAssertEqual(VoiceSettings.decode("any|adult|plain|1|false").speed, 50)
    }

    func testANoticeIsSaidOnlyWhenItIsShownWithSoundAndTheVoiceSaysItsSeverity() {
        let voice = VoiceSettings()
        XCTAssertTrue(AlarmSpeech.shouldSpeak(.show, enabled: true, voice: voice, severity: "critical"))
        XCTAssertFalse(AlarmSpeech.shouldSpeak(.show, enabled: false, voice: voice, severity: "critical"))     // off by default
        XCTAssertFalse(AlarmSpeech.shouldSpeak(.silent, enabled: true, voice: voice, severity: "high"))        // without sound is without voice
        XCTAssertFalse(AlarmSpeech.shouldSpeak(.hide, enabled: true, voice: voice, severity: "critical"))
        XCTAssertFalse(AlarmSpeech.shouldSpeak(.show, enabled: true, voice: voice, severity: "warning"))
        XCTAssertTrue(AlarmSpeech.shouldSpeak(.show, enabled: true, voice: VoiceSettings(warnings: true), severity: "warning"))
    }

    func testEveryLanguageOfTheAppHasATagForTheSpeechEngine() {
        XCTAssertEqual(Translator.languages.map { SpeechLanguage.tag(for: $0.code) }, ["en-US", "es-ES", "de-DE", "fr-FR", "it-IT", "ja-JP", "zh-CN", "pt-PT"])
        XCTAssertEqual(SpeechLanguage.tag(for: "xx"), "en-US")
    }

    func testTheVoiceAndTheSpeakingSwitchLiveInTheStoreOfThePreferences() {
        let store = MemoryStore()
        XCTAssertEqual(VoicePreferences.load(store), VoiceSettings())
        XCTAssertFalse(VoicePreferences.speaks(store))
        VoicePreferences.setSpeaks(store, true)
        VoicePreferences.save(store, VoiceSettings(gender: "female", speed: 80))
        XCTAssertTrue(VoicePreferences.speaks(store))
        XCTAssertEqual(VoicePreferences.load(store).speed, 80)
    }
}
