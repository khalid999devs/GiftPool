import Foundation

struct StarterContent: Codable, Equatable {
    let occasions: [OccasionTemplate]
    let giftCategories: [GiftCategory]
    let checklistTemplates: [ChecklistTemplate]

    static let fallback = StarterContent(
        occasions: [
            OccasionTemplate(id: "other", title: "Gift", symbol: "gift.fill", tint: "coral", checklistTemplateId: "basic")
        ],
        giftCategories: [
            GiftCategory(id: "other", title: "Other", symbol: "sparkles")
        ],
        checklistTemplates: [
            ChecklistTemplate(id: "basic", title: "Basic", taskTitles: ["Buy gift", "Wrap gift", "Deliver gift"])
        ]
    )
}

struct OccasionTemplate: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let tint: String
    let checklistTemplateId: String
}

struct GiftCategory: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}

struct ChecklistTemplate: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let taskTitles: [String]
}
