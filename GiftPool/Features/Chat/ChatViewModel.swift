import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ChatViewModel: ObservableObject {
    static let pageSize = 30

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var pendingIds: Set<String> = []
    @Published private(set) var failedIds: Set<String> = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasOlder = false
    @Published var draft = ""
    // The message being edited in the composer, if any.
    @Published private(set) var editing: ChatMessage?
    @Published var errorMessage: String?
    @Published private(set) var loadError: String?

    private let poolId: String
    private let repository: GiftPoolRepository
    private let listeners = ListenerBag()

    // Keep every message seen so far; the live query only covers the newest page.
    private var messagesById: [String: ChatMessage] = [:]
    private var failedMessages: [String: ChatMessage] = [:]
    private var oldestCursor: DocumentSnapshot?

    init(poolId: String, repository: GiftPoolRepository) {
        self.poolId = poolId
        self.repository = repository
    }

    var canSend: Bool {
        guard let body = Validators.sendableMessage(draft) else { return false }
        return body != editing?.body
    }

    func delivery(of message: ChatMessage) -> MessageDelivery {
        if failedIds.contains(message.stableId) {
            return .failed("Not sent")
        }
        if pendingIds.contains(message.stableId) {
            return .sending
        }
        return .delivered
    }

    // MARK: Listening

    func start() {
        guard listeners.isEmpty else { return }

        let registration = repository.listenToRecentMessages(poolId: poolId, limit: Self.pageSize) { [weak self] result in
            self?.handleLivePage(result)
        }
        listeners.add(registration)
    }

    private func handleLivePage(_ result: Result<MessagePage, Error>) {
        isLoading = false

        switch result {
        case .success(let page):
            for message in page.messages {
                messagesById[message.stableId] = message
            }
            pendingIds = page.pendingIds

            if oldestCursor == nil {
                oldestCursor = page.oldestCursor
                hasOlder = page.isFullPage
            }
            rebuild()

        case .failure(let error):
            errorMessage = ErrorMessages.friendly(error)
            loadError = ErrorMessages.friendly(error)
        }
    }

    func loadOlder() async {
        guard let cursor = oldestCursor, !isLoadingOlder else { return }

        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let page = try await repository.fetchMessages(poolId: poolId, before: cursor, limit: Self.pageSize)
            for message in page.messages {
                messagesById[message.stableId] = message
            }
            oldestCursor = page.oldestCursor ?? cursor
            hasOlder = page.isFullPage
            rebuild()
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    // MARK: Sending

    func send(as senderUid: String) {
        guard let body = Validators.sendableMessage(draft) else { return }

        if let message = editing {
            saveEdit(of: message, body: body)
            return
        }

        draft = ""
        let id = UUID().uuidString
        Task { await deliver(id: id, body: body, senderUid: senderUid) }
    }

    func retry(_ message: ChatMessage) {
        let id = message.stableId
        Task { await deliver(id: id, body: message.body, senderUid: message.senderUid) }
    }

    func discard(_ message: ChatMessage) {
        failedMessages[message.stableId] = nil
        failedIds.remove(message.stableId)
        rebuild()
    }

    // MARK: Editing and unsending (your own sent messages only)

    func canUnsend(_ message: ChatMessage, myUid: String) -> Bool {
        message.senderUid == myUid && message.id != nil && !message.isUnsent && delivery(of: message) == .delivered
    }

    func canEdit(_ message: ChatMessage, myUid: String) -> Bool {
        guard let sentAt = message.createdAt else { return false }
        return canUnsend(message, myUid: myUid) && Date.now.timeIntervalSince(sentAt) < ChatMessage.editWindow
    }

    func startEditing(_ message: ChatMessage) {
        editing = message
        draft = message.body
    }

    func cancelEditing() {
        editing = nil
        draft = ""
    }

    private func saveEdit(of message: ChatMessage, body: String) {
        guard let id = message.id else { return }
        editing = nil
        draft = ""

        Task {
            do {
                try await repository.editMessage(id: id, body: body, poolId: poolId)
                if var copy = messagesById[id] {
                    copy.body = body
                    copy.editedAt = .now
                    messagesById[id] = copy
                    rebuild()
                }
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
        }
    }

    func unsend(_ message: ChatMessage) {
        guard let id = message.id else { return }

        Task {
            do {
                try await repository.unsendMessage(id: id, poolId: poolId)
                // Older pages aren't listened to, so update the local copy too.
                if var copy = messagesById[id], !copy.isUnsent {
                    copy.body = ""
                    copy.unsentAt = .now
                    messagesById[id] = copy
                    rebuild()
                }
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
        }
    }

    private func deliver(id: String, body: String, senderUid: String) async {
        failedIds.remove(id)
        failedMessages[id] = nil
        rebuild()

        do {
            try await repository.sendMessage(id: id, body: body, poolId: poolId, senderUid: senderUid)
        } catch {
            // Firestore drops a rejected write, so keep a copy for Retry.
            failedMessages[id] = ChatMessage(id: nil, senderUid: senderUid, body: body, createdAt: .now, clientNonce: id)
            failedIds.insert(id)
            errorMessage = ErrorMessages.friendly(error)
            rebuild()
        }
    }

    private func rebuild() {
        var all = messagesById
        for (id, message) in failedMessages where all[id] == nil {
            all[id] = message
        }

        messages = all.values.sorted { lhs, rhs in
            let lhsDate = lhs.createdAt ?? .distantFuture
            let rhsDate = rhs.createdAt ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.stableId < rhs.stableId
        }
    }
}
