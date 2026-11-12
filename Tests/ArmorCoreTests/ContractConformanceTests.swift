import Foundation
import XCTest
@testable import ArmorCore

/// The readers and writers of the messages that ARMOR-COMMON generates (`Contract`), against the vectors of the shared contracts: `conformance/wire_cases.tsv` and
/// `conformance/wire_full_cases.tsv`, one case per line (schema, 1 or 0, the document) with the verdict of the Python validator.
final class ContractConformanceTests: XCTestCase {
    private struct Case {
        let file: String
        let number: Int
        let schema: String
        let valid: Bool
        let text: String
        var label: String { "\(file):\(number) \(schema)" }
    }

    private static let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let common = repository.deletingLastPathComponent().appendingPathComponent("ARMOR-COMMON")

    private func requireCommon() throws {
        var isFolder: ObjCBool = false
        if FileManager.default.fileExists(atPath: Self.common.path, isDirectory: &isFolder), isFolder.boolValue { return }
        let required = ProcessInfo.processInfo.environment["ARMOR_REQUIRE_SIBLINGS"] ?? ""
        XCTAssertTrue(required.isEmpty, "ARMOR-COMMON must be next to this repository when ARMOR_REQUIRE_SIBLINGS is set")
        throw XCTSkip("ARMOR-COMMON is not next to this repository")
    }

    private func cases(_ name: String) throws -> [Case] {
        try requireCommon()
        let url = Self.common.appendingPathComponent("conformance").appendingPathComponent(name)
        let content = try String(contentsOf: url, encoding: .utf8)
        var found: [Case] = []
        for (index, raw) in content.components(separatedBy: "\n").enumerated() {
            let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
            if line.isEmpty { continue }
            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            XCTAssertEqual(parts.count, 3, "\(name):\(index + 1)")
            if parts.count == 3 { found.append(Case(file: name, number: index + 1, schema: String(parts[0]), valid: parts[1] == "1", text: String(parts[2]))) }
        }
        return found
    }

    private func allCases() throws -> [Case] { try cases("wire_cases.tsv") + cases("wire_full_cases.tsv") }

    /// The document of a case as `JSONSerialization` reads it, or nil when it cannot be read as JSON at all.
    private func document(_ item: Case) -> Any? {
        try? JSONSerialization.jsonObject(with: Data(item.text.utf8), options: [.fragmentsAllowed])
    }

    /// The document without the members its schema does not name (what a reader keeps).
    private func knownOnly(_ value: Any, _ schema: [String: Any]) -> Any {
        if let object = value as? [String: Any] {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            let extra = schema["additionalProperties"] as? [String: Any]
            var out: [String: Any] = [:]
            for (name, child) in object {
                if let rule = properties[name] as? [String: Any] {
                    out[name] = knownOnly(child, rule)
                } else if let rule = extra {
                    out[name] = knownOnly(child, rule)
                }
            }
            return out
        }
        if let list = value as? [Any], let items = schema["items"] as? [String: Any] { return list.map { knownOnly($0, items) } }
        return value
    }

    private func sameValue(_ left: Any, _ right: Any) -> Bool {
        if let a = left as? [String: Any], let b = right as? [String: Any] {
            return Set(a.keys) == Set(b.keys) && a.allSatisfy { entry in b[entry.key].map { sameValue(entry.value, $0) } ?? false }
        }
        if let a = left as? [Any], let b = right as? [Any] {
            return a.count == b.count && zip(a, b).allSatisfy { sameValue($0, $1) }
        }
        if Contract.isBool(left) || Contract.isBool(right) { return Contract.isBool(left) && Contract.isBool(right) && Contract.asFlag(left) == Contract.asFlag(right) }
        if let a = Contract.numberOf(left), let b = Contract.numberOf(right) { return abs(a - b) <= 1e-12 * max(1, abs(a), abs(b)) }
        if let a = left as? String, let b = right as? String { return a == b }
        return false
    }

