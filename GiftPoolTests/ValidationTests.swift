import XCTest
import UIKit
@testable import GiftPool

@MainActor
final class ValidationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func validDraft() -> PoolDraft {
        var draft = PoolDraft()
        draft.title = "Rafi's Birthday Gift"
        draft.recipientName = "Rafi"
        draft.budgetText = "5000"
        draft.occasionDate = now.addingTimeInterval(7 * 86_400)
        return draft
    }

    func testValidPoolPasses() {
        XCTAssertTrue(Validators.poolErrors(validDraft(), isNew: true, now: now).isEmpty)
    }

    func testPoolRequiresTitleRecipientAndBudget() {
        var draft = validDraft()
        draft.title = "   "
        draft.recipientName = ""
        draft.budgetText = "0"

        XCTAssertEqual(Validators.poolErrors(draft, isNew: true, now: now).count, 3)
    }

    func testNewPoolCannotBeInThePast() {
        var draft = validDraft()
        draft.occasionDate = now.addingTimeInterval(-3 * 86_400)

        XCTAssertFalse(Validators.poolErrors(draft, isNew: true, now: now).isEmpty)
        XCTAssertTrue(Validators.poolErrors(draft, isNew: false, now: now).isEmpty)
    }

    func testOverlongTitleIsRejected() {
        var draft = validDraft()
        draft.title = String(repeating: "a", count: Pool.maxTitleLength + 1)

        XCTAssertFalse(Validators.poolErrors(draft, isNew: true, now: now).isEmpty)
    }

    func testValidatedInputIsTrimmedAndInMinorUnits() throws {
        var draft = validDraft()
        draft.title = "  Rafi's Gift  "
        draft.budgetText = "1,500.25"

        let input = try draft.validated(isNew: true, now: now)

        XCTAssertEqual(input.title, "Rafi's Gift")
        XCTAssertEqual(input.budgetMinor, 150_025)
        XCTAssertNil(input.note)
    }

    func testChatMessageRules() {
        XCTAssertNil(Validators.sendableMessage("   \n "))
        XCTAssertEqual(Validators.sendableMessage("  hi all  "), "hi all")
        XCTAssertNil(Validators.sendableMessage(String(repeating: "x", count: ChatMessage.maxBodyLength + 1)))
        XCTAssertNotNil(Validators.sendableMessage(String(repeating: "x", count: ChatMessage.maxBodyLength)))
    }

    func testAuthValidation() {
        XCTAssertTrue(Validators.authErrors(email: "a@b.co", password: "secret1", displayName: nil).isEmpty)
        XCTAssertEqual(Validators.authErrors(email: "not-an-email", password: "123", displayName: "").count, 3)
    }

    func testIdeaNeedsNameAndPrice() {
        var draft = IdeaDraft()
        XCTAssertEqual(Validators.ideaErrors(draft).count, 2)

        draft.title = "Instant camera"
        draft.priceText = "8500"
        XCTAssertTrue(Validators.ideaErrors(draft).isEmpty)
    }

    func testOccasionDateKeepsTheCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Dhaka") ?? .gmt
        let localMidnight = calendar.date(from: DateComponents(year: 2026, month: 12, day: 14)) ?? now

        let stored = DateHelpers.occasionTimestamp(for: localMidnight, calendar: calendar)
        let restored = DateHelpers.localDate(fromOccasion: stored, calendar: calendar)

        XCTAssertEqual(calendar.component(.day, from: restored), 14)
        XCTAssertEqual(calendar.component(.month, from: restored), 12)
    }

    func testProductLinkMustBeAWebAddress() {
        XCTAssertTrue(Validators.isValidLink("https://www.daraz.com.bd/products/instax"))
        XCTAssertFalse(Validators.isValidLink("daraz.com.bd"))
        XCTAssertFalse(Validators.isValidLink("ftp://files.example.com"))
    }

    func testPhotoIsShrunkUnderTheLimit() throws {
        // A large photo is resized and compressed well under the 300 KB the rules allow.
        let size = CGSize(width: 3000, height: 2000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let jpeg = try XCTUnwrap(PhotoCompressor.jpeg(from: try XCTUnwrap(image.pngData())))
        XCTAssertLessThanOrEqual(jpeg.count, PhotoCompressor.maxBytes)

        let shrunk = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertLessThanOrEqual(max(shrunk.size.width, shrunk.size.height), 900)
    }
}
