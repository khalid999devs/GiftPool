import Foundation
import FirebaseFirestore

extension FirestoreGiftPoolRepository {

    func updateAssignments(_ amounts: [String: Int], members: [Member], poolId: String) async throws {
        let batch = db.batch()
        var hasChanges = false

        for member in members {
            guard let newAmount = amounts[member.uid], newAmount != member.assignedMinor else { continue }
            var data: [String: Any] = [
                "assignedMinor": newAmount,
                "reportedGivenAt": FieldValue.delete()
            ]
            if newAmount > 0 && newAmount == member.collectedMinor {
                data["settledAt"] = FieldValue.serverTimestamp()
            }
            batch.updateData(data, forDocument: membersCollection(poolId).document(member.uid))
            hasChanges = true
        }

        guard hasChanges else { return }
        try await batch.commit()
    }

    func recordCollection(_ collectedMinor: Int, for member: Member, poolId: String) async throws {
        var data: [String: Any] = [
            "collectedMinor": collectedMinor,
            "reportedGivenAt": FieldValue.delete()
        ]
        if collectedMinor > 0 && collectedMinor == member.assignedMinor {
            data["settledAt"] = FieldValue.serverTimestamp()
        }
        try await membersCollection(poolId).document(member.uid).updateData(data)
    }

    func reportGiven(poolId: String, uid: String) async throws {
        try await membersCollection(poolId).document(uid).updateData([
            "reportedGivenAt": FieldValue.serverTimestamp()
        ])
    }

    func clearReport(for member: Member, poolId: String) async throws {
        try await membersCollection(poolId).document(member.uid).updateData([
            "reportedGivenAt": FieldValue.delete()
        ])
    }

    // lastPingAt is updated in the same batch; the rules use it for the 24h cooldown.
    func sendPing(to member: Member, poolId: String, senderUid: String) async throws {
        let batch = db.batch()
        batch.setData([
            "recipientUid": member.uid,
            "senderUid": senderUid,
            "sentAt": FieldValue.serverTimestamp(),
            "memberAmountAtSend": member.outstandingMinor,
            "kind": Ping.contributionKind
        ], forDocument: pingsCollection(poolId).document())

        batch.updateData([
            "lastPingAt": FieldValue.serverTimestamp(),
            "pingCount": FieldValue.increment(Int64(1))
        ], forDocument: membersCollection(poolId).document(member.uid))

        try await batch.commit()
    }

    // Read my reminders in one pool
    func listenToPings(poolId: String, recipientUid: String, onChange: @escaping ResultHandler<[Ping]>) -> ListenerRegistration {
        let query = pingsCollection(poolId).whereField("recipientUid", isEqualTo: recipientUid)

        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let pings = snapshot?.documents.compactMap { document in
                try? document.data(as: Ping.self, with: .estimate)
            } ?? []
            onChange(.success(pings))
        }
    }

    func markPingRead(pingId: String, poolId: String) async throws {
        try await pingsCollection(poolId).document(pingId).updateData([
            "readAt": FieldValue.serverTimestamp()
        ])
    }
}
