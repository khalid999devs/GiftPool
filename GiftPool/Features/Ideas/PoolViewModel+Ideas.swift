import Foundation

extension PoolViewModel {

    // MARK: Derived

    var selectedIdea: GiftIdea? {
        guard let selectedId = pool?.selectedIdeaId else { return nil }
        return ideas.first { $0.id == selectedId }
    }

    var myVoteIdeaId: String? {
        votes.first { $0.voterUid == uid }?.ideaId
    }

    var voteCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for vote in votes {
            counts[vote.ideaId, default: 0] += 1
        }
        return counts
    }

    var leadingIdeaIds: Set<String> {
        let counts = voteCounts
        guard let top = counts.values.max(), top > 0 else { return [] }
        return Set(counts.filter { $0.value == top }.map(\.key))
    }

    func voterAvatars(for ideaId: String) -> [AvatarInfo] {
        votes
            .filter { $0.ideaId == ideaId }
            .compactMap { member(withId: $0.voterUid)?.avatar }
    }

    func canEdit(_ idea: GiftIdea) -> Bool {
        isDeciding && idea.createdBy == uid
    }

    func canDelete(_ idea: GiftIdea) -> Bool {
        guard isDeciding else { return false }
        if isOwner {
            return true
        }
        return idea.createdBy == uid && idea.id != pool?.selectedIdeaId
    }

    // MARK: Actions

    func saveIdea(_ draft: IdeaDraft, editing idea: GiftIdea?) async throws {
        try requireActivePool()
        let input = try draft.validated()

        if let ideaId = idea?.id {
            try await repository.updateIdea(input, ideaId: ideaId, poolId: poolId)
        } else {
            try await repository.addIdea(input, poolId: poolId, uid: uid)
        }
    }

    func deleteIdea(_ idea: GiftIdea) async {
        guard let ideaId = idea.id else { return }

        await perform("idea-\(ideaId)") {
            try requireActivePool()
            let isSelected = pool?.selectedIdeaId == ideaId
            try await repository.deleteIdea(ideaId: ideaId, poolId: poolId, clearsSelection: isSelected)
        }
    }

    func toggleVote(for idea: GiftIdea) async {
        guard let ideaId = idea.id else { return }

        await perform("vote") {
            try requireActivePool()

            if myVoteIdeaId == ideaId {
                try await repository.removeVote(poolId: poolId, uid: uid)
            } else {
                try await repository.castVote(ideaId: ideaId, poolId: poolId, uid: uid)
            }
        }
    }

    func select(_ idea: GiftIdea?) async {
        await perform("select") {
            try requireActivePool()
            try await repository.selectIdea(idea?.id, poolId: poolId)
        }
    }
}
