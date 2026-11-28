import XCTest
@testable import GiftPool

@MainActor
final class TemplateAndInviteTests: XCTestCase {

    // MARK: Bundled JSON

    func testBundledTemplatesDecode() {
        let result = TemplateLoader.load()

        XCTAssertNil(result.issue)
        XCTAssertTrue(result.content.occasions.contains { $0.id == "birthday" })
        XCTAssertFalse(result.content.giftCategories.isEmpty)
        XCTAssertTrue(result.content.checklistTemplates.contains { $0.taskTitles.contains("Buy gift") })
    }

    func testEveryOccasionPointsAtARealChecklist() {
        let content = TemplateLoader.load().content
        let templateIds = Set(content.checklistTemplates.map(\.id))

        for occasion in content.occasions {
            XCTAssertTrue(templateIds.contains(occasion.checklistTemplateId), "\(occasion.id) has no checklist")
        }
    }

    func testMissingFileFallsBackWithMessage() {
        let result = TemplateLoader.load(named: "does_not_exist")

        XCTAssertNotNil(result.issue)
        XCTAssertEqual(result.content, .fallback)
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(try TemplateLoader.decode(Data("{ \"occasions\": 5 }".utf8)))
        XCTAssertThrowsError(try TemplateLoader.decode(Data("{\"occasions\":[],\"giftCategories\":[],\"checklistTemplates\":[]}".utf8)))
    }

    // MARK: Invitation codes

    func testTokensAreLongAndUnambiguous() {
        let token = InviteService.makeToken()

        XCTAssertEqual(token.count, InviteService.tokenLength)
        XCTAssertFalse(token.contains("0") || token.contains("O") || token.contains("1") || token.contains("I"))
        XCTAssertNotEqual(token, InviteService.makeToken())
    }

    func testCodesNormalizeFromPastedText() {
        let token = "ABCDEFGHJKLMNPQR"

        XCTAssertEqual(InviteService.displayCode(token), "ABCD-EFGH-JKLM-NPQR")
        XCTAssertEqual(InviteService.normalize(" abcd-efgh-jklm-npqr "), token)
        XCTAssertNil(InviteService.normalize("ABCD-EFGH"))
        XCTAssertNil(InviteService.normalize("ABCD-EFGH-JKLM-NPQ0"))
    }
}
