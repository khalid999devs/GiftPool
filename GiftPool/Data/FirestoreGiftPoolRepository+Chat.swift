import Foundation
import FirebaseFirestore

extension FirestoreGiftPoolRepository {

    // Read the newest messages.
    // Metadata changes are included so a message stops showing "Sending…" once the server has it.
    func listenToRecentMessages(poolId: String, limit: Int, onChange: @escaping ResultHandler<MessagePage>) -> ListenerRegistration {
        let query = messagesCollection(poolId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        return query.addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }
            guard let snapshot = snapshot else { return }

            onChange(.success(self.makePage(from: snapshot, limit: limit)))
        }
    }

    // Read older messages, one page at a time
    func fetchMessages(poolId: String, before cursor: DocumentSnapshot, limit: Int) async throws -> MessagePage {
        let snapshot = try await messagesCollection(poolId)
            .order(by: "createdAt", descending: true)
            .start(afterDocument: cursor)
            .limit(to: limit)
            .getDocuments()

        return makePage(from: snapshot, limit: limit)
    }

    // Create message
    func sendMessage(id: String, body: String, poolId: String, senderUid: String) async throws {
        try await messagesCollection(poolId).document(id).setData([
            "senderUid": senderUid,
            "body": body,
            "createdAt": FieldValue.serverTimestamp(),
            "clientNonce": id
        ])
    }

    // Edit the text of a sent message
    func editMessage(id: String, body: String, poolId: String) async throws {
        try await messagesCollection(poolId).document(id).updateData([
            "body": body,
            "editedAt": FieldValue.serverTimestamp()
        ])
    }

    // Unsend: clear the text for everyone; the bubble then says the message was unsent
    func unsendMessage(id: String, poolId: String) async throws {
        try await messagesCollection(poolId).document(id).updateData([
            "body": "",
            "unsentAt": FieldValue.serverTimestamp()
        ])
    }

    private func makePage(from snapshot: QuerySnapshot, limit: Int) -> MessagePage {
        var messages: [ChatMessage] = []
        var pendingIds: Set<String> = []

        for document in snapshot.documents {
            if let message = try? document.data(as: ChatMessage.self, with: .estimate) {
                messages.append(message)
            }
            if document.metadata.hasPendingWrites {
                pendingIds.insert(document.documentID)
            }
        }

        return MessagePage(
            messages: messages,
            pendingIds: pendingIds,
            oldestCursor: snapshot.documents.last,
            isFullPage: snapshot.documents.count >= limit
        )
    }
}
