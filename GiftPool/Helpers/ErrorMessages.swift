import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AppError: LocalizedError {
    case validation(String)
    case notSignedIn
    case inviteNotFound
    case inviteExpired
    case alreadyMember
    case poolClosed

    var errorDescription: String? {
        switch self {
        case .validation(let message): return message
        case .notSignedIn: return "Please sign in again."
        case .inviteNotFound: return "That code doesn't match any plan. Check it and try again."
        case .inviteExpired: return "This invitation has expired or was revoked. Ask the organizer for a new code."
        case .alreadyMember: return "You're already in this plan."
        case .poolClosed: return "This plan is closed, so no changes can be made."
        }
    }
}

enum ErrorMessages {
    static func friendly(_ error: Error) -> String {
        if let appError = error as? AppError, let message = appError.errorDescription {
            return message
        }
        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail: return "That email address looks invalid."
            case .emailAlreadyInUse: return "An account with this email already exists. Try signing in."
            case .weakPassword: return "Choose a stronger password (at least 6 characters)."
            case .wrongPassword, .invalidCredential, .userNotFound: return "Email or password is incorrect."
            case .networkError: return "You're offline. Check your connection and try again."
            case .tooManyRequests: return "Too many attempts. Please wait a moment and try again."
            case .operationNotAllowed: return "Email sign-in isn't available right now."
            default: return nsError.localizedDescription
            }
        }

        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch code {
            case .permissionDenied: return "You don't have permission to do that."
            case .unavailable, .deadlineExceeded: return "You're offline or the server is unreachable. Try again shortly."
            case .notFound: return "This item no longer exists."
            case .failedPrecondition: return "That change isn't possible right now. Refresh and try again."
            default: return nsError.localizedDescription
            }
        }
        return nsError.localizedDescription
    }
}
