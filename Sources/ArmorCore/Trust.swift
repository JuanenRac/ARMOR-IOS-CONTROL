// ARMOR-IOS-CONTROL - trust in the certificate of the server: trust on first use of the public key of the installation's certificate authority (or of the server's own certificate), kept per server,
// or a pin that came in a QR code from Studio. The calculation of the hash of a key is done by the app (it needs the system's crypto); the decision is made here, where a test can reach it.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum PinDecision: Equatable, Sendable {
    /// The chain holds a key already pinned for this server.
    case trusted
    /// Nothing is pinned yet and the system already trusts the chain: this pin is kept for next time.
    case firstUse(pin: String)
    /// A pin exists and nothing in the chain matches it: the connection is refused and the person told.
    case mismatch
    /// Nothing is pinned and the system does not trust the chain either (a private certificate authority): the person must pair first (QR or confirming the fingerprint).
    case unknownAuthority(pin: String)
}

/// The pins kept for each server, as the base64 SHA-256 of the public key (SPKI) of a certificate. More than one pin may be kept (a renewed certificate, a backup key).
public final class PinStore {
    private let store: KeyValueStore
    public init(_ store: KeyValueStore) { self.store = store }

    private func key(_ host: String) -> String { "pin_" + host.lowercased() }

    public func pins(for host: String) -> [String] {
        (store.get(key(host)) ?? "").split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    /// Adds a pin; a host keeps at most four, the newest last.
    public func add(_ pin: String, for host: String) {
        let clean = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PinStore.isWellFormed(clean) else { return }
        var list = pins(for: host).filter { $0 != clean }
        list.append(clean)
        store.put(key(host), list.suffix(4).joined(separator: ","))
    }

    public func clear(for host: String) { store.remove(key(host)) }

    /// A SHA-256 in base64 is 44 characters with one "=" at the end.
    public static func isWellFormed(_ pin: String) -> Bool {
        pin.count == 44 && pin.hasSuffix("=") && pin.dropLast().allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" } && pin.allSatisfy(\.isASCII)
    }

    /// Decides about a chain: `chainPins` are the pins of every certificate of the chain, the leaf first; `systemTrusts` is the answer of the system's own evaluation.
    public func decide(host: String, chainPins: [String], systemTrusts: Bool) -> PinDecision {
        let kept = pins(for: host)
        if !kept.isEmpty { return chainPins.contains { kept.contains($0) } ? .trusted : .mismatch }
        guard let first = chainPins.first else { return .mismatch }
        // the key worth pinning is the one of the authority when there is one above the leaf, and the leaf's own when the server stands alone
        let candidate = chainPins.count > 1 ? chainPins[chainPins.count - 1] : first
        return systemTrusts ? .firstUse(pin: candidate) : .unknownAuthority(pin: candidate)
    }

    /// The pin that a QR code of Studio carries: `armor-pin:<base64>` (optionally `armor-pin:<host>:<base64>`); nil for anything else.
    public static func parseQr(_ text: String) -> (host: String?, pin: String)? {
        let prefix = "armor-pin:"
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.hasPrefix(prefix) else { return nil }
        let rest = String(source.dropFirst(prefix.count))
        if isWellFormed(rest) { return (nil, rest) }
        guard let split = rest.lastIndex(of: ":") else { return nil }
        let host = String(rest[rest.startIndex..<split]), pin = String(rest[rest.index(after: split)...])
        return (!host.isEmpty && isWellFormed(pin)) ? (host, pin) : nil
    }
}
