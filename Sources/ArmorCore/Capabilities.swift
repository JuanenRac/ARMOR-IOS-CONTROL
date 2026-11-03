// ARMOR-IOS-CONTROL - what the signed-in person may do, from the `capabilities` field of the session (the same reading as ARMOR-STUDIO and the Android app, so all three show the same things).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// The actions the server names in `capabilities.actions`.
public enum CapabilityAction {
    public static let arm = "arm"
    public static let disarm = "disarm"
    public static let acknowledge = "acknowledge"
    public static let operate = "operate"
    public static let cameraControl = "camera_control"
    public static let administer = "administer"
    public static let manageUsers = "manage_users"
    public static let securitySettings = "security_settings"
    public static let all = [arm, disarm, acknowledge, operate, cameraControl, administer, manageUsers, securitySettings]
}

/// What a person may do and what the server offers. A server that announces its capabilities is believed (an action it does not name is not allowed, so a newer action never appears on its own);
/// an older server sends no field and then the role decides, as it always did: administrators everything, operators everything but the administration, anyone else nothing that changes.
/// The routes check the role again: this only decides what the screens show or enable.
public struct Capabilities: Equatable, Sendable {
    /// True when the server announced them; false when they were worked out from the role.
    public let announced: Bool
    public let actions: Set<String>
    public let features: Set<String>

    public init(announced: Bool, actions: Set<String>, features: Set<String> = []) { self.announced = announced; self.actions = actions; self.features = features }

    public func can(_ action: String) -> Bool { actions.contains(action) }
    public func has(_ feature: String) -> Bool { features.contains(feature) }

    private static let operatorActions: Set<String> = [CapabilityAction.arm, CapabilityAction.disarm, CapabilityAction.acknowledge, CapabilityAction.operate, CapabilityAction.cameraControl]
    /// `security_settings` needs a route only the new server has: it is never worked out from the role.
    private static let adminActions: Set<String> = operatorActions.union([CapabilityAction.administer, CapabilityAction.manageUsers])

    /// An older server: the role decides.
    public static func fromRole(_ role: String) -> Capabilities {
        Capabilities(announced: false, actions: role == "admin" ? adminActions : (role == "operator" ? operatorActions : []))
    }

    /// The announced field, or nil when it is missing or not the shape of version 1.
    public static func parse(_ json: JSON?) -> Capabilities? {
        guard let json, (json["version"] as? Int) == 1, let raw = json["actions"] as? JSON else { return nil }
        var allowed = Set<String>()
        for (key, value) in raw where (value as? Bool) == true { allowed.insert(key) }
        let features = Set((json["features"] as? [Any])?.compactMap { $0 as? String } ?? [])
        return Capabilities(announced: true, actions: allowed, features: features)
    }

    /// The answer of `GET /api/v1/studio/session`: announced when the server sent them, else from the role.
    public static func of(session json: JSON, role: String) -> Capabilities { parse(json.object("capabilities")) ?? fromRole(role) }
}
