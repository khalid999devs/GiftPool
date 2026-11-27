import Foundation
import FirebaseFirestore

struct ChatMessage: Identifiable, Codable, Equatable {
    static let maxBodyLength = 500
    // Like Messenger, a message can be edited for 15 minutes after it's sent.
    static let editWindow: TimeInterval = 15 * 60

    @DocumentID var id: String?
    var senderUid: String
    var body: String
    var createdAt: Date?
    var clientNonce: String
    // Set when the sender unsends it; the text is cleared for everyone.
    var unsentAt: Date? = nil
    var editedAt: Date? = nil

    var stableId: String { id ?? clientNonce }
    var isUnsent: Bool { unsentAt != nil }
    var isEdited: Bool { editedAt != nil }
}

enum MessageDelivery: Equatable {
    case sending
    case failed(String)
    case delivered
}
