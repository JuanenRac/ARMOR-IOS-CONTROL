import XCTest
@testable import ArmorCore

/// The health of the nodes: what GET /api/v1/node-health answers (the shape the server produces), its reading and its wording.
final class NodeHealthTests: XCTestCase {
    private let t = plain()
    private let answer = """
    {"nodes":[
      {"node_id":"radar-1","family":"radar","firmware":"0.6.9","board":"s3-wifi","received_at":"2026-01-01T10:00:00.000Z","stale":false,"status":"warning",
       "warnings":[{"code":"node_low_memory","detail":{"heap_free":12000}},{"code":"node_weak_signal","detail":{}}],"restarts_24h":3,
       "report":{"kind":"node_health","node_id":"radar-1","family":"radar","firmware":"0.6.9","board":"s3-wifi","uptime_s":93784,"reset_reason":"task_wdt","heap_free":12000,"heap_min":9000,
                 "link":"wifi","link_up":true,"rssi_dbm":-83,"broker_reconnects":4,"low_stack_tasks":1,"last_error":"armor-mqtt: the broker refused"}},
      {"node_id":"alarm-1","family":"alarm","firmware":"0.3.6","received_at":"2026-01-01T10:00:00.000Z","stale":false,"status":"ok","warnings":[],"restarts_24h":0,
       "report":{"node_id":"alarm-1","uptime_s":3600,"reset_reason":"power_on","heap_free":142000,"heap_min":98000,"link":"ethernet","link_up":true,"broker_reconnects":1}},
      {"node_id":"solar-1","family":"solar","firmware":"0.4.5","received_at":"2026-01-01T09:00:00.000Z","stale":true,"status":"stale","warnings":[],"restarts_24h":1,
       "report":{"uptime_s":60,"reset_reason":"software","heap_free":1500000,"heap_min":1200000,"link":"none","link_up":false,"broker_reconnects":0}},
      {"node_id":"","family":"hmi","report":{}},
      {"node_id":"no-report","family":"hmi"}
    ],
    "waiting":[{"node_id":"north-1","family":"radar"},{"node_id":"","family":"alarm"}],
    "totals":{"nodes":3,"stale":1,"with_warnings":1},
    "levels":{"low_heap_b":30000}}
    """

    private func loaded() throws -> NodeHealthOverview { NodeHealthParser.overview(try Json.object(Data(answer.utf8))) }

    func testTheOverviewIsReadWithItsNodesWarningsAndTotals() throws {
        let overview = try loaded()
        XCTAssertEqual(overview.nodes.count, 3)   // a node with no id and one with no report are left out
        XCTAssertEqual(overview.totals, NodeHealthTotals(nodes: 3, stale: 1, withWarnings: 1))
        XCTAssertEqual(overview.waiting.map { $0.nodeId }, ["north-1"])
        let radar = overview.nodes[0]
        XCTAssertTrue(radar.needsLook)
        XCTAssertFalse(radar.silent)
        XCTAssertEqual(radar.warnings, ["node_low_memory", "node_weak_signal"])
        XCTAssertEqual(radar.uptimeSeconds, 93784)
        XCTAssertEqual(radar.resetReason, "task_wdt")
        XCTAssertEqual(radar.heapFree, 12000)
        XCTAssertEqual(radar.heapMin, 9000)
        XCTAssertEqual(radar.rssiDbm, -83)
        XCTAssertEqual(radar.brokerConnections, 4)
        XCTAssertEqual(radar.lowStackTasks, 1)
        XCTAssertEqual(radar.board, "s3-wifi")
        XCTAssertEqual(radar.lastError, "armor-mqtt: the broker refused")
        XCTAssertEqual(radar.restarts24h, 3)
        let cable = overview.nodes[1]
        XCTAssertNil(cable.rssiDbm)
        XCTAssertNil(cable.lastError)
        XCTAssertNil(cable.board)
        XCTAssertFalse(cable.needsLook)
        XCTAssertTrue(overview.nodes[2].silent)
        XCTAssertTrue(NodeHealthParser.overview([:]).isEmpty)
    }

