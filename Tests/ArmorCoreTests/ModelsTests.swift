import XCTest
@testable import ArmorCore

final class ModelsTests: XCTestCase {
    func testStatusFromARealServer() throws {
        let status = ArmorSnapshot.parse(try fixture("status"))
        XCTAssertEqual(status.mode, "armed")
        XCTAssertTrue(status.armed)
        XCTAssertEqual(status.revision, 18)
        XCTAssertEqual(status.nodes.count, 1)
        XCTAssertEqual(status.nodes[0].id, "simulator-1")
        XCTAssertFalse(status.nodes[0].online)
        XCTAssertTrue(status.nodes[0].stale)
        XCTAssertEqual(status.nodes[0].targetCount, 2)
        XCTAssertEqual(status.nodes[0].alertLevel, "high")
    }
    func testAlarmsFromARealServer() throws {
        let root = try fixture("alarms")
        let active = root.objects("active").compactMap(Alarm.parse)
        XCTAssertEqual(active.map(\.id), ["alm-00002", "alm-00001"])
        XCTAssertEqual(active[1].severity, "high")
        XCTAssertFalse(active[0].acknowledged)
    }
    func testHistoryFromARealServer() throws {
        let events = try fixture("history").objects("events").compactMap(ArmorEvent.parse)
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(events[0].id, 26)
        XCTAssertEqual(events[0].type, "alarm")
        XCTAssertEqual(events[0].code, "node_down")
    }
    func testCameraViewsKeepNoSecrets() throws {
        XCTAssertTrue(CameraView.parse(try fixture("camera_views")).isEmpty, "the capture of the simulator has no cameras")
        let cameras = CameraView.parse(["cameras": [["id": "cam1", "name": "Porche", "password": "secreto", "rtspPath": "/live", "liveVideoAvailable": true], ["name": "sin id"]]])
        XCTAssertEqual(cameras, [CameraView(id: "cam1", name: "Porche", liveVideoAvailable: true)])
        XCTAssertFalse(String(describing: cameras).contains("secreto"))
    }
    func testTheAlarmOfADuressPinIsNeverListed() {
        let alarm: JSON = ["id": "a1", "source": ["type": "alarm", "id": "p1"], "severity": "critical", "code": "duress_disarm", "raised_at": "x"]
        XCTAssertNil(Alarm.parse(alarm))
        let event: JSON = ["id": 5, "type": "alarm", "source": "p1", "code": "duress_disarm", "state": "raised"]
        XCTAssertNil(ArmorEvent.parse(event))
    }
    func testMalformedThingsAreSkippedNotCrashed() {
        XCTAssertNil(Alarm.parse(["id": "a"]))
        XCTAssertNil(ArmorEvent.parse(["id": 0, "type": "alarm"]))
        XCTAssertNil(ArmorEvent.parse(["id": 3, "type": "mystery"]))
        XCTAssertNil(ArmorEvent.parse(["id": 3, "type": "node"]))
        XCTAssertEqual(ArmorSnapshot.parse([:]).mode, "disarmed")
    }
    func testAcknowledgedAlarm() {
        let alarm: JSON = ["id": "a1", "source": ["type": "device", "id": "d1"], "acknowledged_at": "t", "acknowledged_by": "ana", "cleared_at": NSNull()]
        let parsed = Alarm.parse(alarm)
        XCTAssertEqual(parsed?.acknowledgedBy, "ana")
        XCTAssertEqual(parsed?.cleared, false)
    }
    func testSessionFacts() {
        let facts = SessionFacts.parse(["user": ["role": "operator"], "capabilities": ["security": ["client.device_lock": "always"]]])
        XCTAssertEqual(facts.role, "operator")
        XCTAssertEqual(facts.deviceLock, "always")
        XCTAssertTrue(facts.canChange)
        XCTAssertFalse(SessionFacts.parse(["user": ["role": "viewer"]]).canChange)
        XCTAssertEqual(SessionFacts.parse([:]).deviceLock, "user")
    }
    func testApiErrorReadsTheCode() {
        let error = ArmorApiError(message: "x", status: 403, body: #"{"code":"wrong_pin","error":"El PIN no es correcto"}"#)
        XCTAssertEqual(error.code, "wrong_pin")
        XCTAssertEqual(error.detail, "El PIN no es correcto")
        XCTAssertTrue(ArmorApiError(message: "x", status: 403, body: "403 elevation_required").isElevationRequired)
        XCTAssertEqual(ArmorApiError(message: "x", status: 400, body: #"{"error":"x","code" : "pin_locked" "#).code, "pin_locked")
    }
    func testPreflightBlocksOnABlockingIssue() {
        let p = Preflight.parse(["ready": true, "issues": [["code": "zone_open", "level": "block", "id": "p1", "detail": "z2"]]])
        XCTAssertFalse(p.ready)
        XCTAssertEqual(p.blocking, 1)
        XCTAssertEqual(Preflight.describe(p.issues[0], plain()), "La zona z2 de la central p1 está abierta.")
    }
    func testPanelsAndProfiles() {
        let state: JSON = ["phase": "alarm", "mode": "away", "siren": true, "zones": [["id": "z1", "name": "", "state": "triggered"]], "open_zones": ["z1"], "arm_profiles": true]
        let panels = AlarmPanelsParser.panels(["nodes": [["node_id": "alarm-1", "stale": false, "state": state]]])
        XCTAssertEqual(panels.count, 1)
        XCTAssertTrue(panels[0].sounding)
        XCTAssertEqual(panels[0].zones[0].title, "z1")
        let profiles = AlarmPanelsParser.profiles(["profiles": [["id": "night", "name": "Night", "base": "stay"], ["id": "bad", "name": "x", "base": "other"]]])
        XCTAssertEqual(profiles.map(\.id), ["night"])
    }
    func testVoiceReplyLines() {
        let t = plain()
        let needs = VoiceReply.parse(["accepted": true, "outcome": "confirmation-needed", "intent": "arm", "speech": "Voy a armar", "confirmation_token": "tok"])
        XCTAssertEqual(needs.line(t), "Voy a armar. ¿Armo el sistema?")
        XCTAssertEqual(needs.confirmationToken, "tok")
        XCTAssertEqual(VoiceReply.parse(["outcome": "not-understood"]).line(t), "No lo he entendido. Di «ayuda» para saber qué puedo hacer.")
    }
}
