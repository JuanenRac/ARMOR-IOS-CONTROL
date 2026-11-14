// ARMOR-IOS-CONTROL - the Apple Watch: WatchConnectivity on the iPhone. It carries the messages of WatchRelay (ArmorCore) to the watch and takes back the confirmation.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
//
// Used only while the option of the watch is on (off by default). Messages are live ones: an alert is sent only when the watch can be reached now, never queued, so an old alert does not turn up later.
// The same carrier of the Wear OS side is the Data Layer; the contract and the rules are the same (ArmorCore/WatchRelay.swift). Nothing here has run with a real watch.
import ArmorCore
import Foundation
import WatchConnectivity

final class WatchConnectivityRelay: NSObject, WatchTransport, WCSessionDelegate {
    static let shared = WatchConnectivityRelay()

    /// Whether the option of the watch is on (set by the model; read when a confirmation arrives).
    var isEnabled = false
    /// Acknowledges an alarm with the session of the phone; true when the server took it.
    var acknowledge: ((String) async -> Bool)?

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(path: String, payload: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled, session.isReachable else { return }
        session.sendMessage(["path": path, "text": payload], replyHandler: nil, errorHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    /// The confirmation of the watch: a request, acted on only for an alert the phone sent a moment ago, once, with the session the phone keeps; then the watch is told the alert is over.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["path"] as? String == WatchRelay.pathToPhone, let text = message["text"] as? String,
              let found = WatchRelay.alarmToAcknowledge(enabled: isEnabled, text: text) else { return }
        Task {
            if await acknowledge?(found.alarmId) == true {
                send(path: WatchRelay.pathToWatch, payload: WatchRelay.clearMessage(found.alertId))
            } else {
                WatchRelay.sent.remember(alertId: found.alertId, alarmId: found.alarmId, ttlSeconds: WatchRelay.otherTtlSeconds)   // the server did not take it: the watch may ask again
            }
        }
    }
}
