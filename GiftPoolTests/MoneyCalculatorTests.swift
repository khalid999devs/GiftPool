import XCTest
@testable import GiftPool

@MainActor
final class MoneyCalculatorTests: XCTestCase {

    func testTotalsSeparateAssignedFromCollected() {
        let members = [
            makeMember(uid: "a", assigned: 40_000, collected: 40_000),
            makeMember(uid: "b", assigned: 30_000, collected: 10_000),
            makeMember(uid: "c", assigned: 30_000, collected: 0)
        ]

        let totals = MoneyCalculator.totals(target: 100_000, members: members)

        XCTAssertEqual(totals.assigned, 100_000)
        XCTAssertEqual(totals.collected, 50_000)
        XCTAssertEqual(totals.remaining, 50_000)
    }

    func testSummaryReportsGapAndProgress() {
        let members = [makeMember(assigned: 60_000, collected: 30_000)]

        let summary = MoneyCalculator.summarize(target: 100_000, members: members)

        XCTAssertEqual(summary.unassigned, 40_000)
        XCTAssertEqual(summary.allocationDifference, -40_000)
        XCTAssertFalse(summary.isBalanced)
        XCTAssertEqual(summary.progress, 0.3, accuracy: 0.0001)
    }

    func testOverAllocationIsNotHidden() {
        let members = [makeMember(assigned: 120_000)]

        let summary = MoneyCalculator.summarize(target: 100_000, members: members)

        XCTAssertEqual(summary.allocationDifference, 20_000)
        XCTAssertEqual(summary.unassigned, 0)
    }

    func testProgressIsClampedAndSafeForZeroTarget() {
        XCTAssertEqual(MoneyCalculator.progress(collected: 500, target: 0), 0)
        XCTAssertEqual(MoneyCalculator.progress(collected: 200, target: 100), 1)
    }

    func testEqualSplitSumsExactlyToTarget() {
        let shares = MoneyCalculator.equalSplit(total: 100_000, count: 3)

        XCTAssertEqual(shares, [33_334, 33_333, 33_333])
        XCTAssertEqual(shares.reduce(0, +), 100_000)
    }

    func testEqualSplitHandlesEdgeCases() {
        XCTAssertEqual(MoneyCalculator.equalSplit(total: 5, count: 7), [1, 1, 1, 1, 1, 0, 0])
        XCTAssertEqual(MoneyCalculator.equalSplit(total: 900, count: 1), [900])
        XCTAssertTrue(MoneyCalculator.equalSplit(total: 900, count: 0).isEmpty)
    }

    func testAssignmentCannotDropBelowCollectedMoney() {
        let members = [makeMember(uid: "a", name: "Nadia", assigned: 50_000, collected: 30_000)]

        let problem = MoneyCalculator.assignmentProblem(["a": 20_000], members: members)

        XCTAssertNotNil(problem)
        XCTAssertNil(MoneyCalculator.assignmentProblem(["a": 30_000], members: members))
    }

    func testMoneyParsingUsesWholePaisa() {
        XCTAssertEqual(Money.parse("1,250.5", decimalSeparator: "."), 125_050)
        XCTAssertEqual(Money.parse("৳ 99", decimalSeparator: "."), 9_900)
        XCTAssertEqual(Money.parse(".75", decimalSeparator: "."), 75)
        XCTAssertEqual(Money.parse("12,5", decimalSeparator: ","), 1_250)
    }

    func testMoneyParsingRejectsInvalidInput() {
        XCTAssertNil(Money.parse("", decimalSeparator: "."))
        XCTAssertNil(Money.parse("-5", decimalSeparator: "."))
        XCTAssertNil(Money.parse("1.234", decimalSeparator: "."))
        XCTAssertNil(Money.parse("abc", decimalSeparator: "."))
        XCTAssertNil(Money.parse("1.2.3", decimalSeparator: "."))
        XCTAssertNil(Money.parse("2000000", decimalSeparator: "."))
    }

    func testMoneyFormatting() {
        XCTAssertEqual(Money.format(125_000), "৳1,250")
        XCTAssertEqual(Money.format(125_050), "৳1,250.50")
        XCTAssertEqual(Money.format(5), "৳0.05")
        XCTAssertEqual(Money.editingText(125_050, decimalSeparator: "."), "1250.50")
        XCTAssertEqual(Money.editingText(0, decimalSeparator: "."), "")
    }
}
