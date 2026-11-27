import Foundation

enum ContributionState: Equatable {
    case notAssigned
    case pending
    case partiallyCollected
    case awaitingVerification
    case collected
    case archived

    var title: String {
        switch self {
        case .notAssigned: return "Not assigned"
        case .pending: return "Pending"
        case .partiallyCollected: return "Partially collected"
        case .awaitingVerification: return "Awaiting confirmation"
        case .collected: return "Collected"
        case .archived: return "Archived"
        }
    }

    var symbol: String {
        switch self {
        case .notAssigned: return "circle.dashed"
        case .pending: return "clock.fill"
        case .partiallyCollected: return "circle.lefthalf.filled"
        case .awaitingVerification: return "hourglass"
        case .collected: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
}

enum PingEligibility: Equatable {
    case eligible
    case notOrganizer
    case isSelf
    case poolInactive
    case nothingOutstanding
    case awaitingVerification
    case coolingDown(until: Date)

    var isAllowed: Bool { self == .eligible }

    var explanation: String {
        switch self {
        case .eligible: return "Send a private reminder"
        case .notOrganizer: return "Only the organizer can send reminders"
        case .isSelf: return "You can't remind yourself"
        case .poolInactive: return "This plan is closed"
        case .nothingOutstanding: return "Nothing outstanding"
        case .awaitingVerification: return "Confirm their reported payment first"
        case .coolingDown(let until):
            return "Next reminder available \(until.formatted(.relative(presentation: .named)))"
        }
    }
}

enum ReminderStatus: Equatable {
    case open
    case resolved
    case closed

    var title: String {
        switch self {
        case .open: return "Open"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }
}
