// ARMOR-IOS-CONTROL - the report a person can share with whoever helps them: what the app is, what the phone allows it, and the last answers the server gave, with no secret in it.
// The same report as the Android app writes (DiagnosticReport.kt). Nothing here leaves the phone by itself: the person chooses the button and then the app to send it with. It holds no
// password, token, PIN, cookie, address with a sign-in, camera name or message text.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The last answers of the server, kept in memory only (never written to disk): the shape of the route and the status, nothing of the request or the answer.
public final class DiagnosticLog: @unchecked Sendable {
    public struct Entry: Equatable, Sendable {
        public let atMs: Int64, method: String, route: String, status: Int
        public init(atMs: Int64, method: String, route: String, status: Int) { self.atMs = atMs; self.method = method; self.route = route; self.status = status }
    }
    public static let shared = DiagnosticLog()
    private static let keep = 25
    private let lock = NSLock()
    private var entries: [Entry] = []

    public init() {}

    /// A route reduced to its first four parts with no query: "/api/v1/cameras/gate/snapshot?ticket=x" is "/api/v1/cameras/gate/…".
    public static func shape(_ path: String) -> String {
        let bare = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let noFragment = bare.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let parts = noFragment.split(separator: "/").map(String.init)
        if parts.isEmpty { return "/" }
        return "/" + parts.prefix(4).joined(separator: "/") + (parts.count > 4 ? "/…" : "")
    }

    /// The route of the hidden panic gesture: it leaves no trace in the report that a person may share, or that somebody looking over the shoulder may read.
    private static let quietRoute = "/panic-gesture"

    public func record(method: String, path: String, status: Int, atMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        if (path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "").hasSuffix(Self.quietRoute) { return }
        lock.lock(); defer { lock.unlock() }
        if entries.count >= Self.keep { entries.removeFirst() }
        entries.append(Entry(atMs: atMs, method: String(method.prefix(8)), route: Self.shape(path), status: status))
    }

    public func recent() -> [Entry] { lock.lock(); defer { lock.unlock() }; return entries }
    public func clear() { lock.lock(); defer { lock.unlock() }; entries.removeAll() }
}

/// What the report says, gathered by the screen and kept apart from the text so that the text can be tested.
public struct DiagnosticInfo: Sendable {
    public var appVersion: String, appBuild: String, systemVersion: String, device: String, language: String, origin: String, role: String
    public var notificationsAllowed: Bool?, recent: [DiagnosticLog.Entry], nowMs: Int64
    public init(appVersion: String, appBuild: String, systemVersion: String, device: String, language: String, origin: String, role: String, notificationsAllowed: Bool?, recent: [DiagnosticLog.Entry], nowMs: Int64) {
        self.appVersion = appVersion; self.appBuild = appBuild; self.systemVersion = systemVersion; self.device = device; self.language = language
        self.origin = origin; self.role = role; self.notificationsAllowed = notificationsAllowed; self.recent = recent; self.nowMs = nowMs
    }
}

public enum DiagnosticReport {
    /// The address as "scheme://host" (no port, path, query or sign-in), or "not set".
    public static func originLabel(_ origin: String) -> String {
        guard let parts = URLComponents(string: origin.trimmingCharacters(in: .whitespaces)), let scheme = parts.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let host = parts.host, !host.isEmpty else { return "not set" }
        return "\(scheme)://\(host)"
    }

    private static func yesNo(_ value: Bool?) -> String { value.map { $0 ? "yes" : "no" } ?? "unknown" }

    public static func render(_ info: DiagnosticInfo) -> String {
        var lines = [
            "A.R.M.O.R. diagnostic report",
            "App: \(info.appVersion) (build \(info.appBuild))",
            "iOS: \(info.systemVersion)",
            "Device: \(info.device)",
            "Language: \(info.language)",
            "Server: \(originLabel(info.origin))",
            "Role: \(info.role.isEmpty ? "not signed in" : info.role)",
            "Notifications allowed: \(yesNo(info.notificationsAllowed))",
            "Battery optimisation off for the app: unknown",   // not a thing on iOS; the line keeps the report the same as the Android one
            "Alarm watcher on: unknown",                       // the watcher service is Android's; iOS gets its alarms through push
            "Last answers of the server (newest last):",
        ]
        if info.recent.isEmpty { lines.append("  none yet") }
        for entry in info.recent {
            let ago = max(0, info.nowMs - entry.atMs) / 1000
            lines.append("  \(entry.method) \(entry.route) -> \(entry.status > 0 ? String(entry.status) : "no answer") (\(ago)s ago)")
        }
        lines.append("No password, token, PIN or message text is in this report.")
        return lines.joined(separator: "\n")
    }
}
