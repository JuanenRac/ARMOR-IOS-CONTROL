// ARMOR-IOS-CONTROL - trust in the certificate of the server: trust on first use of the public key of the installation's certificate authority (or of the server's own certificate), kept per server,
// or a pin that came in a QR code from Studio. The calculation of the hash of a key is done by the app (it needs the system's crypto); the decision is made here, where a test can reach it.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The answer of the chain and certificate check that follows a matching pin.
public enum StrictVerdict: Equatable, Sendable {
    /// The switch is off: the pin alone decides.
    case off
    /// The chain leads to the certificate kept at pairing time.
    case verified
    /// A pairing made before certificates were kept: accepted, with a notice in the app.
    case legacy
    /// A new pairing whose certificate was not kept yet (a pasted QR code): the matching one is kept now.
    case capture
    /// The pin matched but the chain does not lead to the kept certificate.
    case broken
}

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

/// Once a server has been reached over https, plain http to the same host is refused: a downgrade would send the password in the clear to whoever answers at that address. Forgotten when the
/// person changes the address in the settings or forgets the kept certificates. The same key and rule as the Android app (`https_seen_<host>`); on unless the person turns it off.
public final class SchemeMemory {
    public static let switchKey = "scheme_memory"
    private let store: KeyValueStore
    public init(_ store: KeyValueStore) { self.store = store }

    public var enabled: Bool {
        get { store.get(SchemeMemory.switchKey) != "0" }
        set { store.put(SchemeMemory.switchKey, newValue ? "1" : "0") }
    }

    private func key(_ host: String) -> String { "https_seen_" + host.lowercased() }

    /// Remembers that the host of `url` answered over https; anything else is ignored.
    public func reached(_ url: URL) {
        guard url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else { return }
        store.put(key(host), "1")
    }

    public func forget(host: String) { store.remove(key(host)) }

    /// False when `url` is plain http to a host that has been seen over https (and the switch is on).
    public func allows(_ url: URL) -> Bool {
        guard enabled, url.scheme?.lowercased() == "http", let host = url.host else { return true }
        return store.get(key(host)) != "1"
    }

    public func allows(origin: String) -> Bool { URL(string: origin).map(allows) ?? true }

    /// The person typed another address: what was remembered about the hosts of the addresses that changed is forgotten. An address that stayed the same keeps its memory.
    public func forgetChanged(from old: SavedInstallation, to new: SavedInstallation) {
        let pairs = [(old.endpoints.home, new.endpoints.home), (old.endpoints.away, new.endpoints.away)]
        for (before, after) in pairs where before != after {
            if let after, let host = URL(string: after.origin)?.host { forget(host: host) }
        }
    }
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
        store.put(newKey(host), "1")
    }

    public func clear(for host: String) { store.remove(key(host)); store.remove(certKey(host)); store.remove(newKey(host)) }

    private func certKey(_ host: String) -> String { "pin_cert_" + host.lowercased() }
    private func newKey(_ host: String) -> String { "pin_new_" + host.lowercased() }
    public static let strictKey = "pins_strict_chain"

    /// True when the chain must also lead to the certificate kept at pairing time (on unless the person turned it off).
    public var strictChain: Bool {
        get { store.get(PinStore.strictKey) != "0" }
        set { store.put(PinStore.strictKey, newValue ? "1" : "0") }
    }

    /// The DER of the certificate kept when the server was paired; nil for a pairing made before it was kept.
    public func certificate(for host: String) -> Data? {
        guard let text = store.get(certKey(host)), !text.isEmpty else { return nil }
        return Data(base64Encoded: text)
    }

    public func setCertificate(_ der: Data, for host: String) { store.put(certKey(host), der.base64EncodedString()) }

    /// True for a pin kept before certificates were kept: it still works, with a notice in the app.
    public func isLegacy(for host: String) -> Bool { !pins(for: host).isEmpty && certificate(for: host) == nil && store.get(newKey(host)) != "1" }

    /// Chain and certificate check for a chain that already matched a pin. `chainCertificates` are the DER of the chain, leaf first; `leadsTo` answers whether the chain, evaluated with that certificate as
    /// its only anchor, is signed link by link, in date and for the host (the system does that part).
    public func strictVerdict(host: String, chainCertificates: [Data], leadsTo: (Data) -> Bool) -> StrictVerdict {
        guard strictChain else { return .off }
        guard let kept = certificate(for: host) else { return store.get(newKey(host)) == "1" ? .capture : .legacy }
        return chainCertificates.contains(kept) && leadsTo(kept) ? .verified : .broken
    }

    private func expectKey(_ host: String) -> String { "ca_expect_" + host.lowercased() }

    /// The fingerprint (SHA-256 of the whole certificate, 64 lower-case hex characters) of the local authority that a set-up QR code named for `host`. The next connection waits for it: if the chain holds
    /// that very certificate, its key is paired as a QR with a pin would. It never refuses a connection by itself.
    public func expectAuthority(_ fingerprint: String, for host: String) {
        guard fingerprint.count == 64, fingerprint.unicodeScalars.allSatisfy({ ($0 >= "0" && $0 <= "9") || ($0 >= "a" && $0 <= "f") }) else { return }
        store.put(expectKey(host), fingerprint)
    }

    public func expectedAuthority(for host: String) -> String? {
        let value = store.get(expectKey(host)) ?? ""
        return value.isEmpty ? nil : value
    }

    public func clearExpected(for host: String) { store.remove(expectKey(host)) }

    /// A SHA-256 in base64 is 44 characters with one "=" at the end.
    public static func isWellFormed(_ pin: String) -> Bool {
        pin.count == 44 && pin.hasSuffix("=") && pin.dropLast().allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" } && pin.allSatisfy(\.isASCII)
    }

    /// Decides about a chain: `chainPins` are the pins of every certificate of the chain, the leaf first; `systemTrusts` is the answer of the system's own evaluation.
    public func decide(host: String, chainPins: [String], systemTrusts: Bool, chainFingerprints: [String] = [], verifiedPins: [String]? = nil) -> PinDecision {
        let kept = pins(for: host)
        if !kept.isEmpty { return PinStore.usable(chainPins, systemTrusts: systemTrusts, verified: verifiedPins).contains { kept.contains($0) } ? .trusted : .mismatch }
        guard let first = chainPins.first else { return .mismatch }
        // a set-up QR code named the authority of this installation: the chain that holds exactly that certificate pairs its key, whether or not the system knows the authority
        if let expected = expectedAuthority(for: host), let index = chainFingerprints.firstIndex(of: expected), chainPins.indices.contains(index), PinStore.usable([chainPins[index]], systemTrusts: systemTrusts, verified: verifiedPins).count == 1 { return .firstUse(pin: chainPins[index]) }
        // the key worth pinning is the one of the authority when there is one above the leaf, and the leaf's own when the server stands alone
        let candidate = chainPins.count > 1 ? chainPins[chainPins.count - 1] : first
        return systemTrusts ? .firstUse(pin: candidate) : .unknownAuthority(pin: candidate)
    }

    /// The pins of a chain that may count: all of them when the system trusts the chain; otherwise only those the app proved by evaluating the chain with that certificate as the only anchor (a signed
    /// path from the leaf to it, in date, for the host). `verified` nil means the caller did not check (tests).
    static func usable(_ chainPins: [String], systemTrusts: Bool, verified: [String]?) -> [String] {
        if systemTrusts { return chainPins }
        guard let verified else { return chainPins }
        return chainPins.filter { verified.contains($0) }
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
