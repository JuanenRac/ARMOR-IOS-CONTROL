// ARMOR-IOS-CONTROL - what the app asks of ARMOR-SERVER, as a protocol: the screens depend on this, the HTTP client is one implementation, a test can be another.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public struct SessionCookie: Equatable, Sendable {
    public let name: String
    public let value: String
    public init(name: String, value: String) { self.name = name; self.value = value }
}

public protocol ArmorApi: Sendable {
    func status(_ origin: String) async throws -> ArmorSnapshot
    /// The newest events first; `before` is an event id (only older events are returned). With `after` the events that came after that id, oldest first.
    func history(_ origin: String, limit: Int, before: Int?, after: Int?) async throws -> [ArmorEvent]
    func preflight(_ origin: String) async throws -> Preflight
    /// Arm or disarm the whole system; the server audits it with the signed-in user's name. Disarming carries the PIN of the user when there is one.
    func setMode(_ origin: String, mode: String, pin: String?) async throws
    /// The arming modes of the server (Away, Home, Night); an older server has no such route and the call fails.
    func armingModes(_ origin: String) async throws -> ArmingModesView
    /// Arms in a mode ("away", "home" or "night"). A mode that defends nothing is refused (code `no_zones_assigned`) unless `confirmUnassigned`; a change to a mode that defends less than the
    /// current one needs the PIN like a disarm (codes `wrong_pin`, `pin_locked`, `pin_not_set`).
    func setArmingMode(_ origin: String, mode: String, pin: String?, confirmUnassigned: Bool) async throws
    /// Active alarms first (raised and not yet cleared, or cleared but waiting for a person), then the closed record.
    func alarms(_ origin: String) async throws -> (active: [Alarm], recent: [Alarm])
    func acknowledgeAlarm(_ origin: String, id: String) async throws
    func acknowledgeAllAlarms(_ origin: String) async throws
    func alarmPanels(_ origin: String) async throws -> [AlarmPanelView]
    func armProfiles(_ origin: String) async throws -> [ArmProfileView]
    func alarmCommandsEnabled(_ origin: String) async throws -> Bool
    /// Arms a panel (mode "away" or "stay") or disarms it (mode nil, with the PIN when there is one). The server checks the PIN and never sends it to the node.
    func sendAlarmCommand(_ origin: String, node: String, mode: String?, force: Bool, pin: String?, profile: String?) async throws
    /// Silences the siren of a panel with the system still armed (the alarm stays latched).
    func silenceAlarmSiren(_ origin: String, node: String, pin: String?) async throws
    func devices(_ origin: String) async throws -> [SiteDevice]
    /// `command` is "on", "off" or "toggle"; the server refuses it for a sensor.
    func commandDevice(_ origin: String, id: String, command: String, confirm: Bool) async throws
    func cameraViews(_ origin: String) async throws -> [CameraView]
    func cameraStatus(_ origin: String) async throws -> [CameraHealth]
    /// A ticket to watch one camera; the address to open is the origin plus the path the server gives.
    /// `quality` is what the app asks for explicitly: "low" (the lighter picture), "normal" or "auto" (the server decides by where the person came from).
    func streamTicket(_ origin: String, cameraId: String, quality: String) async throws -> String
    func snapshot(_ origin: String, cameraId: String) async throws
    /// The photos and videos the cameras made, newest first as the server lists them, and the cameras recording right now.
    func media(_ origin: String) async throws -> MediaCatalogueView
    /// Deletes one file of the library from the server (it cannot be undone); the server refuses a viewer.
    func deleteMedia(_ origin: String, item: MediaItemView) async throws
    /// Takes one file of the library to a temporary file of the phone, to be shown; a file longer than `EvidenceParser.largestFile` is refused. The caller deletes the file when it is done.
    func mediaFile(_ origin: String, item: MediaItemView) async throws -> URL
    func ptz(_ origin: String, cameraId: String, command: String) async throws
    func voiceAvailable(_ origin: String) async throws -> Bool
    /// One written command; arming and disarming need a second turn: send the same phrase again with the token of the first answer.
    func voiceCommand(_ origin: String, text: String, language: String, confirmation: String?) async throws -> VoiceReply

