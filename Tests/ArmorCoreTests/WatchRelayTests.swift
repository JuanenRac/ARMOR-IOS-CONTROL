import Foundation
import XCTest
@testable import ArmorCore

/// The messages for the Apple Watch (the contract of ARMOR-WATCH) and what the phone does with the confirmation of the watch, tried with the clock of the test and no watch.
final class WatchRelayTests: XCTestCase {
    private func notice(id: Int = 7, severity: String = "high", alarm: String? = "al-1", title: String = "Intrusion", text: String = "Radar 1 saw movement") -> AlarmNotice {
        AlarmNotice(id: id, title: title, text: text, severity: severity, alarmId: alarm)
    }
    private func object(_ text: String?) -> [String: Any] { try! JSONSerialization.jsonObject(with: Data(text!.utf8)) as! [String: Any] }

    func testAnAlertCarriesTheFieldsOfTheContract() {
        let json = object(WatchRelay.alertMessage(notice()))
        XCTAssertEqual(json["type"] as? String, "alert")
        XCTAssertEqual(json["protocolVersion"] as? Int, 1)
        XCTAssertEqual(json["alertId"] as? String, "al-1")
        XCTAssertEqual(json["severity"] as? String, "warning")
        XCTAssertEqual(json["title"] as? String, "Intrusion")
        XCTAssertEqual(json["needsAck"] as? Bool, true)
        XCTAssertEqual(json["ttlSeconds"] as? Int, 120)
        XCTAssertEqual(json.count, 8)
    }

    func testTheSeverityOfThePhoneBecomesOneOfTheWatch() {
        XCTAssertEqual(WatchRelay.severity(of: "critical"), "critical")
        XCTAssertEqual(WatchRelay.severity(of: "high"), "warning")
        XCTAssertEqual(WatchRelay.severity(of: "warning"), "info")
        XCTAssertEqual(WatchRelay.severity(of: "anything else"), "info")
        XCTAssertEqual(object(WatchRelay.alertMessage(notice(severity: "critical")))["ttlSeconds"] as? Int, 600)
    }

    func testTheTextsAreCutToTheLimitsAndAnEmptyOneIsNotSent() {
        let long = object(WatchRelay.alertMessage(notice(title: String(repeating: "T", count: 100), text: String(repeating: "X", count: 500))))
        XCTAssertEqual((long["title"] as? String)?.count, WatchRelay.titleMax)
        XCTAssertEqual((long["text"] as? String)?.count, WatchRelay.textMax)
        XCTAssertNil(WatchRelay.alertMessage(notice(title: "  ")))
        XCTAssertNil(WatchRelay.alertMessage(notice(text: "")))
    }

    func testANoticeWithoutAnAlarmAsksForNoConfirmation() {
        let json = object(WatchRelay.alertMessage(notice(id: 41, alarm: nil)))
        XCTAssertEqual(json["needsAck"] as? Bool, false)
        XCTAssertEqual(json["alertId"] as? String, "n41")
        XCTAssertEqual(WatchRelay.alertId(of: notice(id: -3, alarm: "not valid!")), "n0")
    }

    func testTheRelayAndClearMessagesAreTheOnesOfTheContract() {
        let relay = object(WatchRelay.relayMessage(true))
        XCTAssertEqual(relay["type"] as? String, "relay")
        XCTAssertEqual(relay["enabled"] as? Bool, true)
        XCTAssertEqual(object(WatchRelay.relayMessage(false))["enabled"] as? Bool, false)
        let clear = object(WatchRelay.clearMessage("al-1"))
        XCTAssertEqual(clear["type"] as? String, "alert_clear")
        XCTAssertEqual(clear["alertId"] as? String, "al-1")
    }

    func testNothingIsSentWhileTheOptionIsOffAndTheRelaySwitchGoesBeforeTheAlert() {
        XCTAssertTrue(WatchRelay.messages(for: notice(), enabled: false).isEmpty)
        let sent = WatchRelay.messages(for: notice(), enabled: true)
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(object(sent[0])["type"] as? String, "relay")
        XCTAssertEqual(object(sent[1])["type"] as? String, "alert")
        XCTAssertTrue(WatchRelay.messages(for: notice(title: ""), enabled: true).isEmpty)
    }

