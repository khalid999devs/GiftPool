import Foundation

enum ReminderRules {
    static let pingCooldown: TimeInterval = 24 * 60 * 60

    static func contributionState(for member: Member, poolIsActive: Bool) -> ContributionState {
        if member.assignedMinor == 0 {
            return poolIsActive ? .notAssigned : .archived
        }
        if member.outstandingMinor == 0 {
            return .collected
        }
        if !poolIsActive {
            return .archived
        }
        if member.hasReportedGiving {
            return .awaitingVerification
        }
        return member.collectedMinor > 0 ? .partiallyCollected : .pending
    }

    static func pingEligibility(
        for member: Member,
        poolIsActive: Bool,
        requesterIsOwner: Bool,
        requesterUid: String,
        now: Date = .now
    ) -> PingEligibility {
        guard requesterIsOwner else { return .notOrganizer }
        guard member.uid != requesterUid else { return .isSelf }
        guard poolIsActive else { return .poolInactive }
        guard member.outstandingMinor > 0 else { return .nothingOutstanding }
        guard !member.hasReportedGiving else { return .awaitingVerification }

        if let lastPingAt = member.lastPingAt {
            let nextAllowed = lastPingAt.addingTimeInterval(pingCooldown)
            if nextAllowed > now {
                return .coolingDown(until: nextAllowed)
            }
        }
        return .eligible
    }

    // A ping sent before the member settled stays resolved, even if the amount is raised later.
    static func status(of ping: Ping, member: Member?, poolIsActive: Bool) -> ReminderStatus {
        guard let member else { return .closed }
        // A share set to nothing isn't "paid"; the reminder just no longer applies.
        if member.assignedMinor == 0 && member.collectedMinor == 0 {
            return .closed
        }
        if member.outstandingMinor == 0 {
            return .resolved
        }
        if let settledAt = member.settledAt, let sentAt = ping.sentAt, settledAt >= sentAt {
            return .resolved
        }
        return poolIsActive ? .open : .closed
    }
}