    // session
    func signIn(_ origin: String, username: String, password: String) async throws -> SignIn
    func completeSignIn(_ origin: String, challenge: String, code: String) async throws
    func sessionFacts(_ origin: String) async throws -> SessionFacts
    func closeSession(_ origin: String) async throws
    /// A new proof of identity (the password, or a code of the app), good for a few minutes for the critical actions.
    func elevate(_ origin: String, password: String, code: String) async throws
    /// The server's session cookie as it stands now (it is renewed while in use), to keep between launches; nil when there is none.
    func sessionCookie(_ origin: String) -> SessionCookie?
    func restoreSessionCookie(_ origin: String, _ cookie: SessionCookie)
    func forgetSession(_ origin: String)
    /// Tells the server the token APNs gave this phone, so it can push alarms to it (a server with push off answers 409, which is not a failure of the app).
    func registerPush(_ origin: String, token: String) async throws
    func unregisterPush(_ origin: String, token: String) async throws

    // reports, solar, electrical and battery maintenance (declared here, not only in the extension below, so a call through the protocol reaches the real client)
    /// The summary of a day in a language, for administrators and operators; the server refuses (404 off, 403 role, 503 not set up...) with a code that `ReportRefusal` turns into words.
    func dailySummary(_ origin: String, date: String, language: String) async throws -> DailySummaryView
    /// The activity heat map of a camera (the only one when `camera` is nil) with its picture.
    func heatmap(_ origin: String, camera: String?) async throws -> HeatmapView
    /// Every inverter and battery that has reported, the declared ones still waiting, and the sums; an operator session is needed.
    func solar(_ origin: String) async throws -> SolarOverview
    /// The meters of the electrical nodes and the sums.
    func electrical(_ origin: String) async throws -> ElectricalOverview
    /// The battery operations of the last weeks, newest first, and whether the server lets anything be written at all; an administrator's.
    func batteryOperations(_ origin: String) async throws -> BatteryOverview
    /// Step one of writing to a battery: the server asks the node to read it and check everything; the answer is the operation, still being checked. The typed serial number must be the battery's.
    func batteryArm(_ origin: String, node: String, port: Int, op: String, output: String?, state: String?, serial: String) async throws -> BatteryOperationView
    func batteryOperation(_ origin: String, id: String) async throws -> BatteryOperationView
    /// Step two: writes it, with the serial number typed again.
    func batteryExecute(_ origin: String, id: String, serial: String) async throws -> BatteryOperationView
    func batteryCancel(_ origin: String, id: String) async throws -> BatteryOperationView
    /// The local network as the network nodes see it.
    func network(_ origin: String) async throws -> NetworkOverview
    /// Asks the network node to sweep the network now, for the node finder.
    func scanNetworkNow(_ origin: String) async throws
    /// Every service of the system, running or not.
    func services(_ origin: String) async throws -> ServicesOverview
    /// The health report of every node, with the warnings the server raised about each (an operator session is needed).
    func nodeHealth(_ origin: String) async throws -> NodeHealthOverview
    /// Every device and app the server has seen (the Connections list of the history); the addresses come only for an administrator.
    func connections(_ origin: String) async throws -> [ConnectionClient]
    /// The site as Studio designed it (terrain, buildings, radars, cameras); nil when no design has been saved yet.
    func site(_ origin: String) async throws -> SiteDesign?
    /// Forgets a node that was taken away, with its health warnings (an administrator only; a node the server no longer knows is not a failure).
    func forgetNode(_ origin: String, id: String) async throws
    /// Gives one order (restart, pause, resume, standby, identify, diagnostics, maintenance_on, maintenance_off) to one node; an administrator who proved themselves a moment ago. `confirm` is the node's name where it is asked.
    func nodeControl(_ origin: String, nodeId: String, operation: String, confirm: String?, durationS: Int?) async throws -> ControlOperationView
    /// The same order to every node that reports; `mode` is "now" or "rolling" (only a restart can be rolling); `confirm` is the word RESTART, PAUSE or STANDBY where it is asked.
    func nodesControl(_ origin: String, operation: String, mode: String, confirm: String?, durationS: Int?) async throws -> ControlOperationView
    /// The orders of the last weeks with a line per node; never a token.
    func nodeControlOperations(_ origin: String) async throws -> [ControlOperationView]
    func nodeControlOperation(_ origin: String, id: String) async throws -> ControlOperationView
    /// Whether updating the programs of the machine from the phone is switched on (here and on the maintenance helper) and which programs can be updated; an administrator.
    func machineUpdateState(_ origin: String) async throws -> MachineUpdateState
    /// Step one: what is installed against the newest release of `project`; nothing changes. When an update is available the answer carries a plan that is good once and for a few minutes.
    func machineUpdatePreview(_ origin: String, project: String) async throws -> MachineUpdatePreview
    /// Step two: updates `project` with the plan of its preview; `confirm` is the name typed again, `code` the one-time code of the administrator when there is one (passed on, never kept). Returns the id of the job.
    func machineUpdateApply(_ origin: String, project: String, planId: String, confirm: String, code: String?) async throws -> String
    /// The steps, percentage and log of the job an apply started, from the log line `since` on.
    func machineUpdateJob(_ origin: String, id: String, since: Int) async throws -> MachineJobView
    /// The open sessions of the signed-in account, this one marked.
    func mySessions(_ origin: String) async throws -> [SessionInfo]
    func endSession(_ origin: String, id: String) async throws
    func endOtherSessions(_ origin: String) async throws
    /// The state of the second factor of the account.
    func totpState(_ origin: String) async throws -> TotpInfo
    /// Starts the second factor (the password confirms who asks): the key and the address to add to the authenticator.
    func totpSetup(_ origin: String, password: String) async throws -> TotpSetup
    /// Confirms it with the first code; the answer is the recovery codes, shown once.
    func totpEnable(_ origin: String, code: String) async throws -> [String]
    func totpDisable(_ origin: String, password: String) async throws
    /// How the server sees this phone: its address and whether it comes from outside the house.
    func remoteCheck(_ origin: String) async throws -> RemoteInfo
    /// The way in from outside the house (administrators): the VPN and the dynamic address, as the maintenance helper reports them.
    func remoteSetup(_ origin: String) async throws -> RemoteSetup
    func vpnSetup(_ origin: String, endpoint: String, port: Int, lan: String, routeLan: String) async throws -> RemoteSetup
    /// Adds a device; the answer holds its private key, to be shown once.
    func vpnAddPeer(_ origin: String, name: String, fullTunnel: Bool) async throws -> PeerConfig
    func vpnShowPeer(_ origin: String, name: String) async throws -> PeerConfig
    func vpnRemovePeer(_ origin: String, name: String) async throws
    func ddnsSetup(_ origin: String, provider: String, domain: String, token: String, zone: String, record: String, url: String) async throws -> RemoteSetup
    func ddnsUpdate(_ origin: String) async throws -> RemoteSetup
    func ddnsRemove(_ origin: String) async throws -> RemoteSetup
}

