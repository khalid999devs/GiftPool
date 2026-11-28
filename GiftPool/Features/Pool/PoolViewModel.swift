import Foundation
import Combine

@MainActor
final class PoolViewModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case loaded
        case missing
        case failed(String)
    }

    // MARK: Published state

    @Published private(set) var pool: Pool?
    @Published private(set) var members: [Member] = []
    @Published private(set) var ideas: [GiftIdea] = []
    @Published private(set) var votes: [Vote] = []
    @Published private(set) var tasks: [GiftTask] = []
    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var busyKeys: Set<String> = []

    @Published var errorMessage: String?
    @Published var showCelebration = false

    // MARK: Dependencies

    let poolId: String
    let user: SessionUser
    let repository: GiftPoolRepository
    private let listeners = ListenerBag()

    init(poolId: String, user: SessionUser, repository: GiftPoolRepository) {
        self.poolId = poolId
        self.user = user
        self.repository = repository
    }

    // MARK: Derived values

    var uid: String { user.uid }

    var isOwner: Bool {
        pool?.isOwned(by: uid) ?? false
    }

    var isActive: Bool {
        pool?.isActive ?? false
    }

    // Ideas and votes are settled once the gift is bought.
    var isDeciding: Bool {
        isActive && pool?.status == .planning
    }

    var me: Member? {
        members.first { $0.uid == uid }
    }

    var summary: BudgetSummary {
        MoneyCalculator.summarize(target: pool?.budgetMinor ?? 0, members: members)
    }

    var sortedMembers: [Member] {
        members.sorted { lhs, rhs in
            if lhs.isOwner != rhs.isOwner {
                return lhs.isOwner
            }
            return (lhs.joinedAt ?? .distantFuture) < (rhs.joinedAt ?? .distantFuture)
        }
    }

    func member(withId uid: String?) -> Member? {
        guard let uid else { return nil }
        return members.first { $0.uid == uid }
    }

    func displayName(for uid: String?) -> String {
        guard let uid else { return "Unassigned" }
        if uid == self.uid {
            return "You"
        }
        return member(withId: uid)?.displayName ?? "Former member"
    }

    func isBusy(_ key: String) -> Bool {
        busyKeys.contains(key)
    }

    // MARK: Listening

    func start() {
        guard listeners.isEmpty else { return }

        listeners.add(repository.listenToPool(id: poolId) { [weak self] result in
            self?.handlePool(result)
        })

        listeners.add(repository.listenToMembers(poolId: poolId) { [weak self] result in
            self?.apply(result) { self?.members = $0 }
        })

        listeners.add(repository.listenToIdeas(poolId: poolId) { [weak self] result in
            self?.apply(result) { self?.ideas = $0 }
        })

        listeners.add(repository.listenToVotes(poolId: poolId) { [weak self] result in
            self?.apply(result) { self?.votes = $0 }
        })

        listeners.add(repository.listenToTasks(poolId: poolId) { [weak self] result in
            self?.apply(result) { self?.tasks = $0 }
        })
    }

    private func handlePool(_ result: Result<Pool?, Error>) {
        switch result {
        case .success(let newPool?):
            let wasCompleted = pool?.status == .completed
            let isFirstLoad = pool == nil
            pool = newPool
            loadState = newPool.isDeleted ? .missing : .loaded

            // Only celebrate the change to completed, not opening an old plan.
            if !isFirstLoad && !wasCompleted && newPool.status == .completed {
                showCelebration = true
            }

        case .success(nil):
            pool = nil
            loadState = .missing

        case .failure(let error):
            loadState = pool == nil ? .failed(ErrorMessages.friendly(error)) : loadState
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    private func apply<T>(_ result: Result<T, Error>, onSuccess: (T) -> Void) {
        switch result {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    // MARK: Running actions

    @discardableResult
    func perform(_ key: String, _ work: () async throws -> Void) async -> Bool {
        guard !busyKeys.contains(key) else { return false }

        busyKeys.insert(key)
        defer { busyKeys.remove(key) }

        do {
            try await work()
            return true
        } catch {
            errorMessage = ErrorMessages.friendly(error)
            return false
        }
    }

    @discardableResult
    func requireActivePool() throws -> Pool {
        guard let pool, pool.isActive else {
            throw AppError.poolClosed
        }
        return pool
    }

    // MARK: Pool-level actions (organizer)

    func updateDetails(_ draft: PoolDraft) async throws {
        let input = try draft.validated(isNew: false)
        try await repository.updatePool(id: poolId, input: input)
    }

    func changeStatus(to status: PoolStatus) async {
        guard let pool, pool.status.allowedNextStatuses.contains(status) else { return }

        await perform("status") {
            if !status.isActive {
                try? await repository.revokeInvite(for: pool)
            }
            try await repository.changeStatus(poolId: poolId, to: status)
        }
    }

    func deletePlan() async -> Bool {
        await perform("delete") {
            if let pool {
                try? await repository.revokeInvite(for: pool)
            }
            try await repository.softDeletePool(id: poolId)
        }
    }

    func regenerateInvite() async {
        guard let pool else { return }

        await perform("invite") {
            try await repository.regenerateInvite(for: pool, ownerName: user.displayName)
        }
    }

    func revokeInvite() async {
        guard let pool else { return }

        await perform("invite") {
            try await repository.revokeInvite(for: pool)
        }
    }

    func fetchCurrentInvite() async -> Invite? {
        guard let token = pool?.inviteToken else { return nil }
        return try? await repository.fetchInvite(token: token)
    }
}
