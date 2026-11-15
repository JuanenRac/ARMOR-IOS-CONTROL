import Foundation
@testable import ArmorCore

/// A twin of the Apple Watch (and of the Wear OS one: the contract is the same) for the tests. It stands where WatchConnectivity stands: the phone sends it the messages of `WatchRelay`, it
/// checks each against the contract of ARMOR-WATCH the way the real watch does, keeps the alerts for their time to live on a clock of the test, and gives back the confirmation a tap would make.
/// The link can be cut: a message sent then is lost (the messages are live ones and are not queued), as with a watch out of range.
final class SimulatedWatch: WatchTransport {
    struct ShownAlert: Equatable {
        let alertId: String
        let severity: String
        let title: String
        let text: String
        let needsAck: Bool
        let expiresAt: Int
    }

    /// The seconds of the test; the tests move it by hand.
    var clock = 0
    var linkUp = true
    private(set) var relayOn = false
    private(set) var rejected: [String] = []
    private(set) var lost = 0
    private(set) var received: [String] = []
    private var alerts: [ShownAlert] = []

    private static let severities: Set<String> = ["info", "warning", "critical"]

    func send(path: String, payload: String) {
        guard linkUp else { lost += 1; return }
        guard path == WatchRelay.pathToWatch else { rejected.append("path"); return }
        received.append(payload)
        guard let data = payload.data(using: .utf8), let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              json["protocolVersion"] as? Int == WatchRelay.protocolVersion, let type = json["type"] as? String else { rejected.append("shape"); return }
        switch type {
        case "relay":
            guard let enabled = json["enabled"] as? Bool else { rejected.append("relay"); return }
            relayOn = enabled
            if !enabled { alerts = [] }   // the watch forgets what it showed when the option goes off
        case "alert_clear":
            guard let id = json["alertId"] as? String, WatchRelay.validId(id) else { rejected.append("clear"); return }
            alerts.removeAll { $0.alertId == id }
        case "alert":
            guard relayOn, let id = json["alertId"] as? String, WatchRelay.validId(id), let severity = json["severity"] as? String, Self.severities.contains(severity),
                  let title = json["title"] as? String, let text = json["text"] as? String, !title.isEmpty, !text.isEmpty,
                  title.count <= WatchRelay.titleMax, text.count <= WatchRelay.textMax, let ack = json["needsAck"] as? Bool,
                  let ttl = json["ttlSeconds"] as? Int, ttl > 0, ttl <= WatchRelay.criticalTtlSeconds else { rejected.append("alert"); return }
            alerts.removeAll { $0.alertId == id }
            alerts.append(ShownAlert(alertId: id, severity: severity, title: title, text: text, needsAck: ack, expiresAt: clock + ttl))
        default:
            rejected.append("type")
        }
    }

    /// What the screen of the watch shows now: the alerts that did not expire, the worst first, and no more than the watch keeps.
    var shown: [ShownAlert] {
        let rank = ["critical": 0, "warning": 1, "info": 2]
        return alerts.filter { $0.expiresAt > clock }.sorted { (rank[$0.severity] ?? 3, $0.expiresAt) < (rank[$1.severity] ?? 3, $1.expiresAt) }
    }

    /// The confirmation a tap on the alert makes, or nil when there is nothing to tap (not shown, expired, or an alert that asks for no confirmation).
    func tap(_ alertId: String) -> String? {
        guard linkUp, let alert = shown.first(where: { $0.alertId == alertId }), alert.needsAck else { return nil }
        return "{\"alertId\":\"\(alertId)\",\"protocolVersion\":\(WatchRelay.protocolVersion),\"type\":\"alert_ack\"}"
    }
}
