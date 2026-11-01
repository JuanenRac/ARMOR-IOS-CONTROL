import XCTest
@testable import ArmorCore

final class NetworkTests: XCTestCase {
    private func json(_ text: String) -> JSON { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! JSON }

    private let sample = """
    {"nodes":[{"node_id":"net-1","stale":false,
      "interface":{"ip":"192.168.0.2","cidr":"192.168.0.0/24","gateway":"192.168.0.1","rx_bps":2500000,"tx_bps":900},
      "internet":{"state":"degraded","since_ms":1000,"gateway_ok":true,"latency_ms":31.5,"loss_percent":2,"probes":[{"target":"1.1.1.1","kind":"icmp","ok":true,"latency_ms":20}],"outages_24h":2,"downtime_24h_s":4000},
      "public":{"ip":"203.0.113.9","org":"Provider","country":"ES"},
      "devices":[
        {"id":"d1","ip":"192.168.0.20","mac":"AA:BB","vendor":"Espressif Inc.","hostname":"armor-radar-1.local","kind":"iot","online":true,"ports":[{"port":23,"service":"telnet"},{"port":80}],"services":["http"]},
        {"id":"d2","ip":"192.168.0.5","hostname":"printer","kind":"printer","online":false,"note":{"name":"Impresora","trusted":true}},
        {"id":"d3","ip":"192.168.0.9","vendor":"Espressif Inc.","online":true},
        {"id":"d4","ip":"192.168.0.30","hostname":"armor-solar-2","online":true},
        {"id":"","ip":"1.2.3.4"}]},
      {"node_id":"net-2"}],
     "totals":{"nodes":1,"stale":0,"devices":4,"online":3,"unknown":2,"internet":"degraded"},
     "events":[{"id":"e1","node_id":"net-1","kind":"port_opened","at_ms":5,"device_id":"d1","port":23},{"id":"","kind":"x"}],
     "outages":[{"kind":"internet","started_ms":1,"ended_ms":2,"duration_s":60}]}
    """

    func testTheNetworkIsReadWithItsInternetItsDevicesItsEventsAndItsOutages() {
        let overview = NetworkParser.overview(json(sample))
        XCTAssertEqual(overview.nodes.map(\.nodeId), ["net-1"])
        let node = overview.nodes[0]
        XCTAssertEqual(node.gateway, "192.168.0.1")
        XCTAssertEqual(node.rxBps, 2_500_000)
        XCTAssertEqual(node.internet.state, "degraded")
        XCTAssertEqual(node.internet.gatewayOk, true)
        XCTAssertEqual(node.internet.probes.count, 1)
        XCTAssertEqual(node.publicInfo?.ip, "203.0.113.9")
        XCTAssertNil(node.publicInfo?.city)
        XCTAssertEqual(node.devices.map(\.id), ["d1", "d2", "d3", "d4"])
        XCTAssertEqual(overview.totals.unknown, 2)
        XCTAssertEqual(overview.totals.internet, "degraded")
        XCTAssertEqual(overview.events.map(\.id), ["e1"])
        XCTAssertEqual(overview.events[0].port, 23)
        XCTAssertEqual(overview.outages.count, 1)
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(NetworkParser.overview([:]).isEmpty)
    }

