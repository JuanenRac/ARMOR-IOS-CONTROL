import XCTest
@testable import ArmorCore

final class AssistantSuggestionsTests: XCTestCase {
    func testTheChipsAreFifteenDifferentPhrasesStartingWithTheState() {
        let phrases = AssistantSuggestions.phrases(plain("es"))
        XCTAssertEqual(phrases.count, 15)
        XCTAssertEqual(Set(phrases).count, 15)
        XCTAssertEqual(phrases.first, "Estado del sistema")
        XCTAssertEqual(phrases.last, "Ayuda")
    }
}
