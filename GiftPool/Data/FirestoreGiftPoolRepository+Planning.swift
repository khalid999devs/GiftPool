import Foundation
import FirebaseFirestore

extension FirestoreGiftPoolRepository {

    // MARK: Ideas

    // Read ideas
    func listenToIdeas(poolId: String, onChange: @escaping ResultHandler<[GiftIdea]>) -> ListenerRegistration {
        ideasCollection(poolId).order(by: "createdAt").addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let ideas = snapshot?.documents.compactMap { document in
                try? document.data(as: GiftIdea.self, with: .estimate)
            } ?? []
            onChange(.success(ideas))
        }
    }

    func listenToIdea(poolId: String, ideaId: String, onChange: @escaping ResultHandler<GiftIdea?>) -> ListenerRegistration {
        ideasCollection(poolId).document(ideaId).addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let idea = try? snapshot?.data(as: GiftIdea.self, with: .estimate)
            onChange(.success(idea))
        }
    }

    // Create idea, with its photo in the same batch
    func addIdea(_ input: IdeaInput, poolId: String, uid: String) async throws {
        let idea = ideasCollection(poolId).document()
        let batch = db.batch()

        var data: [String: Any] = [
            "title": input.title,
            "estimatedMinor": input.estimatedMinor,
            "createdBy": uid,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let note = input.note {
            data["note"] = note
        }
        if let categoryKey = input.categoryKey {
            data["categoryKey"] = categoryKey
        }
        if let link = input.link {
            data["link"] = link
        }
        if case .set(let jpeg) = input.photo {
            data["photoId"] = UUID().uuidString
            batch.setData(photoData(jpeg), forDocument: ideaPhotoDoc(idea.documentID, poolId: poolId))
        }

        batch.setData(data, forDocument: idea)
        try await batch.commit()
    }

    // Update idea
    func updateIdea(_ input: IdeaInput, ideaId: String, poolId: String) async throws {
        let batch = db.batch()

        var data: [String: Any] = [
            "title": input.title,
            "estimatedMinor": input.estimatedMinor,
            "note": valueOrDelete(input.note),
            "categoryKey": valueOrDelete(input.categoryKey),
            "link": valueOrDelete(input.link)
        ]

        switch input.photo {
        case .keep:
            break
        case .set(let jpeg):
            data["photoId"] = UUID().uuidString
            batch.setData(photoData(jpeg), forDocument: ideaPhotoDoc(ideaId, poolId: poolId))
        case .remove:
            data["photoId"] = FieldValue.delete()
            batch.deleteDocument(ideaPhotoDoc(ideaId, poolId: poolId))
        }

        batch.updateData(data, forDocument: ideasCollection(poolId).document(ideaId))
        try await batch.commit()
    }

    // Delete idea, together with its votes and photo
    func deleteIdea(ideaId: String, poolId: String, clearsSelection: Bool) async throws {
        let votes = try await votesCollection(poolId).whereField("ideaId", isEqualTo: ideaId).getDocuments()
        let batch = db.batch()

        for vote in votes.documents {
            batch.deleteDocument(vote.reference)
        }
        batch.deleteDocument(ideasCollection(poolId).document(ideaId))
        batch.deleteDocument(ideaPhotoDoc(ideaId, poolId: poolId))

        if clearsSelection {
            batch.updateData([
                "selectedIdeaId": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: poolDoc(poolId))
        }

        try await batch.commit()
    }

    // Read one idea's photo. It's only downloaded when a card shows it.
    func fetchIdeaPhoto(ideaId: String, poolId: String) async throws -> Data? {
        let snapshot = try await ideaPhotoDoc(ideaId, poolId: poolId).getDocument()
        return snapshot.data()?["jpeg"] as? Data
    }

    func photoData(_ jpeg: Data) -> [String: Any] {
        return [
            "jpeg": jpeg,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func selectIdea(_ ideaId: String?, poolId: String) async throws {
        try await poolDoc(poolId).updateData([
            "selectedIdeaId": valueOrDelete(ideaId),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: Votes

    func listenToVotes(poolId: String, onChange: @escaping ResultHandler<[Vote]>) -> ListenerRegistration {
        votesCollection(poolId).addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let votes = snapshot?.documents.compactMap { document in
                try? document.data(as: Vote.self)
            } ?? []
            onChange(.success(votes))
        }
    }

    // Vote doc id is the voter's uid, so each member only ever has one vote.
    func castVote(ideaId: String, poolId: String, uid: String) async throws {
        try await votesCollection(poolId).document(uid).setData([
            "ideaId": ideaId,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func removeVote(poolId: String, uid: String) async throws {
        try await votesCollection(poolId).document(uid).delete()
    }

    // MARK: Checklist

    // Read tasks
    func listenToTasks(poolId: String, onChange: @escaping ResultHandler<[GiftTask]>) -> ListenerRegistration {
        tasksCollection(poolId).order(by: "sortOrder").addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            let tasks = snapshot?.documents.compactMap { document in
                try? document.data(as: GiftTask.self, with: .estimate)
            } ?? []
            onChange(.success(tasks))
        }
    }

    // Create task
    func addTask(_ input: TaskInput, poolId: String, sortOrder: Int) async throws {
        var data: [String: Any] = [
            "title": input.title,
            "isDone": false,
            "sortOrder": sortOrder,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let uid = input.assignedToUid {
            data["assignedToUid"] = uid
        }
        if let date = input.dueDate {
            data["dueDate"] = Timestamp(date: date)
        }

        try await tasksCollection(poolId).addDocument(data: data)
    }

    // Update task
    func updateTask(_ input: TaskInput, taskId: String, poolId: String) async throws {
        var dueDate: Timestamp?
        if let date = input.dueDate {
            dueDate = Timestamp(date: date)
        }

        try await tasksCollection(poolId).document(taskId).updateData([
            "title": input.title,
            "assignedToUid": valueOrDelete(input.assignedToUid),
            "dueDate": valueOrDelete(dueDate)
        ])
    }

    func setTaskDone(_ isDone: Bool, taskId: String, poolId: String) async throws {
        try await tasksCollection(poolId).document(taskId).updateData([
            "isDone": isDone,
            "completedAt": isDone ? FieldValue.serverTimestamp() : FieldValue.delete()
        ])
    }

    // Delete task
    func deleteTask(taskId: String, poolId: String) async throws {
        try await tasksCollection(poolId).document(taskId).delete()
    }

    func reorderTasks(_ orderedIds: [String], poolId: String) async throws {
        let batch = db.batch()

        for (index, taskId) in orderedIds.enumerated() {
            batch.updateData(["sortOrder": index], forDocument: tasksCollection(poolId).document(taskId))
        }
        try await batch.commit()
    }
}