    func testOnlyAStrictConfirmationIsRead() {
        XCTAssertEqual(WatchRelay.parseAck(#"{"type":"alert_ack","protocolVersion":1,"alertId":"al-1"}"#), "al-1")
        XCTAssertNil(WatchRelay.parseAck(#"{"type":"alert_ack","protocolVersion":2,"alertId":"al-1"}"#))
        XCTAssertNil(WatchRelay.parseAck(#"{"type":"alert","protocolVersion":1,"alertId":"al-1"}"#))
        XCTAssertNil(WatchRelay.parseAck(#"{"type":"alert_ack","protocolVersion":1,"alertId":"bad id"}"#))
        XCTAssertNil(WatchRelay.parseAck(#"{"type":"alert_ack","protocolVersion":1}"#))
        XCTAssertNil(WatchRelay.parseAck("not json"))
        XCTAssertNil(WatchRelay.parseAck(String(repeating: "x", count: 600)))
    }

    func testTheConfirmationIsActedOnlyForAnAlertTheWatchWasGivenAndOnlyOnce() {
        WatchRelay.sent.remember(alertId: "al-9", alarmId: "alarm-9", ttlSeconds: 60)
        let ack = #"{"type":"alert_ack","protocolVersion":1,"alertId":"al-9"}"#
        XCTAssertNil(WatchRelay.alarmToAcknowledge(enabled: false, text: ack))   // the option is off: the entry is not even looked at
        let found = WatchRelay.alarmToAcknowledge(enabled: true, text: ack)
        XCTAssertEqual(found?.alarmId, "alarm-9")
        XCTAssertNil(WatchRelay.alarmToAcknowledge(enabled: true, text: ack))   // used up
        XCTAssertNil(WatchRelay.alarmToAcknowledge(enabled: true, text: #"{"type":"alert_ack","protocolVersion":1,"alertId":"never-sent"}"#))
    }

    func testAnAlertThatExpiredCannotBeConfirmedAndTheTableIsBounded() {
        var clock: Int64 = 100
        let table = SentAlerts { clock }
        table.remember(alertId: "a", alarmId: "alarm-a", ttlSeconds: 10)
        clock += 10
        XCTAssertNil(table.take("a"))
        for index in 1...(SentAlerts.capacity + 5) { table.remember(alertId: "id\(index)", alarmId: "alarm\(index)", ttlSeconds: 600) }
        XCTAssertNil(table.take("id1"))
        XCTAssertEqual(table.take("id\(SentAlerts.capacity + 5)"), "alarm\(SentAlerts.capacity + 5)")
    }

    func testTheOptionIsOffByDefaultAndKept() {
        let store = MemoryStore()
        XCTAssertFalse(WatchRelay.enabled(store))
        WatchRelay.setEnabled(store, true)
        XCTAssertTrue(WatchRelay.enabled(store))
        WatchRelay.setEnabled(store, false)
        XCTAssertFalse(WatchRelay.enabled(store))
    }

    // The contract of the watch (docs/watch_alert_contract.json) is one file kept identically in ARMOR-WATCH, here and in the Android app: the phone's side is held to its limits and examples.
    private func contract() throws -> [String: Any] {
        var folder = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { folder.deleteLastPathComponent(); if FileManager.default.fileExists(atPath: folder.appendingPathComponent("docs/watch_alert_contract.json").path) { break } }
        let data = try Data(contentsOf: folder.appendingPathComponent("docs/watch_alert_contract.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func expanded(_ value: Any) -> Any {
        if let box = value as? [String: Any], box.count == 2, let text = box["repeat"] as? String, let count = box["count"] as? Int { return String(repeating: text, count: count) }
        return value
    }

    func testTheLimitsAndThePathsOfTheContractAreTheOnesThisAppUses() throws {
        let contract = try contract()
        let limits = try XCTUnwrap(contract["limits"] as? [String: Any])
        XCTAssertEqual(limits["titleMax"] as? Int, WatchRelay.titleMax)
        XCTAssertEqual(limits["textMax"] as? Int, WatchRelay.textMax)
        XCTAssertEqual(contract["protocolVersion"] as? Int, WatchRelay.protocolVersion)
        let paths = try XCTUnwrap(contract["paths"] as? [String: String])
        XCTAssertEqual(paths["toWatch"], WatchRelay.pathToWatch)
        XCTAssertEqual(paths["toPhone"], WatchRelay.pathToPhone)
        let pattern = try XCTUnwrap(limits["alertIdPattern"] as? String)
        for id in ["a", "al-001", "n_2", String(repeating: "a", count: 64), "", "a b", String(repeating: "a", count: 65), "a/b"] {
            XCTAssertEqual(id.range(of: pattern, options: .regularExpression) != nil, WatchRelay.validId(id), id)
        }
    }

    func testTheConfirmationsOfTheContractAreReadAndTheWrongOnesAreRefused() throws {
        let contract = try contract()
        for example in try XCTUnwrap(contract["valid"] as? [[String: Any]]) where example["type"] as? String == "alert_ack" {
            let text = String(decoding: try JSONSerialization.data(withJSONObject: example), as: UTF8.self)
            XCTAssertEqual(WatchRelay.parseAck(text), example["alertId"] as? String)
        }
        for var example in try XCTUnwrap(contract["invalid"] as? [[String: Any]]) {
            let why = example.removeValue(forKey: "why") as? String ?? ""
            for (key, value) in example { example[key] = expanded(value) }
            guard example["type"] as? String == "alert_ack" else { continue }
            let text = String(decoding: try JSONSerialization.data(withJSONObject: example), as: UTF8.self)
            XCTAssertNil(WatchRelay.parseAck(text), why)
        }
    }

    func testTheMessagesThePhoneWritesCarryTheTypesOfTheContract() throws {
        let valid = try XCTUnwrap(try contract()["valid"] as? [[String: Any]])
        let relays = Set(valid.filter { $0["type"] as? String == "relay" }.compactMap { $0["enabled"] as? Bool })
        XCTAssertEqual(relays, [true, false])
        for on in relays {
            let written = object(WatchRelay.relayMessage(on))
            XCTAssertEqual(written["type"] as? String, "relay")
            XCTAssertEqual(written["enabled"] as? Bool, on)
        }
        XCTAssertEqual(object(WatchRelay.clearMessage("al-001"))["type"] as? String, "alert_clear")
    }
}
