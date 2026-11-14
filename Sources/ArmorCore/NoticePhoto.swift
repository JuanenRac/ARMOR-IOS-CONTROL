// ARMOR-IOS-CONTROL - the picture in the notice of a camera, as the Android app has it: when the person turned it on, the phone asks its own server for the still picture of that camera
// (GET /api/v1/cameras/{id}/snapshot, with the saved session) and attaches it to the notice. It never goes through the push service of Apple or Google; off by default, and without a session
// or an answer the notice stays as it was.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum NoticePhoto {
    /// The biggest picture taken in: the server stops a bigger one, and the phone does not keep more than this for a notice.
    public static let maxBytes = 1_500_000

    /// An id the server gave: letters, digits, dots, dashes and underscores, short. Anything else is not asked for.
    public static func validCameraId(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 80 && id.unicodeScalars.allSatisfy { ($0 >= "A" && $0 <= "Z") || ($0 >= "a" && $0 <= "z") || ($0 >= "0" && $0 <= "9") || $0 == "-" || $0 == "_" || $0 == "." }
    }

    /// Whether a notice gets a picture: the person turned it on and the notice names a camera.
    public static func wanted(enabled: Bool, notice: AlarmNotice) -> Bool {
        guard enabled, let camera = notice.cameraId else { return false }
        return validCameraId(camera)
    }

    /// The file extension of a picture by its signature ("jpg" or "png"), or nil when the bytes are not a picture.
    public static func fileExtension(of data: Data) -> String? {
        let head = [UInt8](data.prefix(8))
        if head.count > 3, head[0] == 0xFF, head[1] == 0xD8, head[2] == 0xFF { return "jpg" }
        if head.count >= 8, head[0] == 0x89, head[1] == 0x50, head[2] == 0x4E, head[3] == 0x47 { return "png" }
        return nil
    }
}

/// What the person chose, kept in the preferences of the app. Off by default.
public final class NoticePhotoStore: @unchecked Sendable {
    private let store: KeyValueStore
    public init(_ store: KeyValueStore) { self.store = store }

    public var enabled: Bool {
        get { store.get("notice_photo") == "1" }
        set { if newValue { store.put("notice_photo", "1") } else { store.remove("notice_photo") } }
    }
}
