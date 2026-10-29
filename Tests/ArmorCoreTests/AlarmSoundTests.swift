import XCTest
@testable import ArmorCore

final class AlarmSoundTests: XCTestCase {
    private let siren = SoundChoice(kind: SoundChoice.own, file: "armor_siren_1a2b.wav", name: "siren.wav")
    private let beep = SoundChoice(kind: SoundChoice.own, file: "armor_beep_3c4d.caf", name: "beep.caf")

    func testNothingChosenIsTheDefaultOfEverySeverity() {
        let settings = SoundSettings()
        for severity in SoundSettings.severities { XCTAssertTrue(settings.choiceFor(severity: severity, kind: "alarm.device").isDefault) }
        XCTAssertNil(settings.fileFor(severity: "critical", kind: "alert"))
    }

    func testTheKindWinsOverTheSeverityAndTheSeverityOverTheDefault() {
        let settings = SoundSettings().withSeverity("critical", beep).withKind("alarm.solar", siren)
        XCTAssertEqual(settings.choiceFor(severity: "critical", kind: "alarm.solar"), siren)
        XCTAssertEqual(settings.choiceFor(severity: "critical", kind: "alarm.device"), beep)
        XCTAssertTrue(settings.choiceFor(severity: "warning", kind: "alarm.device").isDefault)
        XCTAssertEqual(settings.fileFor(severity: "critical", kind: "alarm.solar"), "armor_siren_1a2b.wav")
    }

    func testChoosingTheDefaultAgainTakesTheChoiceAway() {
        let settings = SoundSettings().withSeverity("high", siren).withSeverity("high", SoundChoice())
        XCTAssertTrue(settings.bySeverity.isEmpty)
    }

    func testASeverityOrKindThatIsNotKnownIsNotKept() {
        let settings = SoundSettings().withSeverity("mystery", siren).withKind("mystery", siren)
        XCTAssertTrue(settings.bySeverity.isEmpty && settings.byKind.isEmpty)
    }

    func testAChoiceWhoseFileIsNotOneOfOursIsNotKept() {
        let evil = SoundChoice(kind: SoundChoice.own, file: "../../etc/passwd.wav", name: "x")
        XCTAssertTrue(SoundSettings().withSeverity("high", evil).bySeverity.isEmpty)
    }

    func testTheChoicesSurviveBeingWrittenAndRead() {
        let settings = SoundSettings().withSeverity("critical", siren).withSeverity("warning", beep).withKind("camera", beep)
        XCTAssertEqual(SoundSettings.decode(settings.encode()), settings)
    }

    func testATabOrALineBreakInTheNameCannotBreakTheStore() {
        let settings = SoundSettings().withSeverity("high", SoundChoice(kind: SoundChoice.own, file: "armor_a_1.wav", name: "bad\tname\nline"))
        XCTAssertEqual(SoundSettings.decode(settings.encode()).bySeverity["high"]?.name, "bad name line")
    }

    func testDamagedTextIsTheDefault() {
        XCTAssertEqual(SoundSettings.decode(nil), SoundSettings())
        XCTAssertEqual(SoundSettings.decode("   "), SoundSettings())
        XCTAssertEqual(SoundSettings.decode("S\tcritical\town"), SoundSettings())                                  // too few fields
        XCTAssertEqual(SoundSettings.decode("S\tcritical\town\t\tname"), SoundSettings())                          // no file
        XCTAssertEqual(SoundSettings.decode("S\tcritical\tdefault\tarmor_x_1.wav\tn"), SoundSettings())            // the default carries nothing
        XCTAssertEqual(SoundSettings.decode("S\tmystery\town\tarmor_x_1.wav\tn"), SoundSettings())                 // a severity that is not known
        XCTAssertEqual(SoundSettings.decode("K\tmystery\town\tarmor_x_1.wav\tn"), SoundSettings())                 // a kind that is not known
        XCTAssertEqual(SoundSettings.decode("S\tcritical\town\t/private/x.wav\tn"), SoundSettings())               // a path, not one of our files
    }

    func testApplyingAChoiceGoesToTheSeverityOrToTheKind() {
        XCTAssertEqual(SoundSettings().applying(siren, key: "high", isKind: false).bySeverity["high"], siren)
        XCTAssertEqual(SoundSettings().applying(siren, key: "camera", isKind: true).byKind["camera"], siren)
        XCTAssertNil(SoundSettings().applying(siren, key: "camera", isKind: true).bySeverity["camera"])
        XCTAssertTrue(SoundSettings().applying(siren, key: "high", isKind: false).byKind.isEmpty)
    }

    func testOnlyASoundIOSPlaysForANotificationIsAccepted() {
        XCTAssertTrue(OwnSound.accepts(fileName: "siren.wav", bytes: 200_000, seconds: 4))
        XCTAssertTrue(OwnSound.accepts(fileName: "SIREN.CAF", bytes: 200_000, seconds: 30))
        XCTAssertTrue(OwnSound.accepts(fileName: "a.aiff", bytes: OwnSound.maxBytes, seconds: 1))
        XCTAssertFalse(OwnSound.accepts(fileName: "song.mp3", bytes: 200_000, seconds: 4))          // not a container iOS plays for a notification
        XCTAssertFalse(OwnSound.accepts(fileName: "siren.wav", bytes: OwnSound.maxBytes + 1, seconds: 4))
        XCTAssertFalse(OwnSound.accepts(fileName: "siren.wav", bytes: 0, seconds: 4))
        XCTAssertFalse(OwnSound.accepts(fileName: "siren.wav", bytes: 1000, seconds: 31))           // iOS would play the default sound instead
        XCTAssertFalse(OwnSound.accepts(fileName: "siren.wav", bytes: 1000, seconds: 0))
        XCTAssertFalse(OwnSound.accepts(fileName: "siren.wav", bytes: 1000, seconds: nil))          // a file that cannot be measured is not a sound
        XCTAssertFalse(OwnSound.accepts(fileName: "siren", bytes: 1000, seconds: 3))
    }

    func testTheNameOfAKeptFileIsSafeAndTellsTwoFilesApart() {
        let a = OwnSound.storedName(fileName: "../My Siren (1).WAV", content: Data([1, 2, 3]))
        let b = OwnSound.storedName(fileName: "../My Siren (1).WAV", content: Data([1, 2, 4]))
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(OwnSound.isStoredName(a))
        XCTAssertTrue(a.hasPrefix("armor_") && a.hasSuffix(".wav"))
        XCTAssertFalse(a.contains("/") || a.contains(" ") || a.contains(".."))
        XCTAssertEqual(a, OwnSound.storedName(fileName: "../My Siren (1).WAV", content: Data([1, 2, 3])))
        XCTAssertTrue(OwnSound.storedName(fileName: "ñandú.caf", content: Data()).hasPrefix("armor_"))
    }

    func testOnlyNamesThatTheAppMakesAreStoredNames() {
        XCTAssertFalse(OwnSound.isStoredName("siren.wav"))
        XCTAssertFalse(OwnSound.isStoredName("armor_x/../y.wav"))
        XCTAssertFalse(OwnSound.isStoredName("armor_x.mp3"))
        XCTAssertFalse(OwnSound.isStoredName(""))
    }

    func testTheSoundsLiveInTheStoreOfThePreferences() {
        let store = MemoryStore()
        XCTAssertEqual(SoundPreferences.load(store), SoundSettings())
        let settings = SoundSettings().withKind("node", siren)
        SoundPreferences.save(store, settings)
        XCTAssertEqual(SoundPreferences.load(store), settings)
    }
}