    func testADeviceIsCalledByWhatTheOperatorSaidThenItsNameThenItsMakerThenItsAddress() {
        let devices = NetworkParser.overview(json(sample)).nodes[0].devices
        XCTAssertEqual(devices[1].name, "Impresora")
        XCTAssertTrue(devices[1].known)
        XCTAssertEqual(devices[0].name, "armor-radar-1.local")
        XCTAssertEqual(devices[2].name, "Espressif Inc.")
        XCTAssertFalse(devices[2].known)
        let bare = NetworkParser.overview(json(#"{"nodes":[{"node_id":"n","interface":{},"internet":{},"devices":[{"id":"x","ip":"10.0.0.1"}]}]}"#)).nodes[0].devices[0]
        XCTAssertEqual(bare.name, "10.0.0.1")
        XCTAssertEqual(bare.shownKind, "unknown")
    }

    func testTheNodeFinderListsWhatLooksLikeAnArmorNodeAndIsNotKnownYet() {
        let overview = NetworkParser.overview(json(sample))
        let all = NodeFinder.candidates(overview, knownIds: [])
        XCTAssertEqual(all.map(\.ip), ["192.168.0.20", "192.168.0.30", "192.168.0.9"])
        XCTAssertEqual(all[0].nodeId, "radar-1")
        XCTAssertEqual(all[1].nodeId, "solar-2")
        XCTAssertNil(all[2].nodeId)
        let known = NodeFinder.candidates(overview, knownIds: ["Radar-1"])
        XCTAssertEqual(known.map(\.ip), ["192.168.0.30", "192.168.0.9"])
        XCTAssertTrue(NodeFinder.candidates(nil, knownIds: []).isEmpty)
    }

    func testTheStateOfTheInternetHasWordsAndAHintWhenTheFaultIsKnown() {
        let t = plain("es")
        XCTAssertEqual(NetworkText.state("up", t), "Hay internet")
        XCTAssertEqual(NetworkText.state("other", t), "Comprobando internet…")
        XCTAssertNotNil(NetworkText.hint("down", t))
        XCTAssertNotNil(NetworkText.hint("lan_down", t))
        XCTAssertNil(NetworkText.hint("up", t))
        XCTAssertEqual(NetworkText.kind("router", t), "Router")
        XCTAssertEqual(NetworkText.kind("printer", t), "Impresora")
        XCTAssertEqual(NetworkText.kind("???", t), "Desconocido")
    }

    func testDurationsAndSpeedsAreShortAndReadable() {
        let t = plain("es")
        XCTAssertEqual(NetworkText.duration(45, t), "45 s")
        XCTAssertEqual(NetworkText.duration(200, t), "3 min")
        XCTAssertEqual(NetworkText.duration(7500, t), "2 h 5 min")
        XCTAssertEqual(NetworkText.duration(7200, t), "2 h")
        XCTAssertEqual(NetworkText.duration(200_000, t), "2 d 7 h")
        XCTAssertEqual(NetworkText.duration(-5, t), "0 s")
        XCTAssertEqual(NetworkText.bps(nil, t), "—")
        XCTAssertEqual(NetworkText.bps(500, t), "500 bit/s")
        XCTAssertEqual(NetworkText.bps(2_500, t), "3 kbit/s")
        XCTAssertEqual(NetworkText.bps(2_500_000, t), "2.5 Mbit/s")
        XCTAssertEqual(NetworkText.bps(25_000_000, t), "25 Mbit/s")
        XCTAssertEqual(NetworkText.bps(1_250_000_000, t), "1.25 Gbit/s")
    }

    func testAnEventIsASentenceThatNamesTheDevice() {
        let t = plain("es")
        let overview = NetworkParser.overview(json(sample))
        let devices = overview.nodes[0].devices
        XCTAssertEqual(NetworkText.event(overview.events[0], devices, t), "armor-radar-1.local (192.168.0.20) ha abierto el puerto 23")
        let back = NetworkParser.overview(json(#"{"events":[{"id":"a","kind":"internet_up","outage_s":200},{"id":"b","kind":"weird"}]}"#)).events
        XCTAssertEqual(NetworkText.event(back[0], [], t), "Vuelve internet tras 3 min")
        XCTAssertEqual(NetworkText.event(back[1], [], t), "weird")
    }

    func testTheStatusLineGivesTheInternetAndTheDevices() {
        let t = plain("es")
        let overview = NetworkParser.overview(json(sample))
        XCTAssertEqual(NetworkText.summary(overview, t), "Internet va lento o pierde paquetes · 3/4 dispositivos · 2 sin conocer")
        XCTAssertEqual(NetworkText.summary(NetworkOverview(), t), "")
    }

    func testAddressesAreOrderedAsNumbers() {
        XCTAssertTrue(NetworkText.ipKey("192.168.0.9") < NetworkText.ipKey("192.168.0.20"))
        XCTAssertTrue(NetworkText.ipKey("10.0.0.1") < NetworkText.ipKey("192.168.0.1"))
        XCTAssertTrue(NetworkText.riskyPorts.contains(23))
    }

    func testTheNetworkIsReadAndSweptThroughTheClient() async throws {
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let api: ArmorApi = ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "0.1.0")
        StubProtocol.routes["GET /api/v1/network"] = (200, sample)
        StubProtocol.routes["POST /api/v1/network/commands"] = (202, "{}")
        let overview = try await api.network("http://192.168.0.180:8080")
        XCTAssertEqual(overview.nodes.count, 1)
        try await api.scanNetworkNow("http://192.168.0.180:8080")
        XCTAssertTrue(try XCTUnwrap(StubProtocol.bodies.last).contains("\"type\":\"scan_now\""))
    }
}
