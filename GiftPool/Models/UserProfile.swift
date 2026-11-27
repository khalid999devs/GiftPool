import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Equatable {
    var displayName: String
    var avatarId: String?
    var email: String
    var createdAt: Date?
}

struct PoolRef: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var poolId: String
    var joinedAt: Date?
}

struct SessionUser: Equatable {
    let uid: String
    var displayName: String
    let email: String
    var avatarId: String? = nil

    var avatar: AvatarInfo {
        AvatarInfo(name: displayName, avatarId: avatarId)
    }
}
