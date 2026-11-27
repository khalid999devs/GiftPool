import Foundation
import FirebaseFirestore

struct Invite: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var poolId: String
    var createdBy: String
    var isActive: Bool
    var expiresAt: Date
    var poolTitle: String
    var ownerName: String
    var createdAt: Date?

    var token: String { id ?? "" }

    func isUsable(now: Date = .now) -> Bool {
        isActive && expiresAt > now
    }
}
