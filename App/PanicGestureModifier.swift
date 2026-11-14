// ARMOR-IOS-CONTROL - listens for the hidden panic gesture on a view: a long press, or five quick touches inside three seconds (the numbers are in ArmorCore/PanicGesture.swift).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

private struct PanicGestureModifier: ViewModifier {
    let offered: Bool
    let action: () -> Void
    @State private var counter = TapCounter()

    func body(content: Content) -> some View {
        if offered {
            content
                .contentShape(Rectangle())
                .onLongPressGesture { action() }
                .onTapGesture { if counter.touch(atMs: Int64(Date().timeIntervalSince1970 * 1000)) { action() } }
        } else {
            content
        }
    }
}

extension View {
    /// With `offered` false (the server does not offer it) the view listens to nothing and touches go on as before.
    func panicGesture(offered: Bool, _ action: @escaping () -> Void) -> some View {
        modifier(PanicGestureModifier(offered: offered, action: action))
    }
}
