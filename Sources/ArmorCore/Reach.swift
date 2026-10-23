// ARMOR-IOS-CONTROL - which address of the installation to use and what to tell the person when the house cannot be reached; the quality of the camera away from home.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The saved installation: the two addresses and what the person chose to keep.
public struct SavedInstallation: Equatable, Sendable {
    public var homeHost: String
    public var homePort: String
    public var awayHost: String
    public var awayPort: String
    public init(homeHost: String = "", homePort: String = "8080", awayHost: String = "", awayPort: String = "443") {
        self.homeHost = homeHost; self.homePort = homePort; self.awayHost = awayHost; self.awayPort = awayPort
    }

    public var endpoints: DualEndpoint {
        DualEndpoint(home: homeHost.isEmpty ? nil : ServerEndpoint.fromHostAndPort(homeHost, homePort),
                     away: awayHost.isEmpty ? nil : ServerEndpoint.fromHostAndPort(awayHost, awayPort))
    }

    public func save(to store: KeyValueStore) {
        store.put("home_host", homeHost); store.put("home_port", homePort); store.put("away_host", awayHost); store.put("away_port", awayPort)
    }

    public static func load(from store: KeyValueStore) -> SavedInstallation {
        SavedInstallation(homeHost: store.get("home_host") ?? "", homePort: store.get("home_port") ?? "8080",
                          awayHost: store.get("away_host") ?? "", awayPort: store.get("away_port") ?? "443")
    }
}

/// Why the house could not be reached, in the words the person needs.
public enum ReachProblem: Equatable, Sendable {
    /// Neither address is valid or typed.
    case noAddress
    /// The phone has no network at all.
    case offline
    /// The private address was tried and failed, and there is no address for away.
    case homeUnreachableNoRemote
    /// The address for away was tried and failed.
    case remoteUnreachable
    /// Both were tried and failed.
    case bothUnreachable
    /// The server answered but refused the certificate pin.
    case certificateChanged

    public func message(_ t: Translator) -> String {
        switch self {
        case .noAddress: return t.tr("La dirección del servidor no es válida.")
        case .offline: return t.tr("El teléfono no tiene conexión a Internet ni a la red de casa.")
        case .homeUnreachableNoRemote: return t.tr("No se puede llegar a casa. Si no estás en tu wifi, añade la dirección de fuera de casa (un nombre DNS o la VPN) en los ajustes del servidor.")
        case .remoteUnreachable: return t.tr("No se puede llegar a casa desde fuera. Comprueba que el servidor tiene el acceso remoto activo y que la dirección de fuera de casa es correcta.")
        case .bothUnreachable: return t.tr("No se puede llegar a casa ni por la red de casa ni desde fuera. Comprueba la wifi o los datos del teléfono, y que el servidor está encendido.")
        case .certificateChanged: return t.tr("El certificado del servidor ha cambiado y no coincide con el que se guardó. Si lo has renovado, vuelve a emparejar el servidor desde los ajustes; si no, alguien podría estar interceptando la conexión.")
        }
    }
}

public enum Reach {
    /// What to say when the attempts failed. `tried` are the addresses tried, in order, with whether each is the private one.
    public static func problem(installation: SavedInstallation, triedHome: Bool, triedAway: Bool, networkAvailable: Bool, pinMismatch: Bool) -> ReachProblem {
        if pinMismatch { return .certificateChanged }
        if installation.endpoints.home == nil && installation.endpoints.away == nil { return .noAddress }
        if !networkAvailable { return .offline }
        if triedHome && triedAway { return .bothUnreachable }
        if triedAway { return .remoteUnreachable }
        return .homeUnreachableNoRemote
    }

    /// Whether the address in use is outside the house: there the app can lighten what it asks for (fewer pictures) when it is not at home.
    public static func isAway(_ endpoint: ServerEndpoint, installation: SavedInstallation) -> Bool {
        endpoint == installation.endpoints.away && endpoint != installation.endpoints.home
    }
}
