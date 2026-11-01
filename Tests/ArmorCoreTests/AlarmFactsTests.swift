import XCTest
@testable import ArmorCore

final class AlarmFactsTests: XCTestCase {
    private let languages = ["en", "es", "de", "fr", "it", "ja", "zh", "pt"]

    private func alarm(_ detail: Any) -> Alarm {
        let json: JSON = ["id": "a1", "source": ["type": "alarm", "id": "mode_panel"], "severity": "high", "code": "mode_panel_sync_failed", "raised_at": "2026-01-01T00:00:00Z", "detail": detail]
        return Alarm.parse(json)!
    }

    func testEveryFactHasItsLabelInTheEightLanguages() {
        let table = AlarmFacts.shared
        XCTAssertGreaterThanOrEqual(table.count, 50)
        for (key, labels) in table {
            for language in languages { XCTAssertFalse((labels[language] ?? "").isEmpty, "\(key) in \(language)") }
        }
    }

    func testTheHelpOfEveryAlarmCodeIsInTheSharedTableInTheEightLanguages() {
        let help = AlarmFacts.sharedHelp
        XCTAssertGreaterThanOrEqual(help.count, 59)
        for code in ["smoke", "co", "gas", "water_leak", "panic", "intrusion", "door_open", "duress_disarm", "network_internet_down", "alarm_offline", "node_down", "mode_panel_sync_failed"] {
            guard let words = help[code] else { XCTFail("\(code) has no help"); continue }
            for language in ["en", "es", "de", "fr", "it", "ja", "zh", "pt"] { XCTAssertEqual(words[language]?.split(separator: "\n", omittingEmptySubsequences: false).count, 2, "\(code) in \(language)") }
        }
        for (code, words) in help {
            for language in languages { XCTAssertFalse((words[language] ?? "").isEmpty, "\(code) in \(language)") }
        }
    }

    func testTheHelpComesInTheLanguageAskedEnglishWhenItLacksItAndNilWhenTheCodeHasNone() {
        let table = ["solar_battery_low": ["en": "Means: low", "pt": "Significa: baixa"], "smoke": ["es": "Humo"]]
        XCTAssertEqual(AlarmFacts.help("solar_battery_low", "pt", table: table), "Significa: baixa")
        XCTAssertEqual(AlarmFacts.help("solar_battery_low", "de", table: table), "Means: low")
        XCTAssertNil(AlarmFacts.help("smoke", "de", table: table))
        XCTAssertNil(AlarmFacts.help("no_such_code", "en", table: table))
    }

    func testTheMarkOfAFalseAlarmIsReadAndAnAlarmNobodyMarkedHasNone() {
        func parse(_ extra: JSON) -> Alarm {
            var json: JSON = ["id": "a1", "source": ["type": "device", "id": "d1"], "severity": "high", "code": "door_open", "raised_at": "2026-01-01T00:00:00Z"]
            for (key, value) in extra { json[key] = value }
            return Alarm.parse(json)!
        }
        XCTAssertEqual(parse(["false_alarm": true]).falseAlarm, true)
        XCTAssertEqual(parse(["false_alarm": false]).falseAlarm, false)
        XCTAssertNil(parse([:]).falseAlarm)
    }

    func testTheFactsOfAPanelThatDoesNotConfirmTheArmingModeComeWithTheirLabelsInOrder() {
        let a = alarm(["by": "voice", "panel_answers": "nodeA: timeout", "panels": "nodeA, nodeB", "panel_profile": "away", "arming_mode": "away"] as JSON)
        let rows = AlarmFacts.rows(a.detail, plain("pt"))
        XCTAssertEqual(rows.map { $0.key }, ["arming_mode", "panel_profile", "panels", "panel_answers", "by"])
        XCTAssertEqual(rows.map { $0.label }, ["Modo de armamento escolhido", "Perfil pedido às centrais", "Centrais que não confirmaram", "O que cada central respondeu", "Escolhido por"])
        XCTAssertEqual(rows.map { $0.value }, ["away", "away", "nodeA, nodeB", "nodeA: timeout", "voice"])
        XCTAssertTrue(rows.allSatisfy { $0.known })
        XCTAssertEqual(AlarmFacts.rows(a.detail, plain("es")).first?.label, "Modo de armado elegido")
    }

