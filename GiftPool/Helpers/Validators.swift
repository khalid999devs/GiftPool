import Foundation

enum Validators {
    static let minPasswordLength = 6

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidEmail(_ email: String) -> Bool {
        let value = trimmed(email)
        guard let atIndex = value.firstIndex(of: "@") else { return false }
        let domain = value[value.index(after: atIndex)...]
        return atIndex > value.startIndex && domain.contains(".") && !value.contains(" ")
    }

    static func displayNameError(_ name: String) -> String? {
        let value = trimmed(name)
        if value.isEmpty { return "Enter your name." }
        if value.count > Member.maxDisplayNameLength { return "Name must be \(Member.maxDisplayNameLength) characters or fewer." }
        return nil
    }

    static func authErrors(email: String, password: String, displayName: String?) -> [String] {
        var errors: [String] = []
        if let displayName, let error = displayNameError(displayName) {
            errors.append(error)
        }
        if !isValidEmail(email) {
            errors.append("Enter a valid email address.")
        }
        if password.count < minPasswordLength {
            errors.append("Password must be at least \(minPasswordLength) characters.")
        }
        return errors
    }

    static func poolErrors(_ draft: PoolDraft, isNew: Bool, now: Date = .now) -> [String] {
        var errors: [String] = []
        let title = trimmed(draft.title)
        let recipient = trimmed(draft.recipientName)

        if title.isEmpty {
            errors.append("Give the plan a title.")
        } else if title.count > Pool.maxTitleLength {
            errors.append("Title must be \(Pool.maxTitleLength) characters or fewer.")
        }

        if recipient.isEmpty {
            errors.append("Who is the gift for?")
        } else if recipient.count > Pool.maxRecipientLength {
            errors.append("Recipient name must be \(Pool.maxRecipientLength) characters or fewer.")
        }

        switch Money.parse(draft.budgetText) {
        case .none:
            errors.append("Enter a budget up to \(Money.format(Money.maxAmountMinor)).")
        case .some(let amount) where amount <= 0:
            errors.append("Budget must be more than zero.")
        default:
            break
        }

        if isNew && DateHelpers.isBeforeToday(draft.occasionDate, now: now) {
            errors.append("The occasion date can't be in the past.")
        }

        if trimmed(draft.note).count > Pool.maxNoteLength {
            errors.append("Note must be \(Pool.maxNoteLength) characters or fewer.")
        }
        return errors
    }

    static func ideaErrors(_ draft: IdeaDraft) -> [String] {
        var errors: [String] = []
        let title = trimmed(draft.title)
        if title.isEmpty {
            errors.append("Name the gift idea.")
        } else if title.count > GiftIdea.maxTitleLength {
            errors.append("Idea name must be \(GiftIdea.maxTitleLength) characters or fewer.")
        }
        if Money.parse(draft.priceText) == nil {
            errors.append("Enter an estimated price.")
        }
        if trimmed(draft.note).count > GiftIdea.maxNoteLength {
            errors.append("Reason must be \(GiftIdea.maxNoteLength) characters or fewer.")
        }
        let link = trimmed(draft.link)
        if !link.isEmpty && !isValidLink(link) {
            errors.append("Product links start with https://")
        }
        return errors
    }

    static func isValidLink(_ text: String) -> Bool {
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && url.host != nil
    }

    static func taskErrors(_ draft: TaskDraft) -> [String] {
        let title = trimmed(draft.title)
        if title.isEmpty { return ["Describe the task."] }
        if title.count > GiftTask.maxTitleLength { return ["Task must be \(GiftTask.maxTitleLength) characters or fewer."] }
        return []
    }

    static func sendableMessage(_ text: String) -> String? {
        let body = trimmed(text)
        guard !body.isEmpty, body.count <= ChatMessage.maxBodyLength else { return nil }
        return body
    }
}
