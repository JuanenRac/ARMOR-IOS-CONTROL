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
    func streamTicket(_ origin: String, cameraId: String) async throws -> String
    func snapshot(_ origin: String, cameraId: String) async throws
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
}
