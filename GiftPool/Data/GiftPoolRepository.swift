import Foundation
import FirebaseFirestore

typealias ResultHandler<T> = (Result<T, Error>) -> Void

struct MessagePage {
    let messages: [ChatMessage]
    let pendingIds: Set<String>
    let oldestCursor: DocumentSnapshot?
    let isFullPage: Bool
}

protocol GiftPoolRepository: AnyObject {
    // MARK: Profile
    func fetchProfile(uid: String) async throws -> UserProfile?
    func createProfile(uid: String, displayName: String, email: String) async throws
    func updateDisplayName(_ name: String, uid: String, poolIds: [String]) async throws
    func updateAvatar(_ avatarId: String?, uid: String, poolIds: [String]) async throws
    func saveDeviceToken(_ token: String, uid: String) async throws
    func removeDeviceToken(_ token: String, uid: String) async throws

    // MARK: Pools
    func listenToPoolRefs(uid: String, onChange: @escaping ResultHandler<[PoolRef]>) -> ListenerRegistration
    func listenToPool(id: String, onChange: @escaping ResultHandler<Pool?>) -> ListenerRegistration
    func createPool(_ input: PoolInput, owner: SessionUser, taskTitles: [String]) async throws -> String
    func updatePool(id: String, input: PoolInput) async throws
    func changeStatus(poolId: String, to status: PoolStatus) async throws
    func softDeletePool(id: String) async throws

    // MARK: Invitations and membership
    func fetchInvite(token: String) async throws -> Invite?
    func hasJoined(poolId: String, uid: String) async throws -> Bool
    func joinPool(with invite: Invite, user: SessionUser) async throws
    func regenerateInvite(for pool: Pool, ownerName: String) async throws
    func revokeInvite(for pool: Pool) async throws
    func listenToMembers(poolId: String, onChange: @escaping ResultHandler<[Member]>) -> ListenerRegistration
    func listenToMember(poolId: String, uid: String, onChange: @escaping ResultHandler<Member?>) -> ListenerRegistration

    // MARK: Ideas and votes
    func listenToIdeas(poolId: String, onChange: @escaping ResultHandler<[GiftIdea]>) -> ListenerRegistration
    func listenToIdea(poolId: String, ideaId: String, onChange: @escaping ResultHandler<GiftIdea?>) -> ListenerRegistration
    func listenToVotes(poolId: String, onChange: @escaping ResultHandler<[Vote]>) -> ListenerRegistration
    func addIdea(_ input: IdeaInput, poolId: String, uid: String) async throws
    func updateIdea(_ input: IdeaInput, ideaId: String, poolId: String) async throws
    func deleteIdea(ideaId: String, poolId: String, clearsSelection: Bool) async throws
    func fetchIdeaPhoto(ideaId: String, poolId: String) async throws -> Data?
    func castVote(ideaId: String, poolId: String, uid: String) async throws
    func removeVote(poolId: String, uid: String) async throws
    func selectIdea(_ ideaId: String?, poolId: String) async throws

    // MARK: Contributions and reminders
    func updateAssignments(_ amounts: [String: Int], members: [Member], poolId: String) async throws
    func recordCollection(_ collectedMinor: Int, for member: Member, poolId: String) async throws
    func reportGiven(poolId: String, uid: String) async throws
    func clearReport(for member: Member, poolId: String) async throws
    func sendPing(to member: Member, poolId: String, senderUid: String) async throws
    func listenToPings(poolId: String, recipientUid: String, onChange: @escaping ResultHandler<[Ping]>) -> ListenerRegistration
    func markPingRead(pingId: String, poolId: String) async throws

    // MARK: Checklist
    func listenToTasks(poolId: String, onChange: @escaping ResultHandler<[GiftTask]>) -> ListenerRegistration
    func addTask(_ input: TaskInput, poolId: String, sortOrder: Int) async throws
    func updateTask(_ input: TaskInput, taskId: String, poolId: String) async throws
    func setTaskDone(_ isDone: Bool, taskId: String, poolId: String) async throws
    func deleteTask(taskId: String, poolId: String) async throws
    func reorderTasks(_ orderedIds: [String], poolId: String) async throws

    // MARK: Chat
    func listenToRecentMessages(poolId: String, limit: Int, onChange: @escaping ResultHandler<MessagePage>) -> ListenerRegistration
    func fetchMessages(poolId: String, before cursor: DocumentSnapshot, limit: Int) async throws -> MessagePage
    func sendMessage(id: String, body: String, poolId: String, senderUid: String) async throws
    func editMessage(id: String, body: String, poolId: String) async throws
    func unsendMessage(id: String, poolId: String) async throws
}
