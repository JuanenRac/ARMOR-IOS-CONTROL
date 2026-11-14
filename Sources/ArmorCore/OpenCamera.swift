// ARMOR-IOS-CONTROL - the action "Open camera" of a notice about a camera: the app opens on the Cameras place with that camera in full screen, once the person is recognised and the camera is known
// (as the Android app does). The id travels in the user info of the notice and is held by the app until the screen takes it; an id that is not a camera id of the server is never acted on.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum OpenCamera {
    /// What the screen of the cameras does with a request.
    public enum Outcome: Equatable, Sendable {
        /// The list of cameras has not arrived yet: keep the request.
        case wait
        /// Show this camera in full screen and forget the request.
        case open(CameraView)
        /// The id is not valid or the server has no such camera: forget the request.
        case drop
    }

    /// An id the server gave: letters, digits, dots, dashes and underscores, short. Anything else is not acted on.
    public static func valid(_ id: String) -> Bool { NoticePhoto.validCameraId(id) }

    /// The window to open for the camera the notice named. A camera with two lenses in one stream opens its first window. `cameras` is the list as the screen shows it (windows included).
    public static func resolve(requested: String, cameras: [CameraView], loaded: Bool) -> Outcome {
        guard valid(requested) else { return .drop }
        if let found = cameras.first(where: { $0.serverId == requested }) { return .open(found) }
        return loaded ? .drop : .wait
    }
}
