import Foundation
import FirebaseFirestore

struct Ping: Identifiable, Codable, Equatable {
    static let contributionKind = "contribution"

    @DocumentID var id: String?
    var recipientUid: String
    var senderUid: String
    var sentAt: Date?
    var readAt: Date?
    var memberAmountAtSend: Int
    var kind: String

    var isUnread: Bool { readAt == nil }
}