    func testALabelComesInTheLanguageAskedAndEnglishWhenThatLanguageLacksIt() {
        let table = ["ip": ["en": "Address (IP)", "de": "Adresse (IP)"]]
        XCTAssertEqual(AlarmFacts.label("ip", "de", table: table), "Adresse (IP)")
        XCTAssertEqual(AlarmFacts.label("ip", "ja", table: table), "Address (IP)")
        XCTAssertNil(AlarmFacts.label("not_a_fact", "en", table: table))
    }

    func testAFactTheTableDoesNotKnowIsShownAsItCameAndNoFactIsLost() {
        let a = alarm(["zzz_new": "x", "ip": "10.0.0.2", "list": [1, 2], "nested": ["a": 1], "nothing": NSNull(), "count": 3, "ratio": 2.5, "flag": true] as JSON)
        XCTAssertEqual(a.detail.count, 8)
        let rows = AlarmFacts.rows(a.detail, plain("en"))
        XCTAssertEqual(rows.count, 8)
        XCTAssertEqual(rows.first?.key, "ip")
        let unknown = rows.filter { !$0.known }
        XCTAssertEqual(Set(unknown.map { $0.key }), ["zzz_new", "list", "nested", "nothing", "count", "ratio", "flag"])
        XCTAssertTrue(unknown.allSatisfy { $0.label == $0.key })
        XCTAssertEqual(rows.first { $0.key == "list" }?.value, "[1,2]")
        XCTAssertEqual(rows.first { $0.key == "count" }?.value, "3")
        XCTAssertEqual(rows.first { $0.key == "ratio" }?.value, "2.5")
    }

    func testWithNoTableEveryFactIsStillListedWithItsKey() {
        let a = alarm(["device": "cam1", "port": 22] as JSON)
        let rows = AlarmFacts.rows(a.detail, plain("en"), table: [:])
        XCTAssertEqual(rows.map { $0.label }, ["device", "port"])
        XCTAssertEqual(rows.map { $0.value }, ["cam1", "22"])
        XCTAssertFalse(rows.contains { $0.known })
    }

    func testYesAndNoTheUnitsAndTheDatesAreToldAsAPersonReadsThem() {
        let en = Translator(language: "en", loader: { _ in ["sí": "yes", "no": "no"] })
        let utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(AlarmFacts.text("online", .flag(true), en), "yes")
        XCTAssertEqual(AlarmFacts.text("risky", .flag(false), en), "no")
        XCTAssertEqual(AlarmFacts.text("latency_ms", .whole(12), en), "12 ms")
        XCTAssertEqual(AlarmFacts.text("loss_percent", .whole(5), en), "5 %")
        XCTAssertEqual(AlarmFacts.text("since", .text("not a date"), en, timeZone: utc), "not a date")
        XCTAssertEqual(AlarmFacts.text("opened_at", .text("2026-01-01T10:00:00Z"), en, timeZone: utc), "01/01 10:00")
        XCTAssertEqual(AlarmFacts.text("first_seen", .text("2026-01-01T10:00:00.250Z"), en, timeZone: utc), "01/01 10:00")
    }

    func testAnAlarmWithoutDetailsHasAnEmptyListAndKeepsBeingAnAlarm() {
        let json: JSON = ["id": "a2", "source": ["type": "device", "id": "d1"], "severity": "critical", "code": "smoke", "raised_at": "x"]
        let a = Alarm.parse(json)
        XCTAssertNotNil(a)
        XCTAssertTrue(a!.detail.isEmpty)
        XCTAssertTrue(AlarmFacts.rows(a!.detail, plain("en")).isEmpty)
    }
}
