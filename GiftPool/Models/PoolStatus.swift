import Foundation

enum PoolStatus: String, Codable, CaseIterable {
    case planning
    case purchased
    case completed
    case cancelled

    var isActive: Bool {
        self == .planning || self == .purchased
    }

    var title: String {
        switch self {
        case .planning: return "Planning"
        case .purchased: return "Purchased"
        case .completed: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }

    var symbol: String {
        switch self {
        case .planning: return "lightbulb.fill"
        case .purchased: return "bag.fill"
        case .completed: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var allowedNextStatuses: [PoolStatus] {
        switch self {
        case .planning: return [.purchased, .cancelled]
        case .purchased: return [.completed, .cancelled]
        case .completed, .cancelled: return []
        }
    }
}
