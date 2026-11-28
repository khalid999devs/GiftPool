import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var push: PushNotifications
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Onboarding shows until the first successful sign-in; after that, "Welcome back".
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var authPath: [AuthViewModel.Mode] = []

    var body: some View {
        ZStack {
            switch session.phase {
            case .launching:
                // The logo zooms through as the first real screen fades in.
                LaunchView()
                    .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 1.3))))

            case .signedOut:
                NavigationStack(path: $authPath) {
                    Group {
                        if hasSeenWelcome {
                            WelcomeBackView()
                        } else {
                            WelcomeView(path: $authPath)
                        }
                    }
                    .navigationDestination(for: AuthViewModel.Mode.self) { mode in
                        AuthView(mode: mode)
                    }
                }
                // A reminder tapped while signed out belongs to whoever got it, not the next account.
                .onAppear { push.openedPoolId = nil }
                .onChange(of: push.openedPoolId) { push.openedPoolId = nil }
                .transition(.opacity)

            case .signedIn:
                if let user = session.user {
                    SignedInRoot(user: user)
                        .id(user.uid)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.2) : .smooth(duration: 0.55), value: session.phase)
        .onAppear { session.start() }
        .onChange(of: session.phase) { _, phase in
            if phase == .signedIn {
                hasSeenWelcome = true
                authPath = []
            }
        }
    }
}

// Everything that only exists while signed in. Signing out releases these view models,
// which removes their Firestore listeners.
private struct SignedInRoot: View {
    let user: SessionUser
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var push: PushNotifications
    @StateObject private var router = AppRouter()
    @StateObject private var reminders: RemindersViewModel

    init(user: SessionUser) {
        self.user = user
        _reminders = StateObject(wrappedValue: RemindersViewModel(uid: user.uid))
    }

    var body: some View {
        HomeView(user: user, repository: session.repository)
            .environmentObject(router)
            .environmentObject(reminders)
            .onAppear { reminders.start(repository: session.repository) }
            .task(id: push.fcmToken) {
                if let token = push.fcmToken {
                    await session.saveDeviceToken(token)
                }
            }
            .onChange(of: reminders.unreadCount, initial: true) { _, count in
                push.setBadge(count)
            }
            .onChange(of: push.openedPoolId, initial: true) { _, poolId in
                guard let poolId else { return }
                router.openPool(poolId, focus: .contributions)
                push.openedPoolId = nil
            }
            .onDisappear { push.setBadge(0) }
    }
}

// Looks exactly like the system launch screen (same color and logo, set in Info.plist),
// so there's no jump when the app's first frame appears.
private struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            Image("LaunchMark")
                .scaleEffect(breathing ? 1.04 : 1)
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("Loading GiftPool")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}