    private func text(_ value: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self)
    }

    func testTheCopyInTheAppIsWhatArmorCommonGeneratesNow() throws {
        try requireCommon()
        let generated = Self.common.appendingPathComponent("generated").appendingPathComponent("ArmorContract.swift")
        let copy = Self.repository.appendingPathComponent("Sources/ArmorCore/Contract/ArmorContract.swift")
        let wanted = try String(contentsOf: generated, encoding: .utf8).replacingOccurrences(of: "\r\n", with: "\n")
        let have = try String(contentsOf: copy, encoding: .utf8).replacingOccurrences(of: "\r\n", with: "\n")
        XCTAssertTrue(wanted == have, "Sources/ArmorCore/Contract/ArmorContract.swift is not what ARMOR-COMMON generates: copy generated/ArmorContract.swift")
    }

    func testTheOracleHasBothVerdictsForEveryMessageItHasCasesOf() throws {
        let all = try allCases()
        XCTAssertGreaterThan(all.count, 1000)
        let covered = Set(all.map { $0.schema })
        XCTAssertGreaterThan(covered.count, Contract.messageNames.count - 4, "most messages must have cases")
        for name in covered {
            XCTAssertTrue(Contract.messageNames.contains(name), "a case of \(name), which the readers do not know")
            XCTAssertTrue(all.contains { $0.schema == name && $0.valid }, "no valid case of \(name)")
            XCTAssertTrue(all.contains { $0.schema == name && !$0.valid }, "no invalid case of \(name)")
        }
    }

    func testTheReadersSayWhatThePythonValidatorSaysOnEverySeededCase() throws {
        var disagreements: [String] = []
        var unreadable = 0
        for item in try allCases() {
            guard let value = document(item) else {
                // a text that is not JSON for the Foundation parser (a lone surrogate, say) cannot be a valid message
                unreadable += 1
                if item.valid { disagreements.append("\(item.label) cannot be read as JSON") }
                continue
            }
            if (Contract.check(item.schema, value) == nil) != item.valid { disagreements.append(item.label) }
        }
        XCTAssertEqual(Array(disagreements.prefix(30)), [])
        XCTAssertLessThan(unreadable, 20, "the Foundation parser refused too many documents")
    }

    func testAValidCaseBecomesItsStructAndAnInvalidOneBecomesNothing() throws {
        var wrong: [String] = []
        for item in try allCases() {
            guard let object = document(item) as? [String: Any] else { continue }
            let parsed = Contract.parse(item.schema, object)
            if (parsed != nil) != item.valid { wrong.append(item.label) }
        }
        XCTAssertEqual(Array(wrong.prefix(30)), [])
        XCTAssertNil(Contract.parse("not_a_message", [:]))
        XCTAssertNil(Contract.rewrite("not_a_message", [:]))
    }

    func testAValidCaseIsWrittenBackWithTheMembersTheSchemaNamesAndSeenAgainItIsTheSame() throws {
        var different: [String] = []
        var unstable: [String] = []
        var invalidAfter: [String] = []
        var checked = 0
        for item in try allCases() where item.valid {
            guard let object = document(item) as? [String: Any], let schema = Contract.schemas[item.schema] else {
                different.append("\(item.label) cannot be read")
                continue
            }
            guard let written = Contract.rewrite(item.schema, object) else {
                different.append("\(item.label) has no rewrite")
                continue
            }
            checked += 1
            if !sameValue(written, knownOnly(object, schema)) { different.append(item.label) }
            if Contract.check(item.schema, written) != nil { invalidAfter.append(item.label) }
            guard let again = Contract.rewrite(item.schema, written) else {
                unstable.append("\(item.label) is not read again")
                continue
            }
            if try text(again) != text(written) { unstable.append(item.label) }
        }
        XCTAssertEqual(Array(different.prefix(30)), [])
        XCTAssertEqual(Array(invalidAfter.prefix(30)), [])
        XCTAssertEqual(Array(unstable.prefix(30)), [])
        XCTAssertGreaterThan(checked, 500)
    }

    func testTheStructHoldsWhatTheDocumentSaid() throws {
        let all = try allCases()
        let telemetry = try XCTUnwrap(all.first { $0.valid && $0.schema == "telemetry" })
        let object = try XCTUnwrap(document(telemetry) as? [String: Any])
        let message = try XCTUnwrap(Contract.parseTelemetry(object))
        XCTAssertEqual(message.node_id, object["node_id"] as? String)
        XCTAssertEqual(message.targets.count, (object["targets"] as? [Any])?.count)
        let alarm = try XCTUnwrap(all.first { $0.valid && $0.schema == "alarm" })
        let state = try XCTUnwrap(document(alarm) as? [String: Any])
        let parsed = try XCTUnwrap(Contract.parseAlarm(state))
        XCTAssertEqual(parsed.phase, state["phase"] as? String)
        XCTAssertEqual(parsed.zones.count, (state["zones"] as? [Any])?.count)
        let rebuilt = try XCTUnwrap(Contract.parse("alarm", state) as? Contract.Alarm)
        XCTAssertEqual(rebuilt.node_id, parsed.node_id)
    }

    func testAnUnknownNameAndAMissingMemberAreSaidWithTheirPath() {
        XCTAssertEqual(Contract.check("not_a_message", [:] as [String: Any])?.detail, "unknown message not_a_message")
        let error = Contract.check("telemetry", [:] as [String: Any])
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.path.hasPrefix("/") ?? false)
        XCTAssertEqual(error?.detail, "is required")
        XCTAssertEqual(Contract.check("telemetry", 3)?.detail, "must be of type object")
    }

    func testABooleanIsNotANumberAndANumberIsNotABoolean() throws {
        XCTAssertTrue(Contract.isBool(true as Any))
        XCTAssertFalse(Contract.isBool(1 as Any))
        XCTAssertNil(Contract.numberOf(true as Any))
        XCTAssertEqual(Contract.numberOf(2.5 as Any), 2.5)
        let flags = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(#"{"a":true,"b":1,"c":1.5}"#.utf8)) as? [String: Any])
        XCTAssertTrue(Contract.isBool(try XCTUnwrap(flags["a"])))
        XCTAssertFalse(Contract.isBool(try XCTUnwrap(flags["b"])))
        XCTAssertFalse(Contract.isBool(try XCTUnwrap(flags["c"])))
    }
}
