import Foundation
import Combine

struct ReminderItem: Identifiable, Equatable {
    let ping: Ping
    let poolId: String
    let poolTitle: String
    let status: ReminderStatus

    var id: String { "\(poolId)/\(ping.id ?? "")" }
}

@MainActor
final class RemindersViewModel: ObservableObject {
    @Published private(set) var items: [ReminderItem] = []
    @Published var errorMessage: String?

    private let uid: String
    private var repository: GiftPoolRepository?
    private let listeners = ListenerBag()

    private var observedPoolIds: Set<String> = []
    private var pools: [String: Pool] = [:]
    private var myMembership: [String: Member] = [:]
    private var pingsByPool: [String: [Ping]] = [:]

    init(uid: String) {
        self.uid = uid
    }

    var unreadCount: Int {
        items.filter { $0.ping.isUnread }.count
    }

    func items(forPool poolId: String) -> [ReminderItem] {
        items.filter { $0.poolId == poolId }
    }

    func openCount(poolId: String) -> Int {
        items.filter { $0.poolId == poolId && $0.status == .open }.count
    }

    // MARK: Listening

    func start(repository: GiftPoolRepository) {
        guard self.repository == nil else { return }
        self.repository = repository

        listeners.add(repository.listenToPoolRefs(uid: uid) { [weak self] result in
            switch result {
            case .success(let refs):
                self?.updateObservedPools(Set(refs.map(\.poolId)))
            case .failure(let error):
                self?.errorMessage = ErrorMessages.friendly(error)
            }
        }, key: "refs")
    }

    private func updateObservedPools(_ poolIds: Set<String>) {
        for removed in observedPoolIds.subtracting(poolIds) {
            listeners.remove(key: removed)
            pools[removed] = nil
            myMembership[removed] = nil
            pingsByPool[removed] = nil
        }

        for added in poolIds.subtracting(observedPoolIds) {
            observe(added)
        }

        observedPoolIds = poolIds
        rebuild()
    }

    private func observe(_ poolId: String) {
        guard let repository else { return }

        listeners.add(repository.listenToPool(id: poolId) { [weak self] result in
            if case .success(let pool) = result {
                self?.pools[poolId] = pool
                self?.rebuild()
            }
        }, key: poolId)

        listeners.add(repository.listenToMember(poolId: poolId, uid: uid) { [weak self] result in
            if case .success(let member) = result {
                self?.myMembership[poolId] = member
                self?.rebuild()
            }
        }, key: poolId)

        listeners.add(repository.listenToPings(poolId: poolId, recipientUid: uid) { [weak self] result in
            switch result {
            case .success(let pings):
                self?.pingsByPool[poolId] = pings
                self?.rebuild()
            case .failure(let error):
                self?.errorMessage = ErrorMessages.friendly(error)
            }
        }, key: poolId)
    }

    private func rebuild() {
        var result: [ReminderItem] = []

        for (poolId, pings) in pingsByPool {
            guard let pool = pools[poolId], !pool.isDeleted else { continue }

            for ping in pings {
                let status = ReminderRules.status(
                    of: ping,
                    member: myMembership[poolId],
                    poolIsActive: pool.isActive
                )
                result.append(ReminderItem(ping: ping, poolId: poolId, poolTitle: pool.title, status: status))
            }
        }

        items = result.sorted { ($0.ping.sentAt ?? .distantPast) > ($1.ping.sentAt ?? .distantPast) }
    }

    // MARK: Actions

    func markRead(_ item: ReminderItem) async {
        guard item.ping.isUnread, let pingId = item.ping.id, let repository else { return }

        do {
            try await repository.markPingRead(pingId: pingId, poolId: item.poolId)
        } catch {
            errorMessage = ErrorMessages.friendly(error)
        }
    }

    func markAllRead() async {
        for item in items where item.ping.isUnread {
            await markRead(item)
        }
    }
}
