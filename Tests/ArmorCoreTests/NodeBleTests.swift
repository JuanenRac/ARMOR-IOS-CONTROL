import XCTest
@testable import ArmorCore

/// The Bluetooth channel to a field node: framing, requests and answers, the set-up code and the settings the app sends. The radio itself is not tested here.
final class NodeBleTests: XCTestCase {
    private let message = #"{"id":1,"op":"hello"}"#
    private let t = plain()

    private func object(_ text: String) -> JSON { (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? JSON ?? [:] }

    func testAMessageIsItsLengthInTwoBytesAndItsJson() {
        let framed = BleFrame.frame(message)!
        XCTAssertEqual(framed.count, message.utf8.count + 2)
        XCTAssertEqual(framed[0], 0)
        XCTAssertEqual(Int(framed[1]), message.utf8.count)
        XCTAssertNil(BleFrame.frame(""))
        XCTAssertNil(BleFrame.frame(String(repeating: "x", count: BleFrame.maxMessage + 1)))
        XCTAssertNotNil(BleFrame.frame(String(repeating: "x", count: BleFrame.maxMessage)))
    }

    func testAnyWayOfCuttingTheStreamGivesTheMessageBack() {
        let framed = BleFrame.frame(message)!
        for size in [1, 2, 3, 7, 20, 244, 500] {
            let assembler = BleAssembler()
            let got = BleFrame.chunks(framed, size: size).flatMap { assembler.feed($0) }
            XCTAssertEqual(got, [message], "cut in \(size)")
        }
    }

    func testTwoMessagesInOneWriteComeOutOneByOneAndABadLengthIsDropped() {
        let second = #"{"id":2,"op":"status"}"#
        let assembler = BleAssembler()
        XCTAssertEqual(assembler.feed(BleFrame.frame(message)! + BleFrame.frame(second)!), [message, second])
        XCTAssertEqual(assembler.feed([0, 0]), [])
        XCTAssertEqual(assembler.feed([0xFF, 0xFF]), [])
        XCTAssertEqual(assembler.errors, 2)
        XCTAssertEqual(assembler.feed(BleFrame.frame(message)!), [message])   // and it understands the next one
    }

    func testUtf8SurvivesTheFraming() {
        let text = #"{"id":3,"op":"x","args":{"name":"Perímetro norte 日本"}}"#
        XCTAssertEqual(BleAssembler().feed(BleFrame.frame(text)!), [text])
    }

    func testARequestIsJsonWithAnIdAndAnOperation() {
        let json = object(NodeProtocol.request(id: 7, op: "login", args: ["user": "admin", "password": "x"]))
        XCTAssertEqual(json.int("id"), 7)
        XCTAssertEqual(json.str("op"), "login")
        XCTAssertEqual(json.object("args")?.str("user"), "admin")
        XCTAssertFalse(object(NodeProtocol.request(id: 8, op: "hello")).has("args"))
        XCTAssertFalse(NodeProtocol.request(id: 9, op: "x", args: ["uri": "mqtt://a/b"]).contains("\\/"))   // slashes are not escaped
    }

    func testAnswersAreReadWithTheirDataAndTheirErrors() {
        let ok = NodeProtocol.reply(#"{"id":7,"ok":true,"data":{"role":"admin"}}"#)!
        XCTAssertTrue(ok.ok)
        XCTAssertEqual(ok.id, 7)
        XCTAssertEqual(ok.data.str("role"), "admin")
        let bad = NodeProtocol.reply(#"{"id":9,"ok":false,"error":"invalid","data":{"problems":[{"path":"ap.ssid","code":"required"},{"path":"mqtt.uri","code":"invalid"}]}}"#)!
        XCTAssertFalse(bad.ok)
        XCTAssertEqual(bad.error, "invalid")
        XCTAssertEqual(bad.problems(t), ["ap.ssid: required", "mqtt.uri: invalid"])
        XCTAssertNil(NodeProtocol.reply("nonsense"))
        XCTAssertNil(NodeProtocol.reply(#"{"id":1}"#))
        XCTAssertTrue(NodeProtocol.errorText("wrong_code", t).contains("código"))
        XCTAssertTrue(NodeProtocol.errorText("zzz", t).contains("zzz"))
    }

    func testWhatTheNodeSaysAboutItselfAndTheNetworksItHears() {
        let hello = NodeHello(object(#"{"node_id":"armor-a1b2c3","name":"Valla norte","mac":"34:85:18:a1:b2:c3","firmware":"0.2.3","setup":true,"has_ip":false,"ip":"","sta_connected":false,"sta_ssid":""}"#))
        XCTAssertEqual(hello.nodeId, "armor-a1b2c3")
        XCTAssertTrue(hello.setup)
        XCTAssertFalse(hello.hasIp)
        XCTAssertEqual(hello.mac, "34:85:18:a1:b2:c3")
        let list = WifiNetwork.list(object(#"{"networks":[{"ssid":"Casa","rssi":-48,"channel":6,"security":"wpa2"},{"ssid":"Abierta","rssi":-80,"channel":1,"security":"open"}]}"#))
        XCTAssertEqual(list.map { $0.ssid }, ["Casa", "Abierta"])
        XCTAssertEqual(list[0].rssi, -48)
        XCTAssertEqual(list[1].security, "open")
        XCTAssertEqual(WifiNetwork.list([:]), [])
    }

    func testTheKindsOfNodeAreToldApartByWhatTheyDeclare() {
        func kind(_ json: String) -> NodeKind { NodeHello(object(json)).kind }
        XCTAssertEqual(kind(#"{"kind":"radar","node_id":"armor-a1b2c3"}"#), .radar)
        XCTAssertEqual(kind(#"{"kind":"solar","node_id":"casa-solar"}"#), .solar)
        XCTAssertEqual(kind(#"{"kind":"electrical","node_id":"cuadro"}"#), .electrical)
        XCTAssertEqual(kind(#"{"kind":"alarm","node_id":"alarma-1"}"#), .alarm)
        XCTAssertEqual(kind(#"{"kind":"hmi","node_id":"panel-1"}"#), .hmi)
        // a node that predates the field: told by its identifier when it says so, otherwise an ARMOR node
        XCTAssertEqual(kind(#"{"node_id":"solar-a1b2c3"}"#), .solar)
        XCTAssertEqual(kind(#"{"node_id":"electrical-a1b2c3"}"#), .electrical)
        XCTAssertEqual(kind(#"{"node_id":"armor-a1b2c3"}"#), .unknown)
        XCTAssertEqual(kind(#"{"kind":"other","node_id":"solar-x"}"#), .unknown)
        XCTAssertEqual(NodeKind.electrical.label(t), "Nodo eléctrico")
    }

    func testTheFieldsANodeRefusesAreToldInPlainWords() {
        let reply = NodeProtocol.reply(#"{"id":3,"ok":false,"error":"invalid","data":{"problems":[{"path":"uplink","code":"not_available"},{"path":"sta.enabled","code":"required"},{"path":"mqtt.uri","code":"invalid"}]}}"#)!
        let problems = reply.problems(t)
        XCTAssertTrue(problems[0].contains("Ethernet"))
        XCTAssertTrue(problems[1].contains("inalcanzable"))
        XCTAssertEqual(problems[2], "mqtt.uri: invalid")
    }

    func testTheSetupCodeOfABoardIsTheOneTheFirmwareAndAdoptNodeMake() {
        // The vector of ARMOR-NODE-RADAR's tests: openssl, the firmware's mapping and adopt_node.py all give GD8VZH4HBM.
        let secret = "fleet-secret-for-tests-0123456789"
        XCTAssertEqual(SetupCode.derive(secret: secret, mac: "a1b2c3d4e5f6"), "GD8VZH4HBM")
        XCTAssertEqual(SetupCode.derive(secret: secret, mac: "A1:B2:C3:D4:E5:F6"), "GD8VZH4HBM")
        XCTAssertEqual(SetupCode.derive(secret: secret, mac: "a1b2c3d4e5f7")?.count, 10)
    }

    func testASetupCodeIsRefusedForABadMacOrAShortSecret() {
        let secret = "fleet-secret-for-tests-0123456789"
        XCTAssertNil(SetupCode.derive(secret: secret, mac: "a1b2c3"))                 // not a MAC
        XCTAssertNil(SetupCode.derive(secret: "short", mac: "a1b2c3d4e5f6"))          // a fleet secret has 16 characters or more
        XCTAssertEqual(SetupCode.macDigits("A1:B2:C3:D4:E5:F6"), "a1b2c3d4e5f6")
    }

    func testTheSettingsTheAppSendsChangeOnlyWhatWasFilledIn() {
        var form = NodeSettingsPatch.Form()
        form.name = " Valla norte "
        let wired = NodeSettingsPatch.build(form)
        XCTAssertEqual(wired.str("uplink"), "ethernet")
        XCTAssertEqual(wired.object("node")?.str("name"), "Valla norte")
        XCTAssertTrue(wired.object("ip")?.bool("dhcp") ?? false)
        XCTAssertFalse(wired.has("sta"))
        XCTAssertFalse(wired.has("mqtt"))
        XCTAssertFalse(wired.has("ble"))

        var fixed = NodeSettingsPatch.Form()
        fixed.fixedAddress = true; fixed.address = "192.168.0.60"; fixed.gateway = "192.168.0.1"
        let ip = NodeSettingsPatch.build(fixed).object("ip")!
        XCTAssertFalse(ip.bool("dhcp", true))
        XCTAssertEqual(ip.str("address"), "192.168.0.60")
        XCTAssertEqual(ip.str("netmask"), "255.255.255.0")
        XCTAssertEqual(ip.str("dns1"), "192.168.0.1")

        var wifi = NodeSettingsPatch.Form()
        wifi.useWifi = true; wifi.wifiSsid = "Casa"; wifi.wifiPassword = "clave del router"; wifi.fixedAddress = true; wifi.address = "1.2.3.4"
        let patch = NodeSettingsPatch.build(wifi)
        XCTAssertEqual(patch.str("uplink"), "wifi")
        XCTAssertEqual(patch.object("ip")?.str("address"), "1.2.3.4")   // a fixed address works on the Wi-Fi too
        let sta = patch.object("sta")!
        XCTAssertTrue(sta.bool("enabled"))
        XCTAssertEqual(sta.str("ssid"), "Casa")
        XCTAssertEqual(sta.str("password"), "clave del router")
        var open = NodeSettingsPatch.Form()
        open.useWifi = true; open.wifiSsid = "Abierta"
        XCTAssertFalse(NodeSettingsPatch.build(open).object("sta")!.has("password"))   // an empty password keeps the stored one

        var broker = NodeSettingsPatch.Form()
        broker.brokerUri = "mqtt://192.168.0.180:18883"; broker.brokerUser = "field-node-x"; broker.brokerPassword = "p"; broker.bluetoothMode = "always"
        let withBroker = NodeSettingsPatch.build(broker)
        XCTAssertEqual(withBroker.object("mqtt")?.str("uri"), "mqtt://192.168.0.180:18883")
        XCTAssertEqual(withBroker.object("mqtt")?.str("username"), "field-node-x")
        XCTAssertEqual(withBroker.object("ble")?.str("mode"), "always")
        var loud = NodeSettingsPatch.Form()
        loud.bluetoothMode = "loud"
        XCTAssertFalse(NodeSettingsPatch.build(loud).has("ble"))
    }

    func testAFormIsCheckedBeforeItIsSent() {
        func form(_ change: (inout NodeSettingsPatch.Form) -> Void) -> [String] {
            var f = NodeSettingsPatch.Form(); change(&f); return NodeSettingsPatch.problems(f, t)
        }
        XCTAssertEqual(form { $0.useWifi = true; $0.wifiSsid = "Casa"; $0.wifiPassword = "clave del router" }, [])
        XCTAssertEqual(form { $0.useWifi = true }, ["Falta el nombre de la red Wi-Fi."])
        XCTAssertTrue(form { $0.useWifi = true; $0.wifiSsid = "Casa"; $0.wifiPassword = "corta" }.first?.contains("8 a 63") ?? false)
        XCTAssertEqual(form { $0.fixedAddress = true; $0.address = "192.168.0.60"; $0.gateway = "192.168.0.1" }, [])
        XCTAssertEqual(form { $0.fixedAddress = true }.count, 2)   // the address and the gateway (the mask has a valid default)
        XCTAssertTrue(form { $0.fixedAddress = true; $0.address = "192.168.0.60"; $0.gateway = "10.0.0.1" }.first?.contains("misma red") ?? false)
        XCTAssertTrue(form { $0.fixedAddress = true; $0.address = "192.168.0.300"; $0.gateway = "192.168.0.1" }.first?.contains("dirección IP") ?? false)
        XCTAssertTrue(form { $0.fixedAddress = true; $0.address = "192.168.0.1"; $0.gateway = "192.168.0.1" }.first?.contains("no pueden ser la misma") ?? false)
    }

    func testWhatTheNodeDidWithItsConnectionIsToldFromItsHello() {
        func hello(_ json: String) -> NodeHello { NodeHello(object(json)) }
        XCTAssertEqual(NodeOutcome.of(hello(#"{"has_ip":true,"ip":"192.168.0.77","sta_connected":true,"sta_ssid":"Casa"}"#), t), .online(ip: "192.168.0.77", ssid: "Casa"))
        XCTAssertEqual(NodeOutcome.of(hello(#"{"has_ip":true,"ip":"192.168.0.60","sta_connected":false}"#), t), .online(ip: "192.168.0.60", ssid: ""))   // on the cable
        guard case .failed(let wrong) = NodeOutcome.of(hello(#"{"has_ip":false,"sta_connected":false,"sta_ssid":"","sta_error":"wrong_password"}"#), t) else { return XCTFail("expected a failure") }
        XCTAssertTrue(wrong.contains("contraseña"))
        guard case .failed(let missing) = NodeOutcome.of(hello(#"{"sta_error":"network_not_found"}"#), t) else { return XCTFail("expected a failure") }
        XCTAssertTrue(missing.contains("2,4 GHz"))
        XCTAssertEqual(NodeOutcome.of(hello(#"{"has_ip":false}"#), t), .waiting)   // an older firmware says nothing about why
        XCTAssertEqual(hello(#"{"sta_error":"wrong_password"}"#).staError, "wrong_password")
    }

    func testTheIdentifiersMatchTheFirmware() {
        XCTAssertEqual(NodeGatt.service, "a5c0de00-5261-4d4f-8000-41524d4f5200")
        XCTAssertEqual(NodeGatt.rx, "a5c0de01-5261-4d4f-8000-41524d4f5200")
        XCTAssertEqual(NodeGatt.tx, "a5c0de02-5261-4d4f-8000-41524d4f5200")
    }

    func testAScannedPairingCodeMarksTheNodeAndWarnsAboutAnotherServer() {
        let pairing = Pairing(nodeId: "radar-1", server: "https://armor.local:8443")
        XCTAssertTrue(PairingMatch.matches(nodeName: "ARMOR-RADAR-1", pairing: pairing))
        XCTAssertFalse(PairingMatch.matches(nodeName: "ARMOR-SOLAR-2", pairing: pairing))
        XCTAssertFalse(PairingMatch.matches(nodeName: "ARMOR-RADAR-1", pairing: nil))
        XCTAssertFalse(PairingMatch.otherServer(pairing, origin: "https://armor.local:8443/"))
        XCTAssertTrue(PairingMatch.otherServer(pairing, origin: "http://192.168.0.180:18080"))
        XCTAssertFalse(PairingMatch.otherServer(pairing, origin: ""))
    }

    func testSha256AndHmacMatchTheStandardVectors() {
        func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(hex(Sha256.hash(Array("abc".utf8))), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(hex(Sha256.hash([])), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(hex(Sha256.hash(Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8))), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        // RFC 4231, test case 1 (a short key) and test case 6 (a key longer than a block)
        XCTAssertEqual(hex(Sha256.hmac(key: [UInt8](repeating: 0x0b, count: 20), message: Array("Hi There".utf8))), "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
        XCTAssertEqual(hex(Sha256.hmac(key: [UInt8](repeating: 0xaa, count: 131), message: Array("Test Using Larger Than Block-Size Key - Hash Key First".utf8))), "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54")
    }
}
