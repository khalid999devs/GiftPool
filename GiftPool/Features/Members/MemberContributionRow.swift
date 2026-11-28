import SwiftUI

struct MemberContributionRow: View {
    let member: Member
    @ObservedObject var viewModel: PoolViewModel
    let onRecord: () -> Void
    let onPing: () -> Void

    private var isMe: Bool {
        member.uid == viewModel.uid
    }

    private var canRecord: Bool {
        viewModel.isOwner && viewModel.isActive && member.assignedMinor > 0
    }

    private var roleText: String? {
        if isMe {
            return "You"
        }
        return member.isOwner ? "Organizer" : nil
    }

    var body: some View {
        let state = viewModel.contributionState(for: member)
        let eligibility = viewModel.pingEligibility(for: member)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AvatarView(avatar: member.avatar, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    Text(member.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        StatusPill(state: state)
                        if let roleText {
                            Text(roleText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.format(member.collectedMinor))
                        .font(.headline.monospacedDigit())
                        .contentTransition(.numericText())
                    Text("of \(Money.format(member.assignedMinor))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
                .accessibilityElement(children: .combine)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // The organizer can tap anyone to correct what was received.
                if canRecord {
                    onRecord()
                }
            }

            if member.assignedMinor > 0 {
                ProgressBar(
                    progress: MoneyCalculator.progress(collected: member.collectedMinor, target: member.assignedMinor),
                    tint: Theme.tint(for: state),
                    height: 6
                )
            }

            if viewModel.isOwner && viewModel.isActive && state == .awaitingVerification {
                InfoNote(
                    text: "\(member.displayName) says they've given. Confirm once it's in your hands.",
                    symbol: "hourglass",
                    tint: Theme.plum
                )
            }

            if canRecord && member.outstandingMinor > 0 {
                HStack(spacing: 8) {
                    Button(action: onRecord) {
                        Label(state == .awaitingVerification ? "Confirm" : "Record", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.mint))

                    if !isMe {
                        Button(action: onPing) {
                            if viewModel.isBusy("ping-\(member.uid)") {
                                ProgressView()
                            } else {
                                Label("Remind", systemImage: "bell")
                            }
                        }
                        .buttonStyle(SoftButtonStyle(tint: Theme.sun))
                        .disabled(!eligibility.isAllowed || viewModel.isBusy("ping-\(member.uid)"))
                        .accessibilityHint(eligibility.explanation)
                    }

                    Spacer()
                }
            }

            if viewModel.isOwner && viewModel.isActive && !isMe, let caption = pingCaption(eligibility) {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func pingCaption(_ eligibility: PingEligibility) -> String? {
        var parts: [String] = []

        if member.pingCount > 0, let last = member.lastPingAt {
            let times = member.pingCount == 1 ? "once" : "\(member.pingCount) times"
            let when = Date.now.timeIntervalSince(last) < 60 ? "just now" : "last \(last.formatted(.relative(presentation: .named)))"
            parts.append("Reminded \(times) · \(when)")
        }

        switch eligibility {
        case .eligible, .nothingOutstanding, .notOrganizer, .isSelf:
            break
        default:
            parts.append(eligibility.explanation)
        }

        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }
}
