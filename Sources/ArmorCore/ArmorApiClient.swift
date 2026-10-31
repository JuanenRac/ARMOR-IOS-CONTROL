// ARMOR-IOS-CONTROL - the HTTP client of ARMOR-SERVER. Camera passwords and RTSP URLs never enter this client or the app.
// The URLSession is given from outside: the app makes one with its own cookie jar and its certificate rules, a test makes one with a fake protocol.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class ArmorApiClient: ArmorApi, @unchecked Sendable {
    /// The cookie of the session of the server, whose name ends like this.
    static let sessionCookieSuffix = "armor_studio_sid"
    private let session: URLSession
    private let clientTag: String

    /// `clientTag` is what the app says it is, so the history of connections of the server can tell it from Studio and from the other clients ("ios/0.1.0"; only informative).
    public init(session: URLSession, clientTag: String) {
        self.session = session
        self.clientTag = clientTag
    }

    /// A session with its own (ephemeral, in memory) cookie jar, no cache, and timeouts like the other clients'.
    public static func makeSession(delegate: URLSessionDelegate? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    // MARK: reading

    public func status(_ origin: String) async throws -> ArmorSnapshot { ArmorSnapshot.parse(try await getJson(origin, "/api/v1/status")) }

    public func history(_ origin: String, limit: Int, before: Int?, after: Int?) async throws -> [ArmorEvent] {
        var query = "?limit=\(limit)"
        if let before { query += "&before=\(before)" }
        if let after { query += "&after=\(after)" }
        return try await getJson(origin, "/api/v1/history\(query)").objects("events").compactMap(ArmorEvent.parse)
    }

    public func preflight(_ origin: String) async throws -> Preflight { Preflight.parse(try await getJson(origin, "/api/v1/preflight")) }

    public func alarms(_ origin: String) async throws -> (active: [Alarm], recent: [Alarm]) {
        let root = try await getJson(origin, "/api/v1/alarms")
        return (root.objects("active").compactMap(Alarm.parse), root.objects("recent").compactMap(Alarm.parse))
    }

    public func alarmPanels(_ origin: String) async throws -> [AlarmPanelView] { AlarmPanelsParser.panels(try await getJson(origin, "/api/v1/alarm/nodes")) }
    public func armProfiles(_ origin: String) async throws -> [ArmProfileView] { AlarmPanelsParser.profiles(try await getJson(origin, "/api/v1/alarm/profiles")) }
    public func alarmCommandsEnabled(_ origin: String) async throws -> Bool { AlarmPanelsParser.commandsEnabled(try await getJson(origin, "/api/v1/alarm/commands")) }
    public func devices(_ origin: String) async throws -> [SiteDevice] { SiteDevice.parse(try await getJson(origin, "/api/v1/devices")) }
    public func cameraViews(_ origin: String) async throws -> [CameraView] { CameraView.parse(try await getJson(origin, "/api/v1/camera-views")) }

    public func cameraStatus(_ origin: String) async throws -> [CameraHealth] {
        try await getJson(origin, "/api/v1/camera-status").objects("cameras").compactMap { item in
            let id = item.str("id")
            return id.isEmpty ? nil : CameraHealth(id: id, status: item.str("status", "unknown"))
        }
    }

    public func voiceAvailable(_ origin: String) async throws -> Bool { try await getJson(origin, "/api/v1/voice/status").bool("available") }

    // MARK: orders

    public func setMode(_ origin: String, mode: String, pin: String?) async throws {
        guard mode == "armed" || mode == "disarmed" else { throw ArmorApiError(message: "The mode is armed or disarmed", status: nil) }
        var body: JSON = ["mode": mode]
        if mode == "disarmed", let pin, !pin.isEmpty { body["pin"] = pin }
        do { _ = try await send(origin, "/api/v1/mode", "POST", body, [200]) } catch let error as ArmorApiError { throw ArmorApiClient.pinFailure(error) ?? error }
    }

    public func armingModes(_ origin: String) async throws -> ArmingModesView { ArmingModesView.parse(try await getJson(origin, "/api/v1/alarm/modes")) }

    public func setArmingMode(_ origin: String, mode: String, pin: String?, confirmUnassigned: Bool) async throws {
        guard ArmingModesView.armed.contains(mode) else { throw ArmorApiError(message: "The mode is away, home or night", status: nil) }
        var body: JSON = ["mode": mode]
        if let pin, !pin.isEmpty { body["pin"] = pin }
        if confirmUnassigned { body["confirm_unassigned"] = true }
        _ = try await send(origin, "/api/v1/mode", "POST", body, [200])
    }

    public func acknowledgeAlarm(_ origin: String, id: String) async throws { _ = try await send(origin, "/api/v1/alarms/\(Self.part(id))/acknowledge", "POST", nil, [200]) }
    public func acknowledgeAllAlarms(_ origin: String) async throws { _ = try await send(origin, "/api/v1/alarms/acknowledge", "POST", nil, [200]) }

    public func sendAlarmCommand(_ origin: String, node: String, mode: String?, force: Bool, pin: String?, profile: String?) async throws {
        var body: JSON = ["node": node, "action": mode == nil ? "disarm" : "arm"]
        if let mode {
            body["mode"] = mode
            if let profile { body["profile"] = profile }
            if force { body["force"] = true }
        } else if let pin, !pin.isEmpty { body["pin"] = pin }
        try await postAlarmCommand(origin, body)
    }

    public func silenceAlarmSiren(_ origin: String, node: String, pin: String?) async throws {
        var body: JSON = ["node": node, "action": "silence"]
        if let pin, !pin.isEmpty { body["pin"] = pin }
        try await postAlarmCommand(origin, body)
    }

    private func postAlarmCommand(_ origin: String, _ body: JSON) async throws {
        do { _ = try await send(origin, "/api/v1/alarm/command", "POST", body, [202]) } catch let error as ArmorApiError { throw ArmorApiClient.pinFailure(error) ?? error }
    }

    /// The refusal of a PIN (wrong, locked, none set) keeps its code so the screen can say it in words; any other failure is passed on.
    static func pinFailure(_ error: ArmorApiError) -> ArmorApiError? {
        ["wrong_pin", "pin_locked", "pin_not_set"].contains(error.code) ? error : nil
    }

    public func commandDevice(_ origin: String, id: String, command: String, confirm: Bool) async throws {
        var body: JSON = ["command": command]
        if confirm { body["confirm"] = true }
        _ = try await send(origin, "/api/v1/devices/\(Self.part(id))/command", "POST", body, [200])
    }

    public func snapshot(_ origin: String, cameraId: String) async throws { _ = try await send(origin, "/api/v1/cameras/\(Self.part(cameraId))/snapshot", "POST", nil, [201]) }
    public func ptz(_ origin: String, cameraId: String, command: String) async throws { _ = try await send(origin, "/api/v1/cameras/\(Self.part(cameraId))/ptz", "POST", ["command": command], [200]) }

    public func streamTicket(_ origin: String, cameraId: String, quality: String) async throws -> String {
        let asked = CameraQuality.accepted.contains(quality) ? quality : "auto"
        let data = try await send(origin, "/api/v1/cameras/\(Self.part(cameraId))/stream-ticket", "POST", ["quality": asked], [200, 201])
        let path = try Json.object(data).str("path")
        guard path.hasPrefix("/api/v1/cameras/") else { throw ArmorApiError(message: "The server gave no stream ticket", status: nil) }
        return Self.trimmed(origin) + path
    }

    public func voiceCommand(_ origin: String, text: String, language: String, confirmation: String?) async throws -> VoiceReply {
        var body: JSON = ["text": text, "language": language]
        if let confirmation { body["confirmation"] = confirmation }
        return VoiceReply.parse(try Json.object(try await send(origin, "/api/v1/voice/command", "POST", body, [200])))
    }

    // MARK: session

    public func signIn(_ origin: String, username: String, password: String) async throws -> SignIn {
        let data = try await send(origin, "/api/v1/studio/session", "POST", ["username": username, "password": password], [200, 201])
        let body = (try? Json.object(data)) ?? [:]
        if body.bool("totp_required"), !body.str("challenge").isEmpty { return .needsCode(challenge: body.str("challenge")) }
        return .done
    }

    public func completeSignIn(_ origin: String, challenge: String, code: String) async throws {
        _ = try await send(origin, "/api/v1/studio/session/totp", "POST", ["challenge": challenge, "code": code], [201])
    }

    public func sessionFacts(_ origin: String) async throws -> SessionFacts { SessionFacts.parse(try await getJson(origin, "/api/v1/studio/session")) }
    public func closeSession(_ origin: String) async throws { _ = try await send(origin, "/api/v1/studio/session", "DELETE", nil, [204]) }

    public func elevate(_ origin: String, password: String, code: String) async throws {
        var body: JSON = [:]
        if !password.isEmpty { body["password"] = password }
        if !code.isEmpty { body["code"] = code }
        _ = try await send(origin, "/api/v1/studio/elevate", "POST", body, [200])
    }

    public func registerPush(_ origin: String, token: String) async throws { _ = try await send(origin, "/api/v1/push/register", "POST", ["token": token], [200, 201, 409]) }
    public func unregisterPush(_ origin: String, token: String) async throws { _ = try await send(origin, "/api/v1/push/unregister", "POST", ["token": token], [200]) }

    public func sessionCookie(_ origin: String) -> SessionCookie? {
        guard let url = URL(string: origin), let jar = session.configuration.httpCookieStorage else { return nil }
        return jar.cookies(for: url)?.first { $0.name.hasSuffix(Self.sessionCookieSuffix) && !$0.value.isEmpty }.map { SessionCookie(name: $0.name, value: $0.value) }
    }

    public func restoreSessionCookie(_ origin: String, _ cookie: SessionCookie) {
        guard let url = URL(string: origin), let host = url.host, let jar = session.configuration.httpCookieStorage else { return }
        var properties: [HTTPCookiePropertyKey: Any] = [.name: cookie.name, .value: cookie.value, .domain: host, .path: "/", .expires: Date().addingTimeInterval(7 * 24 * 3600)]
        if url.scheme == "https" { properties[.secure] = "TRUE" }
        if let made = HTTPCookie(properties: properties) { jar.setCookie(made) }
    }

    public func forgetSession(_ origin: String) {
        guard let url = URL(string: origin), let jar = session.configuration.httpCookieStorage else { return }
        for cookie in jar.cookies(for: url) ?? [] { jar.deleteCookie(cookie) }
    }

    // MARK: plumbing

    static func trimmed(_ origin: String) -> String { origin.hasSuffix("/") ? String(origin.dropLast()) : origin }

    /// A piece of a path: everything but letters, digits and `-._~` is escaped, so "cam 1" goes as "cam%201" and a slash cannot climb out of the path.
    static func part(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func getJson(_ origin: String, _ path: String) async throws -> JSON { try Json.object(try await send(origin, path, "GET", nil, [200])) }

    func request(_ origin: String, _ path: String, _ method: String, _ body: JSON?) throws -> URLRequest {
        guard let url = URL(string: Self.trimmed(origin) + path) else { throw ArmorApiError(message: "The address is not valid", status: nil) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios/\(clientTag)", forHTTPHeaderField: "X-Armor-Client")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func send(_ origin: String, _ path: String, _ method: String, _ body: JSON?, _ expected: Set<Int>) async throws -> Data {
        let request = try request(origin, path, method, body)
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw ArmorApiError(message: error.localizedDescription, status: nil) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !expected.contains(status) {
            let text = String(decoding: data.prefix(2000), as: UTF8.self)
            let shown = String(text.prefix(180))
            throw ArmorApiError(message: "Server operation failed (HTTP \(status))" + (shown.isEmpty ? "" : ": \(shown)"), status: status, body: text)
        }
        return data
    }
}
