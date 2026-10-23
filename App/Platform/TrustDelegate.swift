// ARMOR-IOS-CONTROL - the rules for the certificate of the server: the system's own checks, plus the pin of the installation's key kept the first time (or paired with a QR code of Studio).
// The decision is ArmorCore's `PinStore.decide`; here are the parts that need the system: reading the keys of the chain and hashing them.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import CryptoKit
import Security
import ArmorCore

final class TrustDelegate: NSObject, URLSessionDelegate {
    private let pins: PinStore
    private let lock = NSLock()
    private var mismatchHost: String?
    /// Set when a first-use pin is kept, so the screen can say "paired with this server".
    var onPinned: ((String, String) -> Void)?

    init(pins: PinStore) { self.pins = pins }

    /// True once if a certificate was refused because it did not match the pin.
    func takeMismatch() -> Bool { lock.lock(); defer { lock.unlock() }; let had = mismatchHost != nil; mismatchHost = nil; return had }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil); return
        }
        let host = challenge.protectionSpace.host
        // plain HTTP to the house never gets here; for https the system decides first
        var error: CFError?
        let systemTrusts = SecTrustEvaluateWithError(trust, &error)
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        let hashes = chain.compactMap(TrustDelegate.spkiPin)
        switch pins.decide(host: host, chainPins: hashes, systemTrusts: systemTrusts) {
        case .trusted:
            completionHandler(.useCredential, URLCredential(trust: trust))
        case .firstUse(let pin):
            pins.add(pin, for: host)
            onPinned?(host, pin)
            completionHandler(.useCredential, URLCredential(trust: trust))
        case .mismatch:
            lock.lock(); mismatchHost = host; lock.unlock()
            completionHandler(.cancelAuthenticationChallenge, nil)
        case .unknownAuthority:
            // a private authority nobody paired with: refused; the person pairs from Settings (QR code of Studio) first
            lock.lock(); mismatchHost = host; lock.unlock()
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// The base64 SHA-256 of the SubjectPublicKeyInfo of a certificate: the usual pin. The system gives the bare key, so the header of its algorithm is put in front.
    static func spkiPin(_ certificate: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(certificate), let attributes = SecKeyCopyAttributes(key) as? [String: Any],
              let type = attributes[kSecAttrKeyType as String] as? String, let bits = attributes[kSecAttrKeySizeInBits as String] as? Int,
              let raw = SecKeyCopyExternalRepresentation(key, nil) as Data? else { return nil }
        let header: [UInt8]
        switch (type, bits) {
        case (kSecAttrKeyTypeRSA as String, 2048): header = [0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00]
        case (kSecAttrKeyTypeRSA as String, 4096): header = [0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00]
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 256): header = [0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00]
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 384): header = [0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00]
        default: return nil
        }
        return Data(SHA256.hash(data: Data(header) + raw)).base64EncodedString()
    }
}
