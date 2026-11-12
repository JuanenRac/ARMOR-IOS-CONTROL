// ARMOR-IOS-CONTROL - the library of recordings: the photos and videos the cameras made, as the server lists them. The same reading as the Android app (its evidence tab).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// One photo ("snapshot") or video ("recording") kept by the server.
public struct MediaItemView: Equatable, Sendable, Identifiable {
    public let id: String
    public let cameraId: String
    /// "snapshot" or "recording".
    public let kind: String
    public let file: String
    /// When it was made, as the server wrote it (ISO 8601).
    public let createdAt: String
    public let bytes: Int

    public var isPhoto: Bool { kind == "snapshot" }
    public init(id: String, cameraId: String, kind: String, file: String, createdAt: String, bytes: Int) {
        self.id = id; self.cameraId = cameraId; self.kind = kind; self.file = file; self.createdAt = createdAt; self.bytes = bytes
    }
}

public struct MediaCatalogueView: Equatable, Sendable {
    public var items: [MediaItemView] = []
    /// The cameras that are recording right now.
    public var activeCameraIds: Set<String> = []
    public init(items: [MediaItemView] = [], activeCameraIds: Set<String> = []) { self.items = items; self.activeCameraIds = activeCameraIds }
}

public enum EvidenceParser {
    /// An item with a field missing is left out, not the whole library.
    public static func catalogue(_ root: JSON) -> MediaCatalogueView {
        let items: [MediaItemView] = root.objects("items").compactMap { item in
            let id = item.str("id"), camera = item.str("cameraId"), kind = item.str("kind"), file = item.str("file")
            if id.isEmpty || camera.isEmpty || kind.isEmpty || file.isEmpty { return nil }
            return MediaItemView(id: id, cameraId: camera, kind: kind, file: file, createdAt: item.str("createdAt"), bytes: item.int("bytes"))
        }
        let active = ((root["activeCameraIds"] as? [Any]) ?? []).compactMap { $0 as? String }.filter { !$0.isEmpty }
        return MediaCatalogueView(items: items, activeCameraIds: Set(active))
    }

    /// The route of one file of the library: photos and videos live in different folders of the server, and every piece of the path is escaped so a name cannot climb out of it.
    public static func path(_ item: MediaItemView) -> String {
        "/api/v1/media/\(ArmorApiClient.part(item.cameraId))/\(item.isPhoto ? "snapshots" : "recordings")/\(ArmorApiClient.part(item.file))"
    }

    /// The day and the minute a file was made (UTC, as the server wrote it): "2026-03-05 10:42". A date that does not look like one is shown as it came.
    public static func when(_ iso: String) -> String {
        let text = iso.trimmingCharacters(in: .whitespaces)
        guard text.count >= 16, let t = text.firstIndex(of: "T"), text.distance(from: text.startIndex, to: t) == 10 else { return text }
        return String(text.prefix(10)) + " " + String(text[text.index(after: t)...].prefix(5))
    }

    /// The size in the unit a person reads: "820 KB", "3.4 MB".
    public static func size(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(max(0, bytes)) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        let tenths = bytes / (1024 * 1024 / 10)
        return "\(tenths / 10).\(tenths % 10) MB"
    }

    /// The most a single file of the library is taken for viewing: a longer one is refused instead of filling the phone.
    public static let largestFile = 400 * 1024 * 1024
}
