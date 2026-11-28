import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode: Identifiable {
        case signIn
        case signUp

        var id: Self { self }
    }

    @Published var mode: Mode
    @Published var displayName = "" {
        didSet { if displayName != oldValue { errorMessage = nil } }
    }
    @Published var email = "" {
        didSet { if email != oldValue { errorMessage = nil } }
    }
    @Published var password = "" {
        didSet { if password != oldValue { errorMessage = nil } }
    }
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var notice: String?

    init(mode: Mode = .signIn) {
        self.mode = mode
    }

    var canSubmit: Bool {
        let hasName = mode == .signIn || !Validators.trimmed(displayName).isEmpty
        return !isWorking && hasName && !Validators.trimmed(email).isEmpty && !password.isEmpty
    }

    // Firebase emails a reset link. The message doesn't say whether the email has an account,
    // so nobody can use this to find out who uses GiftPool.
    func resetPassword(using session: AppSession) async {
        notice = nil
        guard Validators.isValidEmail(Validators.trimmed(email)) else {
            errorMessage = "Enter your email above first."
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await session.sendPasswordReset(email: email)
            notice = "If there's an account for that email, a reset link is on its way."
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    func submit(using session: AppSession) async {
        notice = nil
        let errors = Validators.authErrors(
            email: email,
            password: password,
            displayName: mode == .signUp ? displayName : nil
        )
        guard errors.isEmpty else {
            errorMessage = errors.first
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            switch mode {
            case .signIn:
                try await session.signIn(email: email, password: password)
            case .signUp:
                try await session.signUp(displayName: displayName, email: email, password: password)
            }
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }
}
