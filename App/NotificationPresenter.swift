// ARMOR-IOS-CONTROL - shows the alarm notices while the app is open (the system shows nothing in the foreground unless the app asks for it).
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import UserNotifications

/// What the person chose about a notice (hidden, silent, with sound) is decided before the notice is posted, so here every notice that
/// reaches the system is shown: a banner, the notification list and the sound the notice carries (none for a silent one).
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
