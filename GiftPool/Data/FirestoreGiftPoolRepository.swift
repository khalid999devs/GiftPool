import Foundation
import FirebaseFirestore

class FirestoreGiftPoolRepository: GiftPoolRepository {
    let db = Firestore.firestore()

    // MARK: Paths

    func userDoc(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    func poolRefsCollection(_ uid: String) -> CollectionReference {
        userDoc(uid).collection("poolRefs")
    }

    func poolDoc(_ poolId: String) -> DocumentReference {
        db.collection("pools").document(poolId)
    }

    func membersCollection(_ poolId: String) -> CollectionReference {
        poolDoc(poolId).collection("members")
    }

    func ideasCollection(_ poolId: String) -> CollectionReference {
        poolDoc(poolId).collection("ideas")
    }

    func votesCollection(_ poolId: String) -> CollectionReference {
        poolDoc(poolId).collection("votes")
    }

    func ideaPhotoDoc(_ ideaId: String, poolId: String) -> DocumentReference {
        poolDoc(poolId).collection("ideaPhotos").document(ideaId)
    }

    func tasksCollection(_ poolId: String) -> CollectionReference {
        poolDoc(poolId).collection("tasks")
    }

    func messagesCollection(_ poolId: String) -> CollectionReference {
        poolDoc(poolId).collection("messages")
    }

    func pingsCollection(_ poolId: String) -> CollectionReference {
        poolDoc(poolId).collection("pings")
    }

    func inviteDoc(_ token: String) -> DocumentReference {
        db.collection("invites").document(token)
    }

    // An empty optional field is removed from the document instead of being saved as null.
    func valueOrDelete(_ value: Any?) -> Any {
        if let value = value {
            return value
        }
        return FieldValue.delete()
    }

    // MARK: Profile

    func fetchProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await userDoc(uid).getDocument()
        if !snapshot.exists {
            return nil
        }
        return try snapshot.data(as: UserProfile.self)
    }

