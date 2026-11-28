import Foundation
import Combine

struct PoolOverview: Identifiable, Equatable {
    let pool: Pool
    let members: [Member]
    let tasks: [GiftTask]
    let selectedIdeaTitle: String?

    var id: String { pool.id ?? "" }
    var summary: BudgetSummary { MoneyCalculator.summarize(target: pool.budgetMinor, members: members) }
    var remainingTaskCount: Int { tasks.filter { !$0.isDone }.count }
}

@MainActor
final class HomeViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case history = "History"

        var id: Self { self }
    }

    @Published var segment: Segment = .active
    @Published private(set) var poolIds: [String] = []
    @Published private(set) var pools: [String: Pool] = [:]
    @Published private(set) var membersByPool: [String: [Member]] = [:]
    @Published private(set) var tasksByPool: [String: [GiftTask]] = [:]
    @Published private(set) var selectedIdeaTitles: [String: String] = [:]
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?
    @Published private(set) var loadError: String?

    let uid: String
    private let repository: GiftPoolRepository
    private let listeners = ListenerBag()
    private var observedSelection: [String: String] = [:]

    init(uid: String, repository: GiftPoolRepository) {
        self.uid = uid
        self.repository = repository
    }

    var overviews: [PoolOverview] {
        poolIds.compactMap { id in
            guard let pool = pools[id], !pool.isDeleted else { return nil }
            return PoolOverview(
                pool: pool,
                members: membersByPool[id] ?? [],
                tasks: tasksByPool[id] ?? [],
                selectedIdeaTitle: selectedIdeaTitles[id]
            )
        }
    }

    var activePools: [PoolOverview] {
        overviews
            .filter { $0.pool.status.isActive }
            .sorted { $0.pool.occasionDate < $1.pool.occasionDate }
    }

    var historyPools: [PoolOverview] {
        overviews
            .filter { !$0.pool.status.isActive }
            .sorted { endDate(of: $0.pool) > endDate(of: $1.pool) }
    }

    func start() {
        guard listeners.isEmpty else { return }
        listenToRefs()
    }

    func retry() {
        loadError = nil
        isLoading = true
        listeners.remove(key: "refs")
        listenToRefs()
    }

    private func listenToRefs() {
        let registration = repository.listenToPoolRefs(uid: uid) { [weak self] result in
            self?.handleRefs(result)
        }
        listeners.add(registration, key: "refs")
    }

    func createPool(_ draft: PoolDraft, taskTitles: [String], owner: SessionUser) async throws -> String {
        let input = try draft.validated(isNew: true)
        let titles = taskTitles.map(Validators.trimmed).filter { !$0.isEmpty }
        return try await repository.createPool(input, owner: owner, taskTitles: titles)
    }

    private func endDate(of pool: Pool) -> Date {
        pool.completedAt ?? pool.updatedAt ?? pool.occasionDate
    }

    private func handleRefs(_ result: Result<[PoolRef], Error>) {
        switch result {
        case .failure(let error):
            loadError = ErrorMessages.friendly(error)
            isLoading = false
        case .success(let refs):
            loadError = nil
            let newIds = Set(refs.map(\.poolId))
            let oldIds = Set(poolIds)
            oldIds.subtracting(newIds).forEach(stopObserving)
            newIds.subtracting(oldIds).forEach(observe)
            poolIds = refs.map(\.poolId)
            if newIds.isEmpty || newIds.isSubset(of: Set(pools.keys)) {
                isLoading = false
            }
        }
    }

    private func observe(_ poolId: String) {
        listeners.add(repository.listenToPool(id: poolId) { [weak self] result in
            self?.handlePool(result, poolId: poolId)
        }, key: poolId)

        listeners.add(repository.listenToMembers(poolId: poolId) { [weak self] result in
            switch result {
            case .success(let members): self?.membersByPool[poolId] = members
            case .failure(let error): self?.errorMessage = ErrorMessages.friendly(error)
            }
        }, key: poolId)

        listeners.add(repository.listenToTasks(poolId: poolId) { [weak self] result in
            switch result {
            case .success(let tasks): self?.tasksByPool[poolId] = tasks
            case .failure(let error): self?.errorMessage = ErrorMessages.friendly(error)
            }
        }, key: poolId)
    }

    private func stopObserving(_ poolId: String) {
        listeners.remove(key: poolId)
        listeners.remove(key: selectionKey(poolId))
        pools[poolId] = nil
        membersByPool[poolId] = nil
        tasksByPool[poolId] = nil
        selectedIdeaTitles[poolId] = nil
        observedSelection[poolId] = nil
    }

    private func handlePool(_ result: Result<Pool?, Error>, poolId: String) {
        isLoading = false
        switch result {
        case .success(let pool):
            pools[poolId] = pool
            updateSelectionListener(poolId: poolId, ideaId: pool?.selectedIdeaId)
        case .failure(let error):
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    private func updateSelectionListener(poolId: String, ideaId: String?) {
        guard observedSelection[poolId] != ideaId else { return }
        observedSelection[poolId] = ideaId
        let key = selectionKey(poolId)

        guard let ideaId else {
            listeners.remove(key: key)
            selectedIdeaTitles[poolId] = nil
            return
        }
        listeners.replace(repository.listenToIdea(poolId: poolId, ideaId: ideaId) { [weak self] result in
            switch result {
            case .success(let idea): self?.selectedIdeaTitles[poolId] = idea?.title
            case .failure(let error): self?.errorMessage = ErrorMessages.friendly(error)
            }
        }, key: key)
    }

    private func selectionKey(_ poolId: String) -> String {
        "selection-\(poolId)"
    }
}
