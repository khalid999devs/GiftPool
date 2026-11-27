import Foundation
import FirebaseFirestore

struct GiftIdea: Identifiable, Codable, Equatable {
    static let maxTitleLength = 80
    static let maxNoteLength = 200

    @DocumentID var id: String?
    var title: String
    var estimatedMinor: Int
    var note: String?
    var categoryKey: String?
    var link: String?
    // Changes whenever the photo changes, so cards know to load the new one.
    var photoId: String?
    var createdBy: String
    var createdAt: Date?
}

// What should happen to an idea's photo when it's saved.
enum PhotoChange: Equatable {
    case keep
    case set(Data)
    case remove
}

struct IdeaDraft: Equatable {
    var title = ""
    var priceText = ""
    var note = ""
    var categoryKey: String?
    var link = ""
    var photo: PhotoChange = .keep

    init() {}

    init(idea: GiftIdea) {
        title = idea.title
        priceText = Money.editingText(idea.estimatedMinor)
        note = idea.note ?? ""
        categoryKey = idea.categoryKey
        link = idea.link ?? ""
    }
}
