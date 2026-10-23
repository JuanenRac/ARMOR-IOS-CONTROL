import XCTest
@testable import ArmorCore

final class TranslatorTests: XCTestCase {
    func testPickPrefersSavedThenPhoneThenEnglish() {
        XCTAssertEqual(Translator.pick(saved: "de", phone: "fr"), "de")
        XCTAssertEqual(Translator.pick(saved: nil, phone: "fr"), "fr")
        XCTAssertEqual(Translator.pick(saved: "xx", phone: "ja"), "ja")
        XCTAssertEqual(Translator.pick(saved: nil, phone: "ru"), "en")
    }
    func testThereAreEightLanguagesIncludingPortuguese() {
        XCTAssertEqual(Translator.languages.map(\.code), ["en", "es", "de", "fr", "it", "ja", "zh", "pt"])
    }
    func testAMissingPhraseShowsInSpanish() {
        let t = Translator(language: "de", loader: { _ in ["Hola": "Hallo"] })
        XCTAssertEqual(t.tr("Hola"), "Hallo")
        XCTAssertEqual(t.tr("Adiós"), "Adiós")
    }
    func testFillsHolesInOrder() {
        let t = Translator(language: "en", loader: { _ in ["%s: %s objetivos": "%s: %s targets"] })
        XCTAssertEqual(t.trf("%s: %s objetivos", "radar-1", 3), "radar-1: 3 targets")
        XCTAssertEqual(Translator.fill("100%% de %d", [5]), "100% de 5")
        XCTAssertEqual(Translator.fill("%2$s / %1$s", ["a", "b"]), "b / a")
        XCTAssertEqual(Translator.fill("sin hueco % y fin %", [1]), "sin hueco % y fin %")
    }
    func testUnknownLanguageBecomesEnglish() {
        XCTAssertEqual(Translator(language: "klingon", loader: { _ in [:] }).language, "en")
    }
    func testBundledTablesHaveTheSameKeysInEveryLanguage() throws {
        let english = try XCTUnwrap(Translator.bundled("en"))
        XCTAssertFalse(english.isEmpty)
        for code in ["de", "fr", "it", "ja", "zh", "pt"] {
            let table = try XCTUnwrap(Translator.bundled(code), code)
            XCTAssertEqual(Set(table.keys), Set(english.keys), code)
            XCTAssertFalse(table.values.contains { $0.isEmpty }, code)
        }
    }
    func testHolesSurviveTranslation() throws {
        let english = try XCTUnwrap(Translator.bundled("en"))
        func holes(_ text: String) -> Int {
            var count = 0
            var rest = Substring(text)
            while let at = rest.firstIndex(of: "%") {
                rest = rest[rest.index(after: at)...]
                if let next = rest.first, next == "s" || next == "d" { count += 1 }
                else if let dollar = rest.firstIndex(of: "$"), rest[rest.startIndex..<dollar].allSatisfy(\.isNumber), !rest[rest.startIndex..<dollar].isEmpty { count += 1 }
            }
            return count
        }
        for code in ["de", "fr", "it", "ja", "zh", "pt"] {
            let table = try XCTUnwrap(Translator.bundled(code), code)
            for (phrase, translated) in table { XCTAssertEqual(holes(phrase), holes(translated), "\(code): \(phrase)") }
        }
        XCTAssertNotNil(english)
    }
}
