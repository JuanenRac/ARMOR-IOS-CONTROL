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

    public func dailySummary(_ origin: String, date: String, language: String) async throws -> DailySummaryView {
        ReportsParser.summary(try await getJson(origin, "/api/v1/summary/daily?date=\(Self.part(date))&lang=\(Self.part(language))"))
    }

    public func heatmap(_ origin: String, camera: String?) async throws -> HeatmapView {
        let query = (camera.map { $0.isEmpty ? "" : "camera=\(Self.part($0))&" } ?? "") + "scale=8"
        let map = try await getJson(origin, "/api/v1/vision/heatmap?\(query)&format=json")
        let picture = try await send(origin, "/api/v1/vision/heatmap?\(query)&format=png", "GET", nil, [200])
        return ReportsParser.heatmap(map, png: picture.count >= 8 && picture.count <= 16_000_000 ? picture : nil)
    }

    public func solar(_ origin: String) async throws -> SolarOverview { SolarParser.overview(try await getJson(origin, "/api/v1/solar")) }
    public func electrical(_ origin: String) async throws -> ElectricalOverview { ElectricalParser.overview(try await getJson(origin, "/api/v1/electrical/readings")) }
    public func batteryOperations(_ origin: String) async throws -> BatteryOverview { BatteryParser.overview(try await getJson(origin, "/api/v1/solar/battery-ops")) }

    public func batteryOperation(_ origin: String, id: String) async throws -> BatteryOperationView {
        BatteryParser.operation(try await getJson(origin, "/api/v1/solar/battery-ops/" + Self.part(id)))
    }

    public func batteryArm(_ origin: String, node: String, port: Int, op: String, output: String?, state: String?, serial: String) async throws -> BatteryOperationView {
        var params: JSON = [:]
        if op == "output_set" { params["output"] = output ?? ""; params["state"] = state ?? "" }
        let body: JSON = ["node": node, "port": port, "op": op, "params": params, "serial": serial]
        return BatteryParser.operation(try Json.object(try await send(origin, "/api/v1/solar/battery-ops", "POST", body, [202])))
    }

    public func batteryExecute(_ origin: String, id: String, serial: String) async throws -> BatteryOperationView {
        BatteryParser.operation(try Json.object(try await send(origin, "/api/v1/solar/battery-ops/" + Self.part(id) + "/execute", "POST", ["serial": serial], [202])))
    }

    public func batteryCancel(_ origin: String, id: String) async throws -> BatteryOperationView {
        BatteryParser.operation(try Json.object(try await send(origin, "/api/v1/solar/battery-ops/" + Self.part(id) + "/cancel", "POST", [:], [202])))
    }

    public func network(_ origin: String) async throws -> NetworkOverview { NetworkParser.overview(try await getJson(origin, "/api/v1/network")) }
    public func scanNetworkNow(_ origin: String) async throws { _ = try await send(origin, "/api/v1/network/commands", "POST", ["type": "scan_now"], [200, 201, 202]) }

    public func services(_ origin: String) async throws -> ServicesOverview { ServicesParser.overview(try await getJson(origin, "/api/v1/system/services")) }
    public func nodeHealth(_ origin: String) async throws -> NodeHealthOverview { NodeHealthParser.overview(try await getJson(origin, "/api/v1/node-health")) }

    public func nodeControl(_ origin: String, nodeId: String, operation: String, confirm: String?, durationS: Int?) async throws -> ControlOperationView {
        var body: JSON = ["operation": operation]
        if let confirm { body["confirm"] = confirm }
        if let durationS { body["duration_s"] = durationS }
        return NodeControlParser.operation(try Json.object(try await send(origin, "/api/v1/nodes/" + Self.part(nodeId) + "/control", "POST", body, [202])))
    }

    public func nodesControl(_ origin: String, operation: String, mode: String, confirm: String?, durationS: Int?) async throws -> ControlOperationView {
        var body: JSON = ["operation": operation, "mode": mode]
        if let confirm { body["confirm"] = confirm }
        if let durationS { body["duration_s"] = durationS }
        return NodeControlParser.operation(try Json.object(try await send(origin, "/api/v1/nodes/control", "POST", body, [202])))
    }

    public func connections(_ origin: String) async throws -> [ConnectionClient] { ConnectionsParser.list(try await getJson(origin, "/api/v1/history/connections")) }

    public func forgetNode(_ origin: String, id: String) async throws { _ = try await send(origin, "/api/v1/node-health/" + Self.part(id), "DELETE", nil, [204, 404]) }

    public func site(_ origin: String) async throws -> SiteDesign? { SiteParser.parse(try await getJson(origin, "/api/v1/site")) }

    public func nodeControlOperations(_ origin: String) async throws -> [ControlOperationView] { NodeControlParser.list(try await getJson(origin, "/api/v1/nodes/control/operations")) }

    public func nodeControlOperation(_ origin: String, id: String) async throws -> ControlOperationView {
        NodeControlParser.operation(try await getJson(origin, "/api/v1/nodes/control/operations/" + Self.part(id)))
    }
    public func machineUpdateState(_ origin: String) async throws -> MachineUpdateState { MachineUpdateParser.state(try await getJson(origin, "/api/v1/admin/machine-update")) }

    public func machineUpdatePreview(_ origin: String, project: String) async throws -> MachineUpdatePreview {
        MachineUpdateParser.preview(try Json.object(try await send(origin, "/api/v1/admin/machine-update/preview", "POST", ["project": project], [200])))
    }

    public func machineUpdateApply(_ origin: String, project: String, planId: String, confirm: String, code: String?) async throws -> String {
        var body: JSON = ["project": project, "plan_id": planId, "confirm": confirm]
        if let code, !code.isEmpty { body["totp"] = code }
        return MachineUpdateParser.startedId(try Json.object(try await send(origin, "/api/v1/admin/machine-update/apply", "POST", body, [202])))
    }

    public func machineUpdateJob(_ origin: String, id: String, since: Int) async throws -> MachineJobView {
        MachineUpdateParser.job(try await getJson(origin, "/api/v1/admin/machine-update/jobs/" + Self.part(id) + "?since=\(max(0, since))"))
    }

    public func mySessions(_ origin: String) async throws -> [SessionInfo] { SecurityParser.sessions(try await getJson(origin, "/api/v1/studio/sessions")) }
    public func endSession(_ origin: String, id: String) async throws { _ = try await send(origin, "/api/v1/studio/sessions/\(Self.part(id))", "DELETE", nil, [204]) }
    public func endOtherSessions(_ origin: String) async throws { _ = try await send(origin, "/api/v1/studio/sessions/end-others", "POST", nil, [204]) }
    public func totpState(_ origin: String) async throws -> TotpInfo { SecurityParser.totp(try await getJson(origin, "/api/v1/studio/totp")) }
    public func totpSetup(_ origin: String, password: String) async throws -> TotpSetup {
        SecurityParser.setup(try Json.object(try await send(origin, "/api/v1/studio/totp/setup", "POST", ["password": password], [200])))
    }
    public func totpEnable(_ origin: String, code: String) async throws -> [String] {
        SecurityParser.codes(try Json.object(try await send(origin, "/api/v1/studio/totp/enable", "POST", ["code": code], [200])))
    }
    public func totpDisable(_ origin: String, password: String) async throws { _ = try await send(origin, "/api/v1/studio/totp", "DELETE", ["password": password], [204]) }
    public func remoteCheck(_ origin: String) async throws -> RemoteInfo { SecurityParser.remote(try await getJson(origin, "/api/v1/remote/check")) }

    public func remoteSetup(_ origin: String) async throws -> RemoteSetup { SecurityParser.remoteSetup(try await getJson(origin, "/api/v1/admin/remote")) }

    public func vpnSetup(_ origin: String, endpoint: String, port: Int, lan: String, routeLan: String) async throws -> RemoteSetup {
        var body: JSON = ["endpoint": endpoint, "port": port]
        if !lan.isEmpty { body["lan"] = lan }
        if !routeLan.isEmpty { body["route_lan"] = routeLan }
        return SecurityParser.remoteSetup(try Json.object(try await send(origin, "/api/v1/admin/remote/wireguard/setup", "POST", body, [200])))
    }

    public func vpnAddPeer(_ origin: String, name: String, fullTunnel: Bool) async throws -> PeerConfig {
        SecurityParser.peerConfig(try Json.object(try await send(origin, "/api/v1/admin/remote/wireguard/peers", "POST", ["name": name, "full_tunnel": fullTunnel], [201])))
    }

    public func vpnShowPeer(_ origin: String, name: String) async throws -> PeerConfig {
        SecurityParser.peerConfig(try await getJson(origin, "/api/v1/admin/remote/wireguard/peers/" + Self.part(name)))
    }

    public func vpnRemovePeer(_ origin: String, name: String) async throws { _ = try await send(origin, "/api/v1/admin/remote/wireguard/peers/" + Self.part(name), "DELETE", nil, [200]) }

    public func ddnsSetup(_ origin: String, provider: String, domain: String, token: String, zone: String, record: String, url: String) async throws -> RemoteSetup {
        var body: JSON = ["provider": provider]
        for (key, value) in [("domain", domain), ("token", token), ("zone", zone), ("record_name", record), ("url", url)] where !value.isEmpty { body[key] = value }
        return SecurityParser.remoteSetup(try Json.object(try await send(origin, "/api/v1/admin/remote/ddns/setup", "POST", body, [200])))
    }

    public func ddnsUpdate(_ origin: String) async throws -> RemoteSetup { SecurityParser.remoteSetup(try Json.object(try await send(origin, "/api/v1/admin/remote/ddns/update", "POST", [:], [200]))) }
    public func ddnsRemove(_ origin: String) async throws -> RemoteSetup { SecurityParser.remoteSetup(try Json.object(try await send(origin, "/api/v1/admin/remote/ddns/remove", "POST", [:], [200]))) }

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
    public func panicGesture(_ origin: String) async throws { _ = try await send(origin, "/api/v1/alarm/panic-gesture", "POST", [:], [200]) }
    /// The still picture of a camera right now, as the bytes the server gives (nothing is saved on the server); longer than `limit` is refused.
    public func cameraStill(_ origin: String, cameraId: String, limit: Int) async throws -> Data {
        try ResponseLimit.check(try await send(origin, "/api/v1/cameras/\(Self.part(cameraId))/snapshot", "GET", nil, [200]), limit: limit)
    }
    /// Tells the server only the word for the signed-in person; any other word is refused here and never sent.
    public func setPresence(_ origin: String, state: String) async throws {
        guard PresenceShare.valid(state) else { throw ArmorApiError(message: "The presence word is home or away", status: nil) }
        _ = try await send(origin, "/api/v1/presence/me", "PUT", ["state": state], [200])
    }

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
    public func media(_ origin: String) async throws -> MediaCatalogueView { EvidenceParser.catalogue(try await getJson(origin, "/api/v1/media")) }

    public func deleteMedia(_ origin: String, item: MediaItemView) async throws { _ = try await send(origin, EvidenceParser.path(item), "DELETE", nil, [204]) }

    public func mediaFile(_ origin: String, item: MediaItemView) async throws -> URL {
        let request = try request(origin, EvidenceParser.path(item), "GET", nil)
        let location: URL, response: URLResponse
        do { (location, response) = try await session.download(for: request) } catch { DiagnosticLog.shared.record(method: "GET", path: EvidenceParser.path(item), status: 0); throw ArmorApiError(message: error.localizedDescription, status: nil) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        DiagnosticLog.shared.record(method: "GET", path: EvidenceParser.path(item), status: status)
        let attributes = try? FileManager.default.attributesOfItem(atPath: location.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        if status != 200 { try? FileManager.default.removeItem(at: location); throw ArmorApiError(message: "Server operation failed (HTTP \(status))", status: status) }
        if size > EvidenceParser.largestFile { try? FileManager.default.removeItem(at: location); throw ArmorApiError(message: "The file is longer than \(EvidenceParser.largestFile) bytes", status: nil) }
        // the name keeps its ending so the player knows what it was given; the folder is the phone's temporary one
        let ending = URL(fileURLWithPath: item.file).pathExtension
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent("armor-media-\(UUID().uuidString)" + (ending.isEmpty ? "" : "." + ending))
        try FileManager.default.moveItem(at: location, to: kept)
        return kept
    }

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

    /// The request of a spoken turn: the sound raw (16 kHz, 16-bit, mono) with the voice token and the language; the session is not what authenticates it.
    func voiceTurnRequest(_ origin: String, pcm: Data, language: String, voiceToken: String) throws -> URLRequest {
        var request = try self.request(origin, "/api/v1/voice/turn", "POST", nil)
        request.setValue("audio/L16;rate=16000", forHTTPHeaderField: "Content-Type")
        request.setValue(voiceToken, forHTTPHeaderField: "X-Armor-Voice-Token")
        request.setValue(language, forHTTPHeaderField: "X-Armor-Language")
        request.httpBody = pcm
        return request
    }

    public func voiceTurn(_ origin: String, pcm: Data, language: String, voiceToken: String) async throws -> JSON {
        try Json.object(try ResponseLimit.check(try await perform(try voiceTurnRequest(origin, pcm: pcm, language: language, voiceToken: voiceToken), "/api/v1/voice/turn", [200]), limit: ResponseLimit.json))
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

    public func registerPush(_ origin: String, token: String, language: String) async throws {
        var body: JSON = ["token": token]
        if !language.isEmpty { body["language"] = language }
        _ = try await send(origin, "/api/v1/push/register", "POST", body, [200, 201, 409])
    }
    public func unregisterPush(_ origin: String, token: String) async throws { _ = try await send(origin, "/api/v1/push/unregister", "POST", ["token": token], [200]) }

    public func trustRegister(_ origin: String, name: String, publicKey: String) async throws -> String {
        let data = try await send(origin, "/api/v1/devices/trust", "POST", ["name": name, "public_key": publicKey], [201])
        return ((try? Json.object(data)) ?? [:]).str("id")
    }

    public func trustChallenge(_ origin: String, id: String) async throws -> String {
        let data = try await send(origin, "/api/v1/devices/trust/challenge", "POST", ["id": id], [200])
        return ((try? Json.object(data)) ?? [:]).str("challenge")
    }

    public func trustSession(_ origin: String, id: String, challenge: String, signature: String) async throws {
        _ = try await send(origin, "/api/v1/devices/trust/session", "POST", ["id": id, "challenge": challenge, "signature": signature], [201])
    }

    public func trustRemove(_ origin: String, id: String) async throws {
        _ = try await send(origin, "/api/v1/devices/trust/\(Self.part(id))", "DELETE", nil, [204])
    }

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

    private func getJson(_ origin: String, _ path: String) async throws -> JSON { try Json.object(try ResponseLimit.check(try await send(origin, path, "GET", nil, [200]), limit: ResponseLimit.json)) }

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
        try await perform(try request(origin, path, method, body), path, expected)
    }

    private func perform(_ request: URLRequest, _ path: String, _ expected: Set<Int>) async throws -> Data {
        let method = request.httpMethod ?? "GET"
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { DiagnosticLog.shared.record(method: method, path: path, status: 0); throw ArmorApiError(message: error.localizedDescription, status: nil) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        DiagnosticLog.shared.record(method: method, path: path, status: status)
        try ResponseLimit.check(data, limit: ResponseLimit.picture)
        if !expected.contains(status) {
            let text = String(decoding: data.prefix(2000), as: UTF8.self)
            let shown = String(text.prefix(180))
            throw ArmorApiError(message: "Server operation failed (HTTP \(status))" + (shown.isEmpty ? "" : ": \(shown)"), status: status, body: text)
        }
        return data
    }
}
