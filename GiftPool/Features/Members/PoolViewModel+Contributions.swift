import Foundation

extension PoolViewModel {

    // MARK: Derived

    func contributionState(for member: Member) -> ContributionState {
        ReminderRules.contributionState(for: member, poolIsActive: isActive)
    }

    func pingEligibility(for member: Member, now: Date = .now) -> PingEligibility {
        ReminderRules.pingEligibility(
            for: member,
            poolIsActive: isActive,
            requesterIsOwner: isOwner,
            requesterUid: uid,
            now: now
        )
    }

    func canReportGiven(_ member: Member) -> Bool {
        isActive
            && !isOwner
            && member.uid == uid
            && member.outstandingMinor > 0
            && !member.hasReportedGiving
    }

    // MARK: Organizer actions

    func saveAssignments(_ amounts: [String: Int]) async throws {
        try requireActivePool()

        guard isOwner else {
            throw AppError.validation("Only the organizer can assign amounts.")
        }
        if let problem = MoneyCalculator.assignmentProblem(amounts, members: members) {
            throw AppError.validation(problem)
        }

        try await repository.updateAssignments(amounts, members: members, poolId: poolId)
    }

    func recordCollection(_ amount: Int, for member: Member) async throws {
        try requireActivePool()

        guard amount >= 0, amount <= member.assignedMinor else {
            throw AppError.validation("Enter an amount between \(Money.format(0)) and \(Money.format(member.assignedMinor)).")
        }

        try await repository.recordCollection(amount, for: member, poolId: poolId)
    }

    func rejectReport(for member: Member) async throws {
        try requireActivePool()
        try await repository.clearReport(for: member, poolId: poolId)
    }

    func ping(_ member: Member) async -> Bool {
        let eligibility = pingEligibility(for: member)
        guard eligibility.isAllowed else {
            errorMessage = eligibility.explanation
            return false
        }

        return await perform("ping-\(member.uid)") {
            try await repository.sendPing(to: member, poolId: poolId, senderUid: uid)
        }
    }

    // MARK: Organizer shortcuts

    // Everyone the organizer can remind right now: they owe money and weren't reminded today.
    var membersToRemind: [Member] {
        members.filter { pingEligibility(for: $0).isAllowed }
    }

    func remindAll() async {
        let targets = membersToRemind
        var sent = 0

        await perform("remind-all") {
            for member in targets {
                if (try? await repository.sendPing(to: member, poolId: poolId, senderUid: uid)) != nil {
                    sent += 1
                }
            }
        }

        if sent < targets.count {
            errorMessage = "Sent \(sent) of \(targets.count) reminders. Try the others again in a moment."
        }
    }

    // The budget shared evenly by every member. Nil when someone has already given more than that.
    var equalShares: [String: Int]? {
        guard let pool, isOwner, !members.isEmpty else { return nil }

        let people = sortedMembers
        let amounts = MoneyCalculator.equalSplit(total: pool.budgetMinor, count: people.count)
        let shares = Dictionary(uniqueKeysWithValues: zip(people.map(\.uid), amounts))

        return MoneyCalculator.assignmentProblem(shares, members: members) == nil ? shares : nil
    }

    func splitEqually() async {
        guard let shares = equalShares else { return }

        await perform("split") {
            try await saveAssignments(shares)
        }
    }

    // MARK: Member actions

    func reportGiven() async {
        guard let me, canReportGiven(me) else { return }

        await perform("report") {
            try await repository.reportGiven(poolId: poolId, uid: uid)
        }
    }
}
