import Foundation

struct BudgetSummary: Equatable {
    let target: Int
    let assigned: Int
    let collected: Int
    let remaining: Int
    let unassigned: Int
    let progress: Double

    var allocationDifference: Int { assigned - target }
    var isBalanced: Bool { allocationDifference == 0 }
}

enum MoneyCalculator {
    static func totals(target: Int, members: [Member]) -> (assigned: Int, collected: Int, remaining: Int) {
        let assigned = members.reduce(0) { $0 + $1.assignedMinor }
        let collected = members.reduce(0) { $0 + $1.collectedMinor }
        return (assigned, collected, max(target - collected, 0))
    }

    static func summarize(target: Int, members: [Member]) -> BudgetSummary {
        let totals = totals(target: target, members: members)
        return BudgetSummary(
            target: target,
            assigned: totals.assigned,
            collected: totals.collected,
            remaining: totals.remaining,
            unassigned: max(target - totals.assigned, 0),
            progress: progress(collected: totals.collected, target: target)
        )
    }

    static func progress(collected: Int, target: Int) -> Double {
        target > 0 ? min(Double(collected) / Double(target), 1) : 0
    }

    // Leftover paisa go to the first members so the shares add up exactly.
    static func equalSplit(total: Int, count: Int) -> [Int] {
        guard count > 0, total >= 0 else { return [] }
        let base = total / count
        let remainder = total % count
        var shares: [Int] = []
        for index in 0..<count {
            shares.append(base + (index < remainder ? 1 : 0))
        }
        return shares
    }

    static func assignmentProblem(_ assignments: [String: Int], members: [Member]) -> String? {
        for member in members {
            let newAmount = assignments[member.uid] ?? member.assignedMinor
            if newAmount < 0 || newAmount > Money.maxAmountMinor {
                return "\(member.displayName)'s amount is out of range."
            }
            if newAmount < member.collectedMinor {
                return "\(member.displayName) has already given \(Money.format(member.collectedMinor)). Their share can't be lower than that."
            }
        }
        return nil
    }
}
