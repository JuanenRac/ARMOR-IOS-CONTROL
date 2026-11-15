import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import ArmorCore

/// A twin of ARMOR-SERVER for the tests: the real `ArmorApiClient` talks to it through a URL protocol, so the requests, the status codes and the JSON that cross the wire are the real ones
/// and no phone, server, node or network is needed. It keeps a small state (session, arming mode, PIN, alarms, history, push tokens) and can be made to fail on purpose: a cut line, a
/// refusal on one path, an expired session. Everything is deterministic: ids and times are counted, never read from a clock.
final class SimulatedServer: @unchecked Sendable {
    static let shared = SimulatedServer()

    struct SimAlarm {
        let id: String
        let code: String
        let severity: String
        let node: String
        var acknowledged = false
    }

    private let lock = NSLock()
    private var store = State()

    private struct State {
        var users: [String: String] = ["ana": "pw"]
        var totpCode: String?            // when set, the sign-in asks for this second factor
        var signedIn = false
        var role = "admin"
        var mode = "disarmed"
        var pin = "1234"
        var wrongPins = 0
        var alarms: [SimAlarm] = []
        var events: [[String: Any]] = []
        var nextEvent = 1
        var nextAlarm = 1
        var pushTokens: [String: String] = [:]
        var requests: [String] = []
        var cut = false
        var failures: [String: [(status: Int, body: String)]] = [:]
    }

    // MARK: set up

    func reset() { lock.lock(); store = State(); lock.unlock() }
    func requireSecondFactor(_ code: String?) { lock.lock(); store.totpCode = code; lock.unlock() }
    func setRole(_ role: String) { lock.lock(); store.role = role; lock.unlock() }
    /// The line goes down: every request fails like a phone with no network.
    func cutLine(_ cut: Bool) { lock.lock(); store.cut = cut; lock.unlock() }
    /// The next `times` requests to `METHOD /path` get `status` and `body` instead of their normal answer.
    func fail(_ key: String, status: Int, body: String = "{}", times: Int = 1) {
        lock.lock(); store.failures[key] = Array(repeating: (status: status, body: body), count: times); lock.unlock()
    }
    /// The server forgets the session (a restart, a timeout): the next request that needs it gets 401.
    func expireSession() { lock.lock(); store.signedIn = false; lock.unlock() }

    @discardableResult
    func raiseAlarm(code: String = "intrusion", severity: String = "high", node: String = "radar-1") -> String {
        lock.lock(); defer { lock.unlock() }
        let id = String(format: "alm-%05d", store.nextAlarm)
        store.nextAlarm += 1
        store.alarms.append(SimAlarm(id: id, code: code, severity: severity, node: node))
        addEvent(["type": "alarm", "alarm_id": id, "state": "raised", "severity": severity, "source": node, "source_type": "alarm", "code": code])
        return id
    }

    /// An event of the history that is not an alarm.
    func addNodeEvent(node: String, to: String) {
        lock.lock(); defer { lock.unlock() }
        addEvent(["type": "node", "node_id": node, "from": "online", "to": to])
    }

    private func addEvent(_ fields: [String: Any]) {
        var event = fields
        event["id"] = store.nextEvent
        event["at"] = String(format: "T+%05d", store.nextEvent)
        store.nextEvent += 1
        store.events.append(event)
    }

    // MARK: look

    var mode: String { lock.lock(); defer { lock.unlock() }; return store.mode }
    var requests: [String] { lock.lock(); defer { lock.unlock() }; return store.requests }
    var alarms: [SimAlarm] { lock.lock(); defer { lock.unlock() }; return store.alarms }
    var pushTokens: [String: String] { lock.lock(); defer { lock.unlock() }; return store.pushTokens }
    var signedIn: Bool { lock.lock(); defer { lock.unlock() }; return store.signedIn }
    func count(of key: String) -> Int { requests.filter { $0 == key }.count }

    // MARK: the answers

    enum Reply { case answer(Int, String), dropped }

