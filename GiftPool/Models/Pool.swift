import Foundation
import FirebaseFirestore

struct Pool: Identifiable, Codable, Equatable {
    static let maxTitleLength = 60
    static let maxRecipientLength = 40
    static let maxNoteLength = 280

    @DocumentID var id: String?
    var title: String
    var recipientName: String
    var occasionKey: String
    var occasionDate: Date
    var budgetMinor: Int
    var note: String?
    var ownerUid: String
    var selectedIdeaId: String?
    var status: PoolStatus
    var isDeleted: Bool
    var inviteToken: String?
    var createdAt: Date?
    var updatedAt: Date?
    var completedAt: Date?

    var isActive: Bool {
        status.isActive && !isDeleted
    }

    func isOwned(by uid: String) -> Bool {
        ownerUid == uid
    }
}

struct PoolDraft: Equatable {
    var title = ""
    var recipientName = ""
    var occasionKey = "birthday"
    var occasionDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    var budgetText = ""
    var note = ""

    init() {}

    init(pool: Pool) {
        title = pool.title
        recipientName = pool.recipientName
        occasionKey = pool.occasionKey
        occasionDate = DateHelpers.localDate(fromOccasion: pool.occasionDate)
        budgetText = Money.editingText(pool.budgetMinor)
        note = pool.note ?? ""
    }
}
