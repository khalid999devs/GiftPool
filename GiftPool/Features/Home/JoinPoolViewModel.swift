import Foundation
import Combine

@MainActor
final class JoinPoolViewModel: ObservableObject {
    @Published var code = "" {
        didSet { if code != oldValue { errorMessage = nil } }
    }
    @Published private(set) var invite: Invite?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let repository: GiftPoolRepository

    init(repository: GiftPoolRepository) {
        self.repository = repository
    }

    func lookUp(uid: String) async {
        guard let token = InviteService.normalize(code) else {
            errorMessage = "Codes have 16 letters and numbers, like ABCD-EFGH-JKLM-NPQR."
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            guard let found = try await repository.fetchInvite(token: token) else {
                throw AppError.inviteNotFound
            }
            guard found.isUsable() else { throw AppError.inviteExpired }
            if try await repository.hasJoined(poolId: found.poolId, uid: uid) {
                throw AppError.alreadyMember
            }
            invite = found
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    func join(as user: SessionUser) async -> String? {
        guard let invite else { return nil }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await repository.joinPool(with: invite, user: user)
            return invite.poolId
        } catch {
            errorMessage = ErrorMessages.friendly(error)
            return nil
        }
    }

    func reset() {
        invite = nil
        errorMessage = nil
    }
}
