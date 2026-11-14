// ARMOR-IOS-CONTROL - what the widget of the home screen says about the system, as the tile and the widget of the Android app do: only whether it is armed, from the word the server gives for the mode.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum SystemFace: Equatable, Sendable, CaseIterable {
    case armed, disarmed, unknown

    /// The mode of the server ("armed", "disarmed") as a face; anything else, or nothing, is unknown (the widget never guesses).
    public static func of(_ mode: String?) -> SystemFace {
        switch mode {
        case "armed": return .armed
        case "disarmed": return .disarmed
        default: return .unknown
        }
    }

    /// The phrase of the face, in the Spanish of the source.
    public var phrase: String {
        switch self {
        case .armed: return "Armada"
        case .disarmed: return "Desarmada"
        case .unknown: return "Sin datos"
        }
    }

    /// The phrase of the face in the language of the translator.
    public func text(_ t: Translator) -> String {
        switch self {
        case .armed: return t.tr("Armada")
        case .disarmed: return t.tr("Desarmada")
        case .unknown: return t.tr("Sin datos")
        }
    }
}
