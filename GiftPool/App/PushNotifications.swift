import SwiftUI
import Combine
import UserNotifications
import FirebaseMessaging

// Lock-screen push for reminders.
// Apple gives the phone an APNs token, Firebase Messaging turns it into an FCM token, and we save that
// token under the user. A trusted server (a Cloud Function) sends the push when an organizer pings someone.
final class PushNotifications: NSObject, UIApplicationDelegate, ObservableObject {
    @Published private(set) var fcmToken: String?
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published var openedPoolId: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        Task {
            await refreshStatus()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func refreshStatus() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .authorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // Asked after someone creates or joins a plan, when reminders start to matter.
    func requestPermissionIfNeeded() async {
        await refreshStatus()
        guard status == .notDetermined else { return }

        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshStatus()
    }

    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}

extension PushNotifications: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
        }
    }
}

extension PushNotifications: UNUserNotificationCenterDelegate {
    // Show the banner even while GiftPool is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Tapping a reminder opens that plan's contributions.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let poolId = response.notification.request.content.userInfo["poolId"] as? String

        await MainActor.run {
            self.openedPoolId = poolId
        }
    }
}
