// ARMOR-IOS-CONTROL - the action "Confirm" of a notice that knows its alarm: it acknowledges the alarm with the session the phone keeps, without opening the app (as the Android app does).
// The notices are posted by the app itself from the news it read, so the action travels in the notice: a category with the action, and the id of the alarm in its user info.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

public enum NoticeActions {
    public static let categoryId = "armor.alarm.ack"
    public static let acknowledgeActionId = "armor.ack"
    public static let alarmKey = "alarm_id"

    /// An id the server gave: letters, digits and dashes, short. Anything else is not acted on.
    public static func validAlarmId(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.unicodeScalars.allSatisfy { ($0 >= "A" && $0 <= "Z") || ($0 >= "a" && $0 <= "z") || ($0 >= "0" && $0 <= "9") || $0 == "-" || $0 == "_" }
    }

    /// The user info of a notice: the id of its alarm when it has one the app may act on; nothing otherwise.
    public static func userInfo(alarmId: String?) -> [String: String] {
        guard let alarmId, validAlarmId(alarmId) else { return [:] }
        return [alarmKey: alarmId]
    }

    /// The category a notice carries: the one with the action when its alarm is known, none otherwise.
    public static func category(alarmId: String?) -> String? {
        guard let alarmId, validAlarmId(alarmId) else { return nil }
        return categoryId
    }

    /// The alarm id read back from the user info of a notice that was answered; nil when it is not one the app may act on.
    public static func alarmId(from userInfo: [AnyHashable: Any]) -> String? {
        guard let id = userInfo[alarmKey] as? String, validAlarmId(id) else { return nil }
        return id
    }
}
