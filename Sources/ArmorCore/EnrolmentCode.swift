// ARMOR-IOS-CONTROL - the text of the QR code that sets up the app (made by Studio): the address of the installation, the fingerprint of its local authority and a code of one use that lives
// five minutes. It holds no password and opens no session: the person still types their user and password.
//   armor-enrol:{"ca":"<64 hex or empty>","code":"<base64url>","origin":"https://host[:port]","v":1}
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// What the code holds; `caFingerprint` is empty when the server names no authority.
public struct Enrolment: Equatable, Sendable {
    public let origin: String
    public let code: String
    public let caFingerprint: String
    public init(origin: String, code: String, caFingerprint: String) { self.origin = origin; self.code = code; self.caFingerprint = caFingerprint }
}

/// What the server says about itself when asked with the code: the same two facts, which must agree with the code.
public struct EnrolmentFacts: Equatable, Sendable {
    public let origin: String
    public let caFingerprint: String
    public init(origin: String, caFingerprint: String) { self.origin = origin; self.caFingerprint = caFingerprint }
}

public enum EnrolmentCode {
    public static let prefix = "armor-enrol"
    public static let version = 1
    private static let maxText = 300

    private static func isCode(_ text: String) -> Bool {
        (16...64).contains(text.count) && text.unicodeScalars.allSatisfy { ($0 >= "A" && $0 <= "Z") || ($0 >= "a" && $0 <= "z") || ($0 >= "0" && $0 <= "9") || $0 == "_" || $0 == "-" }
    }

    private static func isFingerprint(_ text: String) -> Bool {
        text.count == 64 && text.unicodeScalars.allSatisfy { ($0 >= "0" && $0 <= "9") || ($0 >= "a" && $0 <= "f") }
    }

    /// The https address as the code holds it (scheme, host and port only), or nil when it is anything else.
    public static func cleanOrigin(_ value: String) -> String? {
        guard !value.isEmpty, value.count <= 200, !value.unicodeScalars.contains(where: { $0.value < 33 || $0.value == 127 }) else { return nil }
        guard let parts = URLComponents(string: value), parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty else { return nil }
        guard parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil, parts.path.isEmpty || parts.path == "/" else { return nil }
        if let port = parts.port, !(1...65535).contains(port) { return nil }
        return "https://\(host)" + (parts.port.map { ":\($0)" } ?? "")
    }

    /// Reads the text of a scanned code; nil when it is not exactly what Studio writes.
    public static func parse(_ text: String?) -> Enrolment? {
        guard let text, text.hasPrefix(prefix + ":"), text.count <= maxText else { return nil }
        let body = String(text.dropFirst(prefix.count + 1))
        guard let data = body.data(using: .utf8), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        guard Set(object.keys) == ["ca", "code", "origin", "v"] else { return nil }
        guard body.range(of: #""v"\s*:\s*(true|false)"#, options: .regularExpression) == nil, let number = object["v"] as? NSNumber, number.intValue == version else { return nil }
        guard let origin = (object["origin"] as? String).flatMap(cleanOrigin), let code = object["code"] as? String, isCode(code), let ca = object["ca"] as? String else { return nil }
        guard ca.isEmpty || isFingerprint(ca) else { return nil }
        return Enrolment(origin: origin, code: code, caFingerprint: ca)
    }

    /// The facts in an answer of the server, or nil when it is not one.
    public static func parseFacts(_ data: Data) -> EnrolmentFacts? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let origin = (object["origin"] as? String).flatMap(cleanOrigin) else { return nil }
        if object["ca_fingerprint"] is NSNull || object["ca_fingerprint"] == nil { return EnrolmentFacts(origin: origin, caFingerprint: "") }
        guard let ca = object["ca_fingerprint"] as? String else { return nil }
        return EnrolmentFacts(origin: origin, caFingerprint: ca)
    }

    /// True when what the server says is what the code says: the same address and the same fingerprint.
    public static func agrees(_ code: Enrolment, _ facts: EnrolmentFacts) -> Bool { facts.origin == code.origin && facts.caFingerprint == code.caFingerprint }
}

/// Reads, once, the public facts of an installation with the code of a set-up QR (`GET /api/v1/enrolment/{code}`). Nothing secret travels either way.
public final class EnrolmentReader: @unchecked Sendable {
    private let session: URLSession
    public init(session: URLSession) { self.session = session }

    /// The facts, or nil when the code is unknown, used or ended (404).
    public func read(_ code: Enrolment) async throws -> EnrolmentFacts? {
        guard let url = URL(string: code.origin + "/api/v1/enrolment/" + code.code) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard status == 200, data.count <= 4096 else { throw ArmorApiError(message: "Server operation failed (HTTP \(status))", status: status) }
        return EnrolmentCode.parseFacts(data)
    }
}
