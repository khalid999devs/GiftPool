import Foundation

struct NextStep: Equatable {
    let title: String
    let detail: String
    let symbol: String
    let section: PoolSection?
    var action: NextStepAction?
}

// A one-tap shortcut for the organizer, so the common jobs don't need a trip into a section.
enum NextStepAction: Equatable {
    case pick(ideaId: String, title: String)
    case splitEqually(share: Int)
    case remindAll(count: Int)
    case markStatus(PoolStatus)

    var buttonTitle: String {
        switch self {
        case .pick: return "Pick This Gift"
        case .splitEqually(let share): return "Split Equally · \(Money.format(share)) each"
        case .remindAll(let count): return "Remind \(count) \(count == 1 ? "Person" : "People")"
        case .markStatus(let status): return status == .purchased ? "Mark as Purchased" : "Mark as Delivered"
        }
    }

    var question: String {
        switch self {
        case .pick(_, let title): return "Pick \(title)?"
        case .splitEqually: return "Split the budget equally?"
        case .remindAll(let count): return "Remind \(count) \(count == 1 ? "person" : "people")?"
        case .markStatus: return ""
        }
    }

    var message: String {
        switch self {
        case .pick: return "Everyone will see it as the group's gift."
        case .splitEqually(let share): return "Everyone gives \(Money.format(share)). You can adjust amounts later."
        case .remindAll: return "Each gets a private nudge about what they still owe."
        case .markStatus: return ""
        }
    }

    var confirmTitle: String {
        switch self {
        case .pick: return "Pick"
        case .splitEqually: return "Split"
        case .remindAll: return "Remind"
        case .markStatus: return ""
        }
    }

    var symbol: String {
        switch self {
        case .pick: return "crown.fill"
        case .splitEqually: return "equal.circle.fill"
        case .remindAll: return "bell.fill"
        case .markStatus(let status): return status.symbol
        }
    }
}