extension ArmorApi {
    func media(_ origin: String) async throws -> MediaCatalogueView { throw ArmorApiError(message: "not supported", status: nil) }
    func deleteMedia(_ origin: String, item: MediaItemView) async throws { throw ArmorApiError(message: "not supported", status: nil) }
    func mediaFile(_ origin: String, item: MediaItemView) async throws -> URL { throw ArmorApiError(message: "not supported", status: nil) }
    func dailySummary(_ origin: String, date: String, language: String) async throws -> DailySummaryView { throw ArmorApiError(message: "not supported", status: nil) }
    func heatmap(_ origin: String, camera: String?) async throws -> HeatmapView { throw ArmorApiError(message: "not supported", status: nil) }
    func solar(_ origin: String) async throws -> SolarOverview { throw ArmorApiError(message: "not supported", status: nil) }
    func electrical(_ origin: String) async throws -> ElectricalOverview { throw ArmorApiError(message: "not supported", status: nil) }
    func batteryOperations(_ origin: String) async throws -> BatteryOverview { throw ArmorApiError(message: "not supported", status: nil) }
    func batteryArm(_ origin: String, node: String, port: Int, op: String, output: String?, state: String?, serial: String) async throws -> BatteryOperationView { throw ArmorApiError(message: "not supported", status: nil) }
    func batteryOperation(_ origin: String, id: String) async throws -> BatteryOperationView { throw ArmorApiError(message: "not supported", status: nil) }
    func batteryExecute(_ origin: String, id: String, serial: String) async throws -> BatteryOperationView { throw ArmorApiError(message: "not supported", status: nil) }
    func batteryCancel(_ origin: String, id: String) async throws -> BatteryOperationView { throw ArmorApiError(message: "not supported", status: nil) }
    func network(_ origin: String) async throws -> NetworkOverview { throw ArmorApiError(message: "not supported", status: nil) }
    func scanNetworkNow(_ origin: String) async throws { throw ArmorApiError(message: "not supported", status: nil) }
    func services(_ origin: String) async throws -> ServicesOverview { throw ArmorApiError(message: "not supported", status: nil) }
    func nodeHealth(_ origin: String) async throws -> NodeHealthOverview { throw ArmorApiError(message: "not supported", status: nil) }
    func connections(_ origin: String) async throws -> [ConnectionClient] { throw ArmorApiError(message: "not supported", status: nil) }
    func site(_ origin: String) async throws -> SiteDesign? { throw ArmorApiError(message: "not supported", status: nil) }
    func forgetNode(_ origin: String, id: String) async throws { throw ArmorApiError(message: "not supported", status: nil) }
    func nodeControl(_ origin: String, nodeId: String, operation: String, confirm: String?, durationS: Int?) async throws -> ControlOperationView { throw ArmorApiError(message: "not supported", status: nil) }
    func nodesControl(_ origin: String, operation: String, mode: String, confirm: String?, durationS: Int?) async throws -> ControlOperationView { throw ArmorApiError(message: "not supported", status: nil) }
    func nodeControlOperations(_ origin: String) async throws -> [ControlOperationView] { throw ArmorApiError(message: "not supported", status: nil) }
    func nodeControlOperation(_ origin: String, id: String) async throws -> ControlOperationView { throw ArmorApiError(message: "not supported", status: nil) }
    func machineUpdateState(_ origin: String) async throws -> MachineUpdateState { throw ArmorApiError(message: "not supported", status: nil) }
    func machineUpdatePreview(_ origin: String, project: String) async throws -> MachineUpdatePreview { throw ArmorApiError(message: "not supported", status: nil) }
    func machineUpdateApply(_ origin: String, project: String, planId: String, confirm: String, code: String?) async throws -> String { throw ArmorApiError(message: "not supported", status: nil) }
    func machineUpdateJob(_ origin: String, id: String, since: Int) async throws -> MachineJobView { throw ArmorApiError(message: "not supported", status: nil) }
    func mySessions(_ origin: String) async throws -> [SessionInfo] { throw ArmorApiError(message: "not supported", status: nil) }
    func endSession(_ origin: String, id: String) async throws { throw ArmorApiError(message: "not supported", status: nil) }
    func endOtherSessions(_ origin: String) async throws { throw ArmorApiError(message: "not supported", status: nil) }
    func totpState(_ origin: String) async throws -> TotpInfo { throw ArmorApiError(message: "not supported", status: nil) }
    func totpSetup(_ origin: String, password: String) async throws -> TotpSetup { throw ArmorApiError(message: "not supported", status: nil) }
    func totpEnable(_ origin: String, code: String) async throws -> [String] { throw ArmorApiError(message: "not supported", status: nil) }
    func totpDisable(_ origin: String, password: String) async throws { throw ArmorApiError(message: "not supported", status: nil) }
    func remoteCheck(_ origin: String) async throws -> RemoteInfo { throw ArmorApiError(message: "not supported", status: nil) }
    func remoteSetup(_ origin: String) async throws -> RemoteSetup { throw ArmorApiError(message: "not supported", status: nil) }
    func vpnSetup(_ origin: String, endpoint: String, port: Int, lan: String, routeLan: String) async throws -> RemoteSetup { throw ArmorApiError(message: "not supported", status: nil) }
    func vpnAddPeer(_ origin: String, name: String, fullTunnel: Bool) async throws -> PeerConfig { throw ArmorApiError(message: "not supported", status: nil) }
    func vpnShowPeer(_ origin: String, name: String) async throws -> PeerConfig { throw ArmorApiError(message: "not supported", status: nil) }
    func vpnRemovePeer(_ origin: String, name: String) async throws { throw ArmorApiError(message: "not supported", status: nil) }
    func ddnsSetup(_ origin: String, provider: String, domain: String, token: String, zone: String, record: String, url: String) async throws -> RemoteSetup { throw ArmorApiError(message: "not supported", status: nil) }
    func ddnsUpdate(_ origin: String) async throws -> RemoteSetup { throw ArmorApiError(message: "not supported", status: nil) }
    func ddnsRemove(_ origin: String) async throws -> RemoteSetup { throw ArmorApiError(message: "not supported", status: nil) }

    /// A ticket with the quality left to the server.
    func streamTicket(_ origin: String, cameraId: String) async throws -> String {
        try await streamTicket(origin, cameraId: cameraId, quality: "auto")
    }
}

/// The picture quality the app asks the server for when it opens a camera.
public enum CameraQuality {
    public static let accepted: Set<String> = ["low", "normal", "auto"]

    /// A tile of the grid asks for the lighter picture from outside the house and the normal one at home; the full view lets the server decide ("auto") because the person came to look closely.
    public static func requested(away: Bool, tile: Bool) -> String { tile ? (away ? "low" : "normal") : "auto" }
}
