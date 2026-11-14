// ARMOR-IOS-CONTROL - shows the alarm notices while the app is open (the system shows nothing in the foreground unless the app asks for it).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import UserNotifications
import ArmorCore

/// What the person chose about a notice (hidden, silent, with sound) is decided before the notice is posted, so here every notice that
/// reaches the system is shown: a banner, the notification list and the sound the notice carries (none for a silent one).
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    /// Set by the app: acknowledges the alarm of a notice whose action "Confirm" was touched (the app may have been woken just for this).
    var onAcknowledge: ((String) async -> Void)?
    /// Set by the app: shows the camera of a notice whose action "Open camera" was touched.
    var onOpenCamera: ((String) async -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        switch response.actionIdentifier {
        case NoticeActions.acknowledgeActionId:
            if let id = NoticeActions.alarmId(from: info) { await onAcknowledge?(id) }
        case NoticeActions.openCameraActionId:
            if let id = NoticeActions.cameraId(from: info) { await onOpenCamera?(id) }
        default:
            break
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