extension PoolViewModel {
    var nextStep: NextStep {
        guard let pool else {
            return NextStep(title: "Loading", detail: "", symbol: "hourglass", section: nil)
        }

        switch pool.status {
        case .completed:
            return NextStep(
                title: "Gift delivered",
                detail: "Thanks for making it happen together.",
                symbol: "checkmark.seal.fill",
                section: nil
            )
        case .cancelled:
            return NextStep(
                title: "Plan cancelled",
                detail: "Everything stays readable.",
                symbol: "xmark.circle.fill",
                section: nil
            )
        case .planning, .purchased:
            break
        }

        if ideas.isEmpty {
            return NextStep(
                title: "Suggest gift ideas",
                detail: "Add the first idea for \(pool.recipientName).",
                symbol: "lightbulb.fill",
                section: .ideas
            )
        }

        if pool.selectedIdeaId == nil {
            // One idea is ahead, so the organizer can pick it right here.
            if isOwner, leadingIdeaIds.count == 1, let leader = ideas.first(where: { leadingIdeaIds.contains($0.id ?? "") }), let leaderId = leader.id {
                let count = voteCounts[leaderId] ?? 0
                return NextStep(
                    title: "\(leader.title) is leading",
                    detail: "\(count) of \(members.count) votes so far.",
                    symbol: "hand.thumbsup.fill",
                    section: .ideas,
                    action: .pick(ideaId: leaderId, title: leader.title)
                )
            }
            if isOwner {
                return NextStep(
                    title: "Pick the gift",
                    detail: "\(votes.count) vote\(votes.count == 1 ? "" : "s") so far. Choose the winner when ready.",
                    symbol: "hand.thumbsup.fill",
                    section: .ideas
                )
            }
            return NextStep(
                title: "Vote for a gift",
                detail: "Help the group decide. You can change your vote.",
                symbol: "hand.thumbsup.fill",
                section: .ideas
            )
        }

        if summary.assigned == 0 {
            if isOwner {
                return NextStep(
                    title: "Assign contributions",
                    detail: "Split the \(Money.format(pool.budgetMinor)) budget across the group.",
                    symbol: "chart.pie.fill",
                    section: .contributions,
                    action: splitAction
                )
            }
            return NextStep(
                title: "Waiting on amounts",
                detail: "The organizer will assign everyone's share.",
                symbol: "chart.pie.fill",
                section: .contributions
            )
        }

        // Someone joined after the amounts were split.
        let withoutShare = members.filter { !$0.isOwner && $0.assignedMinor == 0 }.count
        if isOwner && withoutShare > 0 {
            return NextStep(
                title: "Give everyone a share",
                detail: "\(withoutShare) member\(withoutShare == 1 ? " doesn't" : "s don't") have an amount yet.",
                symbol: "person.badge.plus",
                section: .contributions,
                action: splitAction
            )
        }

        // A member who joined after the split has no amount yet.
        if let me, !isOwner, me.assignedMinor == 0 {
            return NextStep(
                title: "Waiting for your share",
                detail: "The organizer will give you an amount.",
                symbol: "chart.pie.fill",
                section: .contributions
            )
        }

        if let me, !isOwner, me.outstandingMinor > 0, !me.hasReportedGiving {
            return NextStep(
                title: "Your share: \(Money.format(me.outstandingMinor))",
                detail: "Give it to the organizer, then tap I Have Given.",
                symbol: "person.crop.circle.badge.clock",
                section: .contributions
            )
        }

        // People who say they've paid come first: the organizer only has to confirm.
        let reported = members.filter { $0.hasReportedGiving && $0.outstandingMinor > 0 }.count
        if isOwner && reported > 0 {
            return NextStep(
                title: "\(reported) \(reported == 1 ? "person says they've" : "people say they've") given",
                detail: "Confirm once the money is in your hands.",
                symbol: "hourglass",
                section: .contributions
            )
        }

        let owing = members.filter { $0.outstandingMinor > 0 }.count
        if isOwner && owing > 0 {
            let canRemind = membersToRemind.count
            return NextStep(
                title: "\(owing) contribution\(owing == 1 ? "" : "s") outstanding",
                detail: "Record money as it comes in.",
                symbol: "tray.and.arrow.down.fill",
                section: .contributions,
                action: canRemind > 0 ? .remindAll(count: canRemind) : nil
            )
        }

        if !isOwner && owing > 0 {
            return NextStep(
                title: "Waiting on the group",
                detail: "\(owing) of \(members.count) still to give.",
                symbol: "person.3.fill",
                section: .contributions
            )
        }

        // Everyone paid, but the shares don't cover the whole budget yet.
        if isOwner && summary.allocationDifference < 0 {
            return NextStep(
                title: "\(Money.format(-summary.allocationDifference)) isn't assigned yet",
                detail: "Add it to someone's share, or lower the budget.",
                symbol: "exclamationmark.circle.fill",
                section: .contributions
            )
        }

        if pool.status == .planning {
            if isOwner {
                return NextStep(
                    title: "Buy the gift",
                    detail: "Everything is collected.",
                    symbol: "bag.fill",
                    section: .checklist,
                    action: .markStatus(.purchased)
                )
            }

            let remainingTasks = tasks.filter { !$0.isDone }.count
            return NextStep(
                title: "Gift shopping time",
                detail: "\(remainingTasks) task\(remainingTasks == 1 ? "" : "s") left on the checklist.",
                symbol: "bag.fill",
                section: .checklist
            )
        }

        return NextStep(
            title: "Deliver the gift",
            detail: isOwner ? "Mark it delivered once \(pool.recipientName) has it." : "Almost there!",
            symbol: "shippingbox.fill",
            section: .checklist,
            action: isOwner ? .markStatus(.completed) : nil
        )
    }

    func run(_ action: NextStepAction) async {
        switch action {
        case .pick(let ideaId, _):
            if let idea = ideas.first(where: { $0.id == ideaId }) {
                await select(idea)
            }
        case .splitEqually:
            await splitEqually()
        case .remindAll:
            await remindAll()
        case .markStatus(let status):
            await changeStatus(to: status)
        }
    }

    var isRunningShortcut: Bool {
        isBusy("select") || isBusy("split") || isBusy("remind-all")
    }

    private var splitAction: NextStepAction? {
        guard let shares = equalShares, let share = shares.values.min() else { return nil }
        return .splitEqually(share: share)
    }
}
