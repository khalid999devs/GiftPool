import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct GiftPoolApp: App {
    @UIApplicationDelegateAdaptor(PushNotifications.self) private var push
    @StateObject private var session: AppSession
    @StateObject private var templates = TemplateLibrary()

    init() {
        FirebaseApp.configure()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-useEmulator") {
            GiftPoolApp.useLocalEmulator()
        }
        #endif

        let repository = FirestoreGiftPoolRepository()
        _session = StateObject(wrappedValue: AppSession(repository: repository, authService: AuthService()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(templates)
                .environmentObject(push)
                .fontDesign(.rounded)
                .tint(Theme.coral)
        }
    }

    // Local testing: run `firebase emulators:start` and add -useEmulator to the scheme's arguments.
    static func useLocalEmulator() {
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)

        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
    }
}
