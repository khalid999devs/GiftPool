import Foundation
import FirebaseAuth

final class AuthService {
    private var auth: Auth { Auth.auth() }

    func addStateListener(_ handler: @escaping (FirebaseAuth.User?) -> Void) -> AuthStateDidChangeListenerHandle {
        auth.addStateDidChangeListener { _, user in
            handler(user)
        }
    }

    func removeStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await auth.signIn(withEmail: email, password: password)
    }

    func createAccount(email: String, password: String) async throws -> FirebaseAuth.User {
        try await auth.createUser(withEmail: email, password: password).user
    }

    func updateDisplayName(_ name: String) async throws {
        guard let user = auth.currentUser else { throw AppError.notSignedIn }
        let request = user.createProfileChangeRequest()
        request.displayName = name
        try await request.commitChanges()
    }

    func sendPasswordReset(to email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
        try auth.signOut()
    }
}
