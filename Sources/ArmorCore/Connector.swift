// ARMOR-IOS-CONTROL - chooses the address to use: the private one at home, the one for away otherwise, and the other when the chosen one does not answer.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum Selection: Equatable, Sendable {
    case reached(ServerEndpoint)
    case failed(ReachProblem)
}

public enum Connector {
    /// Asks the server for its session facts (it answers without a session) at the chosen address and, if nothing answers, at the other. Any answer from the server, even a refusal, means the
    /// address is the right one; only silence (no HTTP status at all) moves on. `pinMismatch` tells whether the certificate rules refused a certificate meanwhile.
    public static func select(api: ArmorApi, installation: SavedInstallation, place: NetworkPlace, networkAvailable: Bool, pinMismatch: () -> Bool = { false }) async -> Selection {
        let endpoints = installation.endpoints
        guard let first = endpoints.chosen(for: place) else {
            return .failed(Reach.problem(installation: installation, triedHome: false, triedAway: false, networkAvailable: networkAvailable, pinMismatch: false))
        }
        var triedHome = first == endpoints.home
        var triedAway = first == endpoints.away
        if await answers(api, first) { return .reached(first) }
        if pinMismatch() { return .failed(.certificateChanged) }
        if let other = endpoints.alternative(to: first) {
            if other == endpoints.home { triedHome = true }
            if other == endpoints.away { triedAway = true }
            if await answers(api, other) { return .reached(other) }
            if pinMismatch() { return .failed(.certificateChanged) }
        }
        return .failed(Reach.problem(installation: installation, triedHome: triedHome, triedAway: triedAway, networkAvailable: networkAvailable, pinMismatch: false))
    }

    private static func answers(_ api: ArmorApi, _ endpoint: ServerEndpoint) async -> Bool {
        do { _ = try await api.sessionFacts(endpoint.origin); return true }
        catch let error as ArmorApiError { return error.status != nil }
        catch { return false }
    }
}
