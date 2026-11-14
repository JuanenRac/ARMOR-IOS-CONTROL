// ARMOR-IOS-CONTROL - the widget of the home screen: whether the system is armed, read from the own server with the session the app keeps. PREPARED, NOT YET A TARGET: it is not in project.yml.
// To turn it on (needs a Mac): add a widget extension target that holds this file and ArmorCore, give the app and the extension the same Keychain access group so the extension can read the
// saved session, and generate the project again. Like the tile of the Android app it only shows and opens the app: it never arms or disarms, and the person adds it on purpose.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import WidgetKit
import ArmorCore

struct StatusEntry: TimelineEntry {
    let date: Date
    let face: SystemFace
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry { StatusEntry(date: Date(), face: .unknown) }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) { completion(StatusEntry(date: Date(), face: .unknown)) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            let face = await StatusReader.face()
            // asked again in half an hour: the system decides when it really does
            completion(Timeline(entries: [StatusEntry(date: Date(), face: face)], policy: .after(Date().addingTimeInterval(30 * 60))))
        }
    }
}

/// Reads the mode with the saved session; unknown without a session or an answer. The session comes from the Keychain access group shared with the app (to be set up with the target).
enum StatusReader {
    static func face() async -> SystemFace {
        // TODO(target): restore the saved session of the server in use from the shared Keychain group and ask `ArmorApiClient.status`; until the target exists this stays unknown.
        .unknown
    }
}

struct StatusWidgetView: View {
    let entry: StatusEntry
    private let translator = Translator(language: Locale.current.language.languageCode?.identifier ?? "en")

    var body: some View {
        VStack(spacing: 4) {
            Text("A.R.M.O.R.").font(.caption).foregroundColor(.secondary)
            Text(entry.face.text(translator)).font(.title3.bold()).foregroundColor(entry.face == .armed ? .cyan : .primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
struct ArmorStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "es.electrohobby3d.armor.status", provider: StatusProvider()) { entry in StatusWidgetView(entry: entry) }
            .configurationDisplayName("A.R.M.O.R.")
            .description("Shows whether the system is armed.")
            .supportedFamilies([.systemSmall])
    }
}