    func testTheWordingIsPlainSpanishAndNeverShowsACode() {
        for family in ["radar", "solar", "electrical", "alarm", "hmi"] { XCTAssertNotEqual(family, NodeHealthText.family(family, t)) }
        for status in ["ok", "warning", "stale"] { XCTAssertNotEqual(status, NodeHealthText.status(status, t)) }
        for code in ["node_low_memory", "node_frequent_resets", "node_link_flapping", "node_weak_signal", "node_sensor_bluetooth_open", "node_radar_masked", "node_wifi_jam"] {
            XCTAssertNotEqual(code, NodeHealthText.warning(code, t))
        }
        for reason in ["power_on", "external", "software", "panic", "int_wdt", "task_wdt", "other_wdt", "deep_sleep", "brownout", "sdio", "usb", "jtag", "efuse", "power_glitch", "cpu_lockup"] {
            XCTAssertNotEqual(reason, NodeHealthText.resetReason(reason, t))
        }
        XCTAssertEqual(NodeHealthText.resetReason("cosmic_ray", t), "desconocido")
        XCTAssertTrue(NodeHealthText.isUnexpected("panic"))
        XCTAssertTrue(NodeHealthText.isUnexpected("brownout"))
        XCTAssertFalse(NodeHealthText.isUnexpected("software"))
        XCTAssertFalse(NodeHealthText.isUnexpected("power_on"))
    }

    func testTheLinkTheSignalTheMemoryAndTheUptimeAreToldInWords() throws {
        let nodes = try loaded().nodes
        XCTAssertEqual(NodeHealthText.link(nodes[0], t), "Wi-Fi · activo · -83 dBm (muy débil)")
        XCTAssertEqual(NodeHealthText.link(nodes[1], t), "Cable Ethernet · activo")
        XCTAssertEqual(NodeHealthText.link(nodes[2], t), "sin enlace · caído")
        XCTAssertEqual([-55, -65, -75, -90].map { NodeHealthText.signal($0, t) }, ["buena", "aceptable", "débil", "muy débil"])
        XCTAssertEqual([500, 142_000, 1_500_000, -1].map { NodeHealthText.bytes($0) }, ["500 B", "139 KB", "1.4 MB", "–"])
        XCTAssertEqual([93_784, 3_600, 420, 5].map { NodeHealthText.uptime($0, t) }, ["1 d 2 h", "1 h 0 min", "7 min", "0 min"])
    }

    func testTheSummaryOfTheScreenSaysWhatNeedsALook() throws {
        XCTAssertEqual(NodeHealthText.summary(NodeHealthOverview(), t), "Ningún nodo ha enviado aún su informe de salud")
        var overview = try loaded()
        XCTAssertEqual(NodeHealthText.summary(overview, t), "Un nodo con aviso de salud")
        overview.totals = NodeHealthTotals(nodes: 5, stale: 0, withWarnings: 3)
        XCTAssertEqual(NodeHealthText.summary(overview, t), "3 nodos con aviso de salud")
        overview.totals = NodeHealthTotals(nodes: 5, stale: 2, withWarnings: 0)
        XCTAssertEqual(NodeHealthText.summary(overview, t), "2 nodos sin informe reciente")
        overview.totals = NodeHealthTotals(nodes: 5, stale: 0, withWarnings: 0)
        XCTAssertEqual(NodeHealthText.summary(overview, t), "Todos los nodos sanos")
    }

    func testTheNodesThatNeedALookComeFirst() throws {
        let nodes = try loaded().nodes
        XCTAssertEqual(NodeHealthText.orderedByNeed(nodes.reversed()).map { $0.nodeId }, ["radar-1", "solar-1", "alarm-1"])
    }
}
