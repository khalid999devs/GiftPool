import Foundation

enum MemberRole: String, Codable {
    case owner
    case member
}

struct Member: Identifiable, Codable, Equatable {
    static let maxDisplayNameLength = 40

    var uid: String
    var displayName: String
    var avatarId: String?
    var role: MemberRole
    var assignedMinor: Int
    var collectedMinor: Int
    var reportedGivenAt: Date?
    var joinedAt: Date?
    var lastPingAt: Date?
    var pingCount: Int
    var settledAt: Date?

    var id: String { uid }

    var isOwner: Bool { role == .owner }

    var outstandingMinor: Int {
        max(assignedMinor - collectedMinor, 0)
    }

    var hasReportedGiving: Bool {
        reportedGivenAt != nil
    }

    var avatar: AvatarInfo {
        AvatarInfo(name: displayName, avatarId: avatarId)
    }
}
