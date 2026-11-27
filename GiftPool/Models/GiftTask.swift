import Foundation
import FirebaseFirestore

struct GiftTask: Identifiable, Codable, Equatable {
    static let maxTitleLength = 80

    @DocumentID var id: String?
    var title: String
    var assignedToUid: String?
    var dueDate: Date?
    var isDone: Bool
    var sortOrder: Int
    var createdAt: Date?
    var completedAt: Date?

    func isOverdue(now: Date = .now) -> Bool {
        guard let dueDate, !isDone else { return false }
        return DateHelpers.daysUntil(dueDate, now: now) < 0
    }
}

struct TaskDraft: Equatable {
    var title = ""
    var assignedToUid: String?
    var hasDueDate = false
    var dueDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now

    init() {}

    init(task: GiftTask) {
        title = task.title
        assignedToUid = task.assignedToUid
        if let due = task.dueDate {
            hasDueDate = true
            dueDate = DateHelpers.localDate(fromOccasion: due)
        }
    }
}