    func handle(method: String, path: String, body: [String: Any]) -> Reply {
        lock.lock(); defer { lock.unlock() }
        let key = "\(method) \(path)"
        store.requests.append(key)
        if store.cut { return .dropped }
        if var queue = store.failures[key], !queue.isEmpty {
            let next = queue.removeFirst()
            store.failures[key] = queue
            return .answer(next.status, next.body)
        }
        let open = key == "POST /api/v1/studio/session" || key == "POST /api/v1/studio/session/totp"
        if !open, !store.signedIn { return .answer(401, #"{"error":"sign in first","code":"unauthorized"}"#) }
        switch (method, path) {
        case ("POST", "/api/v1/studio/session"):
            guard let name = body["username"] as? String, let word = body["password"] as? String, store.users[name] == word else {
                return .answer(401, #"{"error":"wrong user or password","code":"bad_credentials"}"#)
            }
            if store.totpCode != nil { return .answer(200, #"{"challenge":"sim-challenge","totp_required":true}"#) }
            store.signedIn = true
            return .answer(201, "{}")
        case ("POST", "/api/v1/studio/session/totp"):
            guard body["challenge"] as? String == "sim-challenge", let code = store.totpCode, body["code"] as? String == code else {
                return .answer(401, #"{"error":"wrong code","code":"bad_code"}"#)
            }
            store.signedIn = true
            return .answer(201, "{}")
        case ("GET", "/api/v1/studio/session"):
            return .answer(200, json(["user": ["name": "ana", "role": store.role], "capabilities": ["security": [String: Any]()]] as [String: Any]))
        case ("DELETE", "/api/v1/studio/session"):
            store.signedIn = false
            return .answer(204, "")
        case ("GET", "/api/v1/status"):
            return .answer(200, json(["mode": store.mode, "revision": store.nextEvent, "nodes": [String: Any]()] as [String: Any]))
        case ("GET", "/api/v1/history"):
            return .answer(200, json(["events": Array(store.events.reversed()), "next_before": 0] as [String: Any]))
        case ("GET", "/api/v1/alarms"):
            let all = store.alarms.map(alarmJson)
            return .answer(200, json(["active": all.filter { $0["acknowledged_at"] == nil }, "recent": all.filter { $0["acknowledged_at"] != nil }] as [String: Any]))
        case ("POST", "/api/v1/mode"):
            return setMode(body)
        case ("POST", "/api/v1/push/register"):
            guard let token = body["token"] as? String, !token.isEmpty else { return .answer(400, #"{"error":"no token"}"#) }
            let known = store.pushTokens[token] != nil
            store.pushTokens[token] = body["language"] as? String ?? ""
            return .answer(known ? 409 : 201, "{}")
        case ("POST", "/api/v1/push/unregister"):
            store.pushTokens[body["token"] as? String ?? ""] = nil
            return .answer(200, "{}")
        default:
            if method == "POST", path.hasPrefix("/api/v1/alarms/"), path.hasSuffix("/acknowledge") {
                let id = String(path.dropFirst("/api/v1/alarms/".count).dropLast("/acknowledge".count))
                guard let index = store.alarms.firstIndex(where: { $0.id == id }) else { return .answer(404, #"{"error":"no such alarm","code":"not_found"}"#) }
                store.alarms[index].acknowledged = true
                return .answer(200, "{}")
            }
            return .answer(404, #"{"error":"not found","code":"not_found"}"#)
        }
    }

    private func setMode(_ body: [String: Any]) -> Reply {
        guard let wanted = body["mode"] as? String, wanted == "armed" || wanted == "disarmed" else { return .answer(400, #"{"code":"bad_mode"}"#) }
        if wanted == "disarmed" {
            if store.wrongPins >= 3 { return .answer(429, #"{"error":"locked","code":"pin_locked"}"#) }
            if (body["pin"] as? String ?? "") != store.pin {
                store.wrongPins += 1
                return .answer(403, #"{"error":"wrong PIN","code":"wrong_pin"}"#)
            }
            store.wrongPins = 0
        }
        store.mode = wanted
        addEvent(["type": "mode", "mode": wanted])
        return .answer(200, "{}")
    }

    private func alarmJson(_ alarm: SimAlarm) -> [String: Any] {
        var item: [String: Any] = ["id": alarm.id, "key": "node:\(alarm.node):\(alarm.code)", "source": ["type": "alarm", "id": alarm.node], "severity": alarm.severity, "code": alarm.code, "raised_at": "T+00000"]
        if alarm.acknowledged { item["acknowledged_at"] = "T+99999"; item["acknowledged_by"] = "ana" }
        return item
    }

    private func json(_ object: Any) -> String { String(decoding: (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data(), as: UTF8.self) }
}

/// The URL protocol that puts `SimulatedServer` behind a `URLSession`.
final class SimulatedServerProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var data = Data()
        if let body = request.httpBody { data = body }
        else if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
            stream.close()
        }
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let url = request.url!
        switch SimulatedServer.shared.handle(method: request.httpMethod ?? "GET", path: url.path, body: body) {
        case .dropped:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case .answer(let status, let text):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(text.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}

    /// A client of the real kind, wired to the twin.
    static func makeClient() -> ArmorApiClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SimulatedServerProtocol.self]
        return ArmorApiClient(session: URLSession(configuration: configuration), clientTag: "sim")
    }
}
