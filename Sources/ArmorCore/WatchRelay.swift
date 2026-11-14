// ARMOR-IOS-CONTROL - the alarms on an Apple Watch: what the phone says to the watch of ARMOR-WATCH and what it does with the confirmation that comes back. Off by default.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
//
// The contract is the one of ARMOR-WATCH (docs/watch_alert_contract.json): four messages (the switch of the relay, an alert, the clear of an alert and the confirmation), a version, limits of size
// and an alert that lives at most ten minutes. It is the same as ARMOR-ANDROID-CONTROL sends to a Wear OS watch; only the carrier differs (WatchConnectivity here). The phone sends only the title and the
// text of a notice the person would see and only while the person turned the option on. The confirmation from the watch is a request, not an order: the phone acts only on an alert it sent a moment
// ago, once, and acknowledges it with its own session.
import Foundation

/// Whatever carries a message to the watch: WatchConnectivity on a phone, a list in a test.
public protocol WatchTransport: AnyObject {
    func send(path: String, payload: String)
}

/// The alerts the phone sent and that the watch may confirm: alert id to the alarm it stands for, for a while, and never more than `capacity`.
public final class SentAlerts {
    public static let capacity = 32

    private struct Entry { let alertId: String; let alarmId: String; let expiresAt: Int64 }

    private let now: () -> Int64
    private let lock = NSLock()
    private var entries: [Entry] = []   // oldest first

    public init(now: @escaping () -> Int64) { self.now = now }

    public func remember(alertId: String, alarmId: String, ttlSeconds: Int) {
        lock.lock(); defer { lock.unlock() }
        entries.removeAll { $0.alertId == alertId }
        entries.append(Entry(alertId: alertId, alarmId: alarmId, expiresAt: now() + Int64(ttlSeconds)))
        while entries.count > Self.capacity { entries.removeFirst() }
    }

    /// The alarm of `alertId` when the phone sent it and it has not expired; one confirmation only (the entry is used up).
    public func take(_ alertId: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let index = entries.firstIndex(where: { $0.alertId == alertId }) else { return nil }
        let entry = entries.remove(at: index)
        return entry.expiresAt > now() ? entry.alarmId : nil
    }
}

public enum WatchRelay {
    public static let protocolVersion = 1
    public static let pathToWatch = "/armor/alert"
    public static let pathToPhone = "/armor/alert/ack"
    public static let titleMax = 60
    public static let textMax = 160
    public static let criticalTtlSeconds = 600
    public static let otherTtlSeconds = 120

    private static let idMax = 64
    private static let enabledKey = "watch_relay"

    /// The alerts that can still be confirmed from the watch.
    public static let sent = SentAlerts { Int64(Date().timeIntervalSince1970) }

    public static func enabled(_ store: KeyValueStore) -> Bool { store.get(enabledKey) == "true" }
    public static func setEnabled(_ store: KeyValueStore, _ on: Bool) { store.put(enabledKey, String(on)) }

    public static func severity(of severity: String) -> String {
        switch severity {
        case "critical": return "critical"
        case "high": return "warning"
        default: return "info"
        }
    }

    private static func ttl(of notice: AlarmNotice) -> Int { notice.severity == "critical" ? criticalTtlSeconds : otherTtlSeconds }

    public static func validId(_ id: String) -> Bool {
        !id.isEmpty && id.utf16.count <= idMax && id.unicodeScalars.allSatisfy { ($0.value >= 48 && $0.value <= 57) || ($0.value >= 65 && $0.value <= 90) || ($0.value >= 97 && $0.value <= 122) || $0 == "_" || $0 == "-" }
    }

    /// The id of the alert: the alarm the notice tells about, or a number of the notice.
    public static func alertId(of notice: AlarmNotice) -> String {
        if let alarm = notice.alarmId, validId(alarm) { return alarm }
        return "n\(max(notice.id, 0))"
    }

    private static func json(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }

    public static func relayMessage(_ on: Bool) -> String { json(["type": "relay", "protocolVersion": protocolVersion, "enabled": on]) }

    public static func clearMessage(_ alertId: String) -> String { json(["type": "alert_clear", "protocolVersion": protocolVersion, "alertId": alertId]) }

    /// The alert message of a notice, or nil when it has nothing to say (the watch refuses an empty title or text).
    public static func alertMessage(_ notice: AlarmNotice) -> String? {
        let title = String(notice.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(titleMax))
        let text = String(notice.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(textMax))
        if title.isEmpty || text.isEmpty { return nil }
        let needsAck = notice.alarmId.map(validId) ?? false
        return json(["type": "alert", "protocolVersion": protocolVersion, "alertId": alertId(of: notice), "severity": severity(of: notice.severity), "title": title, "text": text, "needsAck": needsAck, "ttlSeconds": ttl(of: notice)])
    }

    /// What to send for a notice, in order: the relay switch (a watch that started again is off until the phone says otherwise) and the alert; empty when the option is off or the notice says nothing.
    /// The alert is remembered, when it can be confirmed.
    public static func messages(for notice: AlarmNotice, enabled: Bool) -> [String] {
        guard enabled, let alert = alertMessage(notice) else { return [] }
        if let alarm = notice.alarmId, validId(alarm) { sent.remember(alertId: alertId(of: notice), alarmId: alarm, ttlSeconds: ttl(of: notice)) }
        return [relayMessage(true), alert]
    }

    /// The alert id of a confirmation from the watch, or nil when the text is not one (strict: the type, the version and nothing else that is not expected).
    private struct Ack: Decodable {
        let type: String
        let protocolVersion: Int
        let alertId: String
    }

    public static func parseAck(_ text: String) -> String? {
        guard text.utf16.count <= 512, let data = text.data(using: .utf8), let ack = try? JSONDecoder().decode(Ack.self, from: data),
              ack.type == "alert_ack", ack.protocolVersion == protocolVersion, validId(ack.alertId) else { return nil }
        return ack.alertId
    }

    /// What the phone does with a confirmation that came from the watch: the alert id and the alarm to acknowledge, once, or nil (not enabled, an alert the phone did not send, one that expired or one already used).
    public static func alarmToAcknowledge(enabled: Bool, text: String) -> (alertId: String, alarmId: String)? {
        guard enabled, let alertId = parseAck(text), let alarm = sent.take(alertId) else { return nil }
        return (alertId, alarm)
    }
}
