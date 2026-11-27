import Foundation
import Combine

enum TemplateLoaderError: LocalizedError {
    case missingFile(String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .missingFile(let name): return "\(name).json is missing from the app bundle."
        case .emptyContent: return "The starter template file has no occasions or tasks."
        }
    }
}

enum TemplateLoader {
    static let defaultFileName = "starter_templates"

    static func decode(_ data: Data) throws -> StarterContent {
        let content = try JSONDecoder().decode(StarterContent.self, from: data)
        guard !content.occasions.isEmpty, !content.checklistTemplates.isEmpty else {
            throw TemplateLoaderError.emptyContent
        }
        return content
    }

    static func load(named fileName: String = defaultFileName, bundle: Bundle = .main) -> (content: StarterContent, issue: String?) {
        do {
            guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
                throw TemplateLoaderError.missingFile(fileName)
            }
            let data = try Data(contentsOf: url)
            return (try decode(data), nil)
        } catch {
            return (.fallback, "Starter templates couldn't be loaded, so basic options are shown instead.")
        }
    }
}

final class TemplateLibrary: ObservableObject {
    let content: StarterContent
    let loadIssue: String?

    lazy var occasionIndex: [String: OccasionTemplate] = Dictionary(
        content.occasions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    lazy var checklistIndex: [String: ChecklistTemplate] = Dictionary(
        content.checklistTemplates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    lazy var categoryIndex: [String: GiftCategory] = Dictionary(
        content.giftCategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    init(fileName: String = TemplateLoader.defaultFileName, bundle: Bundle = .main) {
        let result = TemplateLoader.load(named: fileName, bundle: bundle)
        content = result.content
        loadIssue = result.issue
    }

    func occasion(for key: String) -> OccasionTemplate {
        occasionIndex[key] ?? OccasionTemplate(id: key, title: "Gift", symbol: "gift.fill", tint: "coral", checklistTemplateId: "")
    }

    func taskTitles(forOccasion key: String) -> [String] {
        let templateId = occasion(for: key).checklistTemplateId
        return checklistIndex[templateId]?.taskTitles ?? content.checklistTemplates.first?.taskTitles ?? []
    }

    func category(for key: String?) -> GiftCategory? {
        guard let key else { return nil }
        return categoryIndex[key]
    }
}
