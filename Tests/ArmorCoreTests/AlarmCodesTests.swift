import XCTest
@testable import ArmorCore

final class AlarmCodesTests: XCTestCase {
    private let languages = ["en", "es", "de", "fr", "it", "ja", "zh", "pt"]

    func testTheTableHasEveryCodeInEightLanguagesAndTheOneAboutAStaleDnsName() {
        let table = AlarmCodes.shared
        XCTAssertGreaterThanOrEqual(table.count, 58)
        XCTAssertNotNil(table["network_dns_stale"])
        for (code, texts) in table {
            for language in languages { XCTAssertFalse((texts[language] ?? "").isEmpty, "\(code) in \(language)") }
        }
    }

    func testAnAlarmIsSaidInTheLanguageOfTheApp() {
        for language in languages {
            let t = plain(language)
            let said = AlarmText.text("network_dns_stale", t)
            XCTAssertEqual(said, AlarmCodes.shared["network_dns_stale"]?[language])
            XCTAssertNotEqual(said, "network_dns_stale")
        }
    }

    func testACodeNotInTheTableKeepsThePhrasesOfTheAppAndAnUnknownOneShowsAsItComes() {
        let t = plain("es")
        XCTAssertEqual(AlarmText.text("smoke", t, table: [:]), "Humo detectado")
        XCTAssertEqual(AlarmText.text("not_a_code", t), "not_a_code")
    }

    func testEveryCodeTheAppKnewIsInTheTable() {
        let missing = AlarmText.phrases.keys.filter { AlarmCodes.shared[$0] == nil }
        XCTAssertEqual(missing.sorted(), [])
    }
}
