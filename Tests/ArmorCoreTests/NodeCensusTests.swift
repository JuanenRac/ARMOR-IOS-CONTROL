// ARMOR-IOS-CONTROL - the count of the nodes of every kind: the radar stream and the health every node reports, together (the same cases as the Android app).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import XCTest
@testable import ArmorCore

final class NodeCensusTests: XCTestCase {
    private func radar(_ id: String, online: Bool, stale: Bool = false) -> FieldNode {
        FieldNode(id: id, online: online, lux: nil, targetCount: 0, alertLevel: "none", stale: stale)
    }

    private func health(_ nodes: [(String, String, Bool)]) throws -> NodeHealthOverview {
        let items = nodes.map { id, family, stale in
            """
            {"node_id":"\(id)","family":"\(family)","firmware":"1.0.0","received_at":"2026-01-01T10:00:00.000Z","stale":\(stale),"status":"\(stale ? "stale" : "ok")","warnings":[],"restarts_24h":0,
             "report":{"node_id":"\(id)","uptime_s":10,"reset_reason":"power_on","heap_free":100000,"heap_min":90000,"link":"wifi","link_up":true,"broker_reconnects":0}}
            """
        }.joined(separator: ",")
        let text = "{\"nodes\":[\(items)],\"waiting\":[],\"totals\":{\"nodes\":\(nodes.count),\"stale\":0,\"with_warnings\":0}}"
        return NodeHealthParser.overview(try Json.object(Data(text.utf8)))
    }

    func testOnlyTheRadarNodesWhenTheHealthIsNotKnownYet() {
        let census = NodeCensus.of(radar: [radar("r1", online: true), radar("r2", online: false)], health: nil)
        XCTAssertEqual(census.online, 1)
        XCTAssertEqual(census.total, 2)
        XCTAssertEqual(census.families.map { $0.family }, ["radar"])
        XCTAssertEqual(census.silent.map { $0.id }, ["r2"])
    }

    func testEveryKindOfNodeThatReportsItsHealthIsCounted() throws {
        let census = NodeCensus.of(
            radar: [radar("r1", online: true)],
            health: try health([("r1", "radar", false), ("s1", "solar", false), ("e1", "electrical", false), ("a1", "alarm", false), ("h1", "hmi", true)]))
        XCTAssertEqual(census.online, 4)
        XCTAssertEqual(census.total, 5)
        XCTAssertEqual(census.families.map { $0.family }, ["radar", "solar", "electrical", "alarm", "hmi"])
        XCTAssertEqual(census.silent.map { $0.id }, ["h1"])
    }

    func testANodeInBothListsIsCountedOnceAndIsOnlineWhenEitherSaysSo() throws {
        XCTAssertEqual(NodeCensus.of(radar: [radar("r1", online: false)], health: try health([("r1", "radar", false)])).online, 1)
        XCTAssertEqual(NodeCensus.of(radar: [radar("r1", online: true)], health: try health([("r1", "radar", true)])).online, 1)
        XCTAssertEqual(NodeCensus.of(radar: [radar("r1", online: true)], health: try health([("r1", "radar", true)])).total, 1)
    }

    func testAStaleRadarNodeIsNotOnline() {
        let census = NodeCensus.of(radar: [radar("r1", online: true, stale: true)], health: nil)
        XCTAssertEqual(census.online, 0)
    }

    func testNothingIsCountedWithNothing() {
        let census = NodeCensus.of(radar: [], health: nil)
        XCTAssertEqual(census.total, 0)
        XCTAssertTrue(census.families.isEmpty)
    }

    func testTheWordsOfTheCountAreInEveryLanguage() {
        for language in ["en", "es", "de", "fr", "it", "ja", "zh", "pt"] {
            let translator = Translator(language: language)
            for phrase in ["Nodos en línea", "Nodos por tipo"] {
                XCTAssertFalse(translator.tr(phrase).isEmpty, "\(language) \(phrase)")
                if language != "es" { XCTAssertNotEqual(translator.tr(phrase), phrase, "\(language) \(phrase) is not translated") }
            }
        }
    }
}
