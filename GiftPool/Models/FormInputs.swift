import Foundation

struct PoolInput: Equatable {
    let title: String
    let recipientName: String
    let occasionKey: String
    let occasionDate: Date
    let budgetMinor: Int
    let note: String?
}

struct IdeaInput: Equatable {
    let title: String
    let estimatedMinor: Int
    let note: String?
    let categoryKey: String?
    let link: String?
    let photo: PhotoChange
}

struct TaskInput: Equatable {
    let title: String
    let assignedToUid: String?
    let dueDate: Date?
}

extension PoolDraft {
    func validated(isNew: Bool, now: Date = .now) throws -> PoolInput {
        let errors = Validators.poolErrors(self, isNew: isNew, now: now)
        guard errors.isEmpty, let budget = Money.parse(budgetText) else {
            throw AppError.validation(errors.first ?? "Check the highlighted fields.")
        }
        let trimmedNote = Validators.trimmed(note)
        return PoolInput(
            title: Validators.trimmed(title),
            recipientName: Validators.trimmed(recipientName),
            occasionKey: occasionKey,
            occasionDate: DateHelpers.occasionTimestamp(for: occasionDate),
            budgetMinor: budget,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
    }
}

extension IdeaDraft {
    func validated() throws -> IdeaInput {
        let errors = Validators.ideaErrors(self)
        guard errors.isEmpty, let price = Money.parse(priceText) else {
            throw AppError.validation(errors.first ?? "Check the idea details.")
        }
        let trimmedNote = Validators.trimmed(note)
        let trimmedLink = Validators.trimmed(link)
        return IdeaInput(
            title: Validators.trimmed(title),
            estimatedMinor: price,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            categoryKey: categoryKey,
            link: trimmedLink.isEmpty ? nil : trimmedLink,
            photo: photo
        )
    }
}

extension TaskDraft {
    func validated() throws -> TaskInput {
        if let error = Validators.taskErrors(self).first {
            throw AppError.validation(error)
        }
        return TaskInput(
            title: Validators.trimmed(title),
            assignedToUid: assignedToUid,
            dueDate: hasDueDate ? DateHelpers.occasionTimestamp(for: dueDate) : nil
        )
    }
}
