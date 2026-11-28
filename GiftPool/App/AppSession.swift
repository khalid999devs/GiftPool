import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AppSession: ObservableObject {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn
    }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var user: SessionUser?
    @Published var profileError: String?

    let repository: GiftPoolRepository
    private let authService: AuthService
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var pendingSignUpName: String?
    private var deviceToken: String?

    init(repository: GiftPoolRepository, authService: AuthService) {
        self.repository = repository
        self.authService = authService
    }

    func start() {
        guard authHandle == nil else { return }
        authHandle = authService.addStateListener { [weak self] firebaseUser in
            self?.handleAuthChange(firebaseUser)
        }
    }

    func signIn(email: String, password: String) async throws {
        try await authService.signIn(email: Validators.trimmed(email), password: password)
    }

    func signUp(displayName: String, email: String, password: String) async throws {
        let name = Validators.trimmed(displayName)
        pendingSignUpName = name
        do {
            _ = try await authService.createAccount(email: Validators.trimmed(email), password: password)
            try await authService.updateDisplayName(name)
        } catch {
            pendingSignUpName = nil
            throw error
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await authService.sendPasswordReset(to: Validators.trimmed(email))
    }

    // The push token is removed first, so this phone stops getting the old account's reminders.
    func signOut() async throws {
        if let user, let token = deviceToken {
            try? await repository.removeDeviceToken(token, uid: user.uid)
            deviceToken = nil
        }
        try authService.signOut()
    }

    func saveDeviceToken(_ token: String) async {
        guard let user else { return }

        deviceToken = token
        try? await repository.saveDeviceToken(token, uid: user.uid)
    }

    func updateDisplayName(_ name: String, poolIds: [String]) async throws {
        guard let user else { throw AppError.notSignedIn }
        let trimmed = Validators.trimmed(name)
        if let error = Validators.displayNameError(trimmed) {
            throw AppError.validation(error)
        }
        try await repository.updateDisplayName(trimmed, uid: user.uid, poolIds: poolIds)
        try await authService.updateDisplayName(trimmed)
        self.user?.displayName = trimmed
    }

    func updateAvatar(_ avatarId: String?, poolIds: [String]) async throws {
        guard let user else { throw AppError.notSignedIn }
        try await repository.updateAvatar(avatarId, uid: user.uid, poolIds: poolIds)
        self.user?.avatarId = avatarId
    }

    private func handleAuthChange(_ firebaseUser: FirebaseAuth.User?) {
        guard let firebaseUser else {
            user = nil
            phase = .signedOut
            return
        }
        guard user?.uid != firebaseUser.uid else { return }

        let email = firebaseUser.email ?? ""
        let fallbackName = pendingSignUpName
            ?? firebaseUser.displayName
            ?? String(email.split(separator: "@").first ?? "Friend")
        user = SessionUser(uid: firebaseUser.uid, displayName: fallbackName, email: email)
        phase = .signedIn

        Task { await loadProfile(uid: firebaseUser.uid, email: email, fallbackName: fallbackName) }
    }

    private func loadProfile(uid: String, email: String, fallbackName: String) async {
        do {
            if let profile = try await repository.fetchProfile(uid: uid) {
                if user?.uid == uid {
                    user?.displayName = profile.displayName
                    user?.avatarId = profile.avatarId
                }
            } else {
                try await repository.createProfile(uid: uid, displayName: fallbackName, email: email)
            }
            pendingSignUpName = nil
        } catch {
            profileError = ErrorMessages.friendly(error)
        }
    }
}
