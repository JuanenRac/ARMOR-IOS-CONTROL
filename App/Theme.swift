// ARMOR-IOS-CONTROL - the look: near-black surfaces, a cyan accent, amber for attention, red for danger (the same as the Android app and Studio).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI

enum Theme {
    static let background = Color(red: 0.04, green: 0.05, blue: 0.07)
    static let surface = Color(red: 0.08, green: 0.10, blue: 0.13)
    static let accent = Color(red: 0.0, green: 0.90, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.70, blue: 0.0)
    static let danger = Color(red: 1.0, green: 0.27, blue: 0.27)
    static let ok = Color(red: 0.0, green: 1.0, blue: 0.53)
    static let muted = Color(red: 0.55, green: 0.58, blue: 0.62)

    static func severity(_ severity: String) -> Color {
        switch severity {
        case "critical": return danger
        case "high": return amber
        default: return accent
        }
    }
}

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule()).foregroundColor(color)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 12)).foregroundColor(.black)
    }
}
