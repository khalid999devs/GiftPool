import Foundation
import FirebaseFirestore

struct Vote: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var ideaId: String
    var updatedAt: Date?

    var voterUid: String { id ?? "" }
}
