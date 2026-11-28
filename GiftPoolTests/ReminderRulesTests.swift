import XCTest
@testable import GiftPool

@MainActor
final class ReminderRulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Contribution state

    func testContributionStates() {
        XCTAssertEqual(state(makeMember(assigned: 0)), .notAssigned)
        XCTAssertEqual(state(makeMember(assigned: 500)), .pending)
        XCTAssertEqual(state(makeMember(assigned: 500, collected: 200)), .partiallyCollected)
        XCTAssertEqual(state(makeMember(assigned: 500, collected: 500)), .collected)
    }

    func testSelfReportIsNeverCountedAsCollected() {
        let member = makeMember(assigned: 500, collected: 0, reportedGivenAt: now)

        XCTAssertEqual(state(member), .awaitingVerification)
        XCTAssertEqual(member.outstandingMinor, 500)
    }

    func testClosedPoolShowsArchivedUnlessFullyCollected() {
        XCTAssertEqual(ReminderRules.contributionState(for: makeMember(assigned: 500), poolIsActive: false), .archived)
        XCTAssertEqual(ReminderRules.contributionState(for: makeMember(assigned: 500, collected: 500), poolIsActive: false), .collected)
    }

    // MARK: Ping eligibility

    func testOrganizerCanPingMemberWhoOwesMoney() {
        XCTAssertEqual(eligibility(makeMember(assigned: 500)), .eligible)
    }

    func testOnlyTheOrganizerCanPing() {
        XCTAssertEqual(eligibility(makeMember(assigned: 500), isOwner: false), .notOrganizer)
    }

    func testOrganizerCannotPingThemself() {
        XCTAssertEqual(eligibility(makeMember(uid: "owner-1", assigned: 500)), .isSelf)
    }

    func testNoPingWithoutOutstandingAmount() {
        XCTAssertEqual(eligibility(makeMember(assigned: 0)), .nothingOutstanding)
        XCTAssertEqual(eligibility(makeMember(assigned: 500, collected: 500)), .nothingOutstanding)
    }

    func testNoPingWhileAwaitingVerification() {
        XCTAssertEqual(eligibility(makeMember(assigned: 500, reportedGivenAt: now)), .awaitingVerification)
    }

    func testNoPingInClosedPool() {
        XCTAssertEqual(eligibility(makeMember(assigned: 500), poolIsActive: false), .poolInactive)
    }

    func testSecondPingWithin24HoursIsBlocked() {
        let recentlyPinged = makeMember(assigned: 500, lastPingAt: now.addingTimeInterval(-3_600))
        let expectedUntil = now.addingTimeInterval(-3_600 + ReminderRules.pingCooldown)

        XCTAssertEqual(eligibility(recentlyPinged), .coolingDown(until: expectedUntil))
    }

    func testPingAllowedAgainAfterCooldown() {
        let pingedYesterday = makeMember(assigned: 500, lastPingAt: now.addingTimeInterval(-ReminderRules.pingCooldown))

        XCTAssertEqual(eligibility(pingedYesterday), .eligible)
    }

    // MARK: Reminder closure

    func testReminderOpenWhileBalanceRemains() {
        let ping = makePing(sentAt: now)

        XCTAssertEqual(ReminderRules.status(of: ping, member: makeMember(assigned: 500), poolIsActive: true), .open)
    }

    func testReminderResolvesOnFullCollection() {
        let ping = makePing(sentAt: now)
        let settled = makeMember(assigned: 500, collected: 500, settledAt: now.addingTimeInterval(60))

        XCTAssertEqual(ReminderRules.status(of: ping, member: settled, poolIsActive: true), .resolved)
    }

    func testOldReminderStaysResolvedAfterAssignmentIncrease() {
        let ping = makePing(sentAt: now)
        let increasedLater = makeMember(assigned: 800, collected: 500, settledAt: now.addingTimeInterval(60))

        XCTAssertEqual(ReminderRules.status(of: ping, member: increasedLater, poolIsActive: true), .resolved)
    }

    func testNewReminderAfterIncreaseIsOpen() {
        let laterPing = makePing(sentAt: now.addingTimeInterval(7_200))
        let increasedLater = makeMember(assigned: 800, collected: 500, settledAt: now.addingTimeInterval(60))

        XCTAssertEqual(ReminderRules.status(of: laterPing, member: increasedLater, poolIsActive: true), .open)
    }

    func testReminderClosedWhenPoolArchived() {
        let ping = makePing(sentAt: now)

        XCTAssertEqual(ReminderRules.status(of: ping, member: makeMember(assigned: 500), poolIsActive: false), .closed)
    }

    func testRemovedShareIsNotCountedAsPaid() {
        let ping = makePing(sentAt: now)

        XCTAssertEqual(ReminderRules.status(of: ping, member: makeMember(assigned: 0), poolIsActive: true), .closed)
    }

    // MARK: Helpers

    private func state(_ member: Member) -> ContributionState {
        ReminderRules.contributionState(for: member, poolIsActive: true)
    }

    private func eligibility(_ member: Member, isOwner: Bool = true, poolIsActive: Bool = true) -> PingEligibility {
        ReminderRules.pingEligibility(
            for: member,
            poolIsActive: poolIsActive,
            requesterIsOwner: isOwner,
            requesterUid: "owner-1",
            now: now
        )
    }
}
