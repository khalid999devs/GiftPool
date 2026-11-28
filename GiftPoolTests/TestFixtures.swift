import Foundation
@testable import GiftPool

@MainActor
func makeMember(
    uid: String = "member-1",
    name: String = "Rafi",
    role: MemberRole = .member,
    assigned: Int = 0,
    collected: Int = 0,
    reportedGivenAt: Date? = nil,
    lastPingAt: Date? = nil,
    pingCount: Int = 0,
    settledAt: Date? = nil
) -> Member {
    Member(
        uid: uid,
        displayName: name,
        role: role,
        assignedMinor: assigned,
        collectedMinor: collected,
        reportedGivenAt: reportedGivenAt,
        joinedAt: nil,
        lastPingAt: lastPingAt,
        pingCount: pingCount,
        settledAt: settledAt
    )
}

@MainActor
func makePing(sentAt: Date?, amount: Int = 50_000) -> Ping {
    Ping(
        id: "ping-1",
        recipientUid: "member-1",
        senderUid: "owner-1",
        sentAt: sentAt,
        readAt: nil,
        memberAmountAtSend: amount,
        kind: Ping.contributionKind
    )
}