    func createProfile(uid: String, displayName: String, email: String) async throws {
        try await userDoc(uid).setData([
            "displayName": displayName,
            "email": email,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func updateDisplayName(_ name: String, uid: String, poolIds: [String]) async throws {
        let batch = db.batch()
        batch.updateData(["displayName": name], forDocument: userDoc(uid))

        for poolId in poolIds {
            batch.updateData(["displayName": name], forDocument: membersCollection(poolId).document(uid))
        }
        try await batch.commit()
    }

    // The avatar is copied to every plan, like the name, so other members can see it.
    // nil goes back to initials.
    func updateAvatar(_ avatarId: String?, uid: String, poolIds: [String]) async throws {
        let value: Any = avatarId ?? FieldValue.delete()
        let batch = db.batch()
        batch.updateData(["avatarId": value], forDocument: userDoc(uid))

        for poolId in poolIds {
            batch.updateData(["avatarId": value], forDocument: membersCollection(poolId).document(uid))
        }
        try await batch.commit()
    }

    // Each phone saves its push token here, so the Cloud Function knows where to send reminders.
    func saveDeviceToken(_ token: String, uid: String) async throws {
        try await userDoc(uid).collection("devices").document(token).setData([
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func removeDeviceToken(_ token: String, uid: String) async throws {
        try await userDoc(uid).collection("devices").document(token).delete()
    }

    // MARK: Pools

    // Read the pools I belong to.
    // Refs that haven't reached the server yet are skipped, otherwise the pool listener can be denied.
    func listenToPoolRefs(uid: String, onChange: @escaping ResultHandler<[PoolRef]>) -> ListenerRegistration {
        poolRefsCollection(uid).addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let confirmed = snapshot?.documents.filter { !$0.metadata.hasPendingWrites } ?? []
            let refs = confirmed.compactMap { document in
                try? document.data(as: PoolRef.self)
            }
            onChange(.success(refs))
        }
    }

    // Read one pool
    func listenToPool(id: String, onChange: @escaping ResultHandler<Pool?>) -> ListenerRegistration {
        poolDoc(id).addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let pool = try? snapshot?.data(as: Pool.self, with: .estimate)
            onChange(.success(pool))
        }
    }

    // Create pool
    // Everything for a new pool goes in one batch so it can't be half created.
    func createPool(_ input: PoolInput, owner: SessionUser, taskTitles: [String]) async throws -> String {
        let pool = db.collection("pools").document()
        let poolId = pool.documentID
        let token = InviteService.makeToken()
        let batch = db.batch()

        var poolData: [String: Any] = [
            "title": input.title,
            "recipientName": input.recipientName,
            "occasionKey": input.occasionKey,
            "occasionDate": Timestamp(date: input.occasionDate),
            "budgetMinor": input.budgetMinor,
            "ownerUid": owner.uid,
            "status": PoolStatus.planning.rawValue,
            "isDeleted": false,
            "inviteToken": token,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let note = input.note {
            poolData["note"] = note
        }
        batch.setData(poolData, forDocument: pool)

        var ownerData: [String: Any] = [
            "uid": owner.uid,
            "displayName": owner.displayName,
            "role": MemberRole.owner.rawValue,
            "assignedMinor": 0,
            "collectedMinor": 0,
            "pingCount": 0,
            "joinedAt": FieldValue.serverTimestamp()
        ]
        ownerData["avatarId"] = owner.avatarId
        batch.setData(ownerData, forDocument: membersCollection(poolId).document(owner.uid))

        batch.setData([
            "poolId": poolId,
            "joinedAt": FieldValue.serverTimestamp()
        ], forDocument: poolRefsCollection(owner.uid).document(poolId))

        let invite = inviteData(poolId: poolId, poolTitle: input.title, ownerUid: owner.uid, ownerName: owner.displayName)
        batch.setData(invite, forDocument: inviteDoc(token))

        for (index, title) in taskTitles.enumerated() {
            batch.setData([
                "title": title,
                "isDone": false,
                "sortOrder": index,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: tasksCollection(poolId).document())
        }

        try await batch.commit()
        return poolId
    }

    // Update pool
    func updatePool(id: String, input: PoolInput) async throws {
        try await poolDoc(id).updateData([
            "title": input.title,
            "recipientName": input.recipientName,
            "occasionKey": input.occasionKey,
            "occasionDate": Timestamp(date: input.occasionDate),
            "budgetMinor": input.budgetMinor,
            "note": valueOrDelete(input.note),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func changeStatus(poolId: String, to status: PoolStatus) async throws {
        var data: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if status == .completed {
            data["completedAt"] = FieldValue.serverTimestamp()
        }
        try await poolDoc(poolId).updateData(data)
    }

    // Delete pool
    // Firestore doesn't delete subcollections, so plans are only hidden.
    func softDeletePool(id: String) async throws {
        try await poolDoc(id).updateData([
            "isDeleted": true,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: Invitations and membership

    func inviteData(poolId: String, poolTitle: String, ownerUid: String, ownerName: String) -> [String: Any] {
        return [
            "poolId": poolId,
            "createdBy": ownerUid,
            "isActive": true,
            "expiresAt": Timestamp(date: InviteService.expiryDate()),
            "poolTitle": poolTitle,
            "ownerName": ownerName,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }

    func fetchInvite(token: String) async throws -> Invite? {
        let snapshot = try await inviteDoc(token).getDocument()
        if !snapshot.exists {
            return nil
        }
        return try snapshot.data(as: Invite.self)
    }

    func hasJoined(poolId: String, uid: String) async throws -> Bool {
        let snapshot = try await poolRefsCollection(uid).document(poolId).getDocument()
        return snapshot.exists
    }

    // inviteToken is saved on the member so the rules can check the invite.
    func joinPool(with invite: Invite, user: SessionUser) async throws {
        let batch = db.batch()

        var memberData: [String: Any] = [
            "uid": user.uid,
            "displayName": user.displayName,
            "role": MemberRole.member.rawValue,
            "assignedMinor": 0,
            "collectedMinor": 0,
            "pingCount": 0,
            "inviteToken": invite.token,
            "joinedAt": FieldValue.serverTimestamp()
        ]
        memberData["avatarId"] = user.avatarId
        batch.setData(memberData, forDocument: membersCollection(invite.poolId).document(user.uid))

        batch.setData([
            "poolId": invite.poolId,
            "joinedAt": FieldValue.serverTimestamp()
        ], forDocument: poolRefsCollection(user.uid).document(invite.poolId))

        try await batch.commit()
    }

    func regenerateInvite(for pool: Pool, ownerName: String) async throws {
        guard let poolId = pool.id else { return }

        let token = InviteService.makeToken()
        let batch = db.batch()

        if let oldToken = pool.inviteToken {
            batch.updateData(["isActive": false], forDocument: inviteDoc(oldToken))
        }

        let invite = inviteData(poolId: poolId, poolTitle: pool.title, ownerUid: pool.ownerUid, ownerName: ownerName)
        batch.setData(invite, forDocument: inviteDoc(token))

        batch.updateData([
            "inviteToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: poolDoc(poolId))

        try await batch.commit()
    }

    func revokeInvite(for pool: Pool) async throws {
        guard let poolId = pool.id, let token = pool.inviteToken else { return }

        let batch = db.batch()
        batch.updateData(["isActive": false], forDocument: inviteDoc(token))
        batch.updateData([
            "inviteToken": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: poolDoc(poolId))

        try await batch.commit()
    }

    // Read members
    func listenToMembers(poolId: String, onChange: @escaping ResultHandler<[Member]>) -> ListenerRegistration {
        membersCollection(poolId).addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let members = snapshot?.documents.compactMap { document in
                try? document.data(as: Member.self, with: .estimate)
            } ?? []
            onChange(.success(members))
        }
    }

    func listenToMember(poolId: String, uid: String, onChange: @escaping ResultHandler<Member?>) -> ListenerRegistration {
        membersCollection(poolId).document(uid).addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let member = try? snapshot?.data(as: Member.self, with: .estimate)
            onChange(.success(member))
        }
    }
}
