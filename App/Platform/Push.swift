// ARMOR-IOS-CONTROL - alarms that reach a closed app: the push that the server sends through Firebase (data only: the app decides what to show). Optional: without the Firebase file of the
// installation (GoogleService-Info.plist in the app) nothing here runs, and the alarms are read while the app is open.
// The push carries the id of the event; the app asks the server for the news and announces each event once, whether it came by push or by reading (ArmorCore.SeenEvents), and the notification
// of an event has the event id as identifier, so a second one for the same event replaces the first.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import UIKit
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseCore
import FirebaseMessaging
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by the app once the model exists.
    static var onPush: (() async -> Void)?
    static var onToken: ((String) -> Void)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if canImport(FirebaseMessaging)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
        }
        #endif
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    /// A data-only push: read the news from the server (the id of the event is in `event_id`, but the server is the source of truth).
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await AppDelegate.onPush?()
        return .newData
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken { AppDelegate.onToken?(fcmToken) }
    }
}
#endif
