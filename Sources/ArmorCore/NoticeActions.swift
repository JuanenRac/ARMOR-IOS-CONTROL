// ARMOR-IOS-CONTROL - the actions of a notice: "Confirm" for a notice that knows its alarm (it acknowledges the alarm with the session the phone keeps, without opening the app) and "Open camera" for a
// notice about a camera (the app opens on that camera), as the Android app does.
// The notices are posted by the app itself from the news it read, so the actions travel in the notice: a category with the actions, and the ids in its user info.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum NoticeActions {
    public static let categoryId = "armor.alarm.ack"
    public static let openCameraCategoryId = "armor.camera.open"
    public static let ackAndOpenCategoryId = "armor.alarm.ack.camera.open"
    public static let acknowledgeActionId = "armor.ack"
    public static let openCameraActionId = "armor.open_camera"
    public static let alarmKey = "alarm_id"
    public static let cameraKey = "camera_id"

    /// An id the server gave: letters, digits and dashes, short. Anything else is not acted on.
    public static func validAlarmId(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.unicodeScalars.allSatisfy { ($0 >= "A" && $0 <= "Z") || ($0 >= "a" && $0 <= "z") || ($0 >= "0" && $0 <= "9") || $0 == "-" || $0 == "_" }
    }

    private static func usable(alarm: String?) -> String? {
        guard let alarm, validAlarmId(alarm) else { return nil }
        return alarm
    }

    private static func usable(camera: String?) -> String? {
        guard let camera, OpenCamera.valid(camera) else { return nil }
        return camera
    }

    /// The user info of a notice: the ids the app may act on; nothing otherwise.
    public static func userInfo(alarmId: String?, cameraId: String? = nil) -> [String: String] {
        var info: [String: String] = [:]
        if let alarm = usable(alarm: alarmId) { info[alarmKey] = alarm }
        if let camera = usable(camera: cameraId) { info[cameraKey] = camera }
        return info
    }

    /// The category a notice carries: the one with the actions its facts allow, none when it allows none.
    public static func category(alarmId: String?, cameraId: String? = nil) -> String? {
        switch (usable(alarm: alarmId) != nil, usable(camera: cameraId) != nil) {
        case (true, true): return ackAndOpenCategoryId
        case (true, false): return categoryId
        case (false, true): return openCameraCategoryId
        case (false, false): return nil
        }
    }

    /// The alarm id read back from the user info of a notice that was answered; nil when it is not one the app may act on.
    public static func alarmId(from userInfo: [AnyHashable: Any]) -> String? {
        guard let id = userInfo[alarmKey] as? String, validAlarmId(id) else { return nil }
        return id
    }

    /// The camera id read back from the user info of a notice that was answered; nil when it is not one the app may act on.
    public static func cameraId(from userInfo: [AnyHashable: Any]) -> String? {
        guard let id = userInfo[cameraKey] as? String, OpenCamera.valid(id) else { return nil }
        return id
    }
}
