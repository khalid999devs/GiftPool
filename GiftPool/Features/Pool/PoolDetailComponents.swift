import SwiftUI

struct PoolHeroCard: View {
    let pool: Pool
    let occasion: OccasionTemplate
    let summary: BudgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusPill(status: pool.status, onColor: true)
                Spacer()
                StatusPill(text: occasion.title, symbol: occasion.symbol, onColor: true)
            }

            Spacer(minLength: 20)

            Text(pool.title)
                .font(.title2.weight(.bold))
            Text("For \(pool.recipientName)")
                .font(.headline)
                .opacity(0.92)

            Label(
                "\(DateHelpers.occasionText(pool.occasionDate, style: .dateTime.weekday(.wide).day().month(.wide))) · \(DateHelpers.countdownText(pool.occasionDate))",
                systemImage: "calendar"
            )
            .font(.subheadline.weight(.medium))
            .opacity(0.92)

            if let note = pool.note {
                Text(note)
                    .font(.footnote)
                    .opacity(0.85)
                    .lineLimit(2)
            }

            // How much of the budget has come in.
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                        Capsule()
                            .fill(.white)
                            .frame(width: proxy.size.width * min(summary.progress, 1))
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(Money.format(summary.collected)) of \(Money.format(summary.target)) collected")
                    Spacer()
                    Text(summary.progress, format: .percent.precision(.fractionLength(0)))
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .bottomLeading)
        .background(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                Theme.gradient(named: occasion.tint)
                Image(systemName: occasion.symbol)
                    .font(.system(size: 130, weight: .bold))
                    .foregroundStyle(.white.opacity(0.13))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 30, y: 10)
                    .accessibilityHidden(true)

                // A soft shade behind the text keeps white readable on the lighter colors (sun, mint).
                LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.tint(named: occasion.tint).opacity(0.3), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }
}

struct NextStepCard: View {
    let step: NextStep
    var isBusy = false
    var onAction: ((NextStepAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let section = step.section {
                NavigationLink(value: section) {
                    header
                }
                .buttonStyle(.plain)
            } else {
                header
            }

            if let action = step.action, let onAction {
                Button {
                    onAction(action)
                } label: {
                    if isBusy {
                        ProgressView()
                    } else {
                        Label(action.buttonTitle, systemImage: action.symbol)
                    }
                }
                .buttonStyle(SoftButtonStyle(fullWidth: true))
                .disabled(isBusy)
            }
        }
        .card()
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: step.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 46, height: 46)
                .background(Theme.coral.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT STEP")
                    .font(.caption2.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(Theme.coralText)
                Text(step.title)
                    .font(.headline)
                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            if step.section != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct BudgetCard: View {
    let summary: BudgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 22) {
                ZStack {
                    ProgressRing(progress: summary.progress)
                        .frame(width: 100, height: 100)

                    VStack(spacing: 0) {
                        Text(summary.progress, format: .percent.precision(.fractionLength(0)))
                            .font(.title3.weight(.bold))
                            .contentTransition(.numericText())
                        Text("collected")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 11) {
                    amountRow("Target", summary.target)
                    amountRow("Assigned", summary.assigned)
                    amountRow("Collected", summary.collected, tint: Theme.successText)
                    amountRow("Remaining", summary.remaining)
                }
            }

            AllocationNote(summary: summary)
        }
        .card(padding: 20)
    }

    private func amountRow(_ title: String, _ amount: Int, tint: Color = .primary) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(Money.format(amount))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

struct AllocationNote: View {
    let summary: BudgetSummary

    var body: some View {
        if summary.assigned == 0 {
            InfoNote(text: "No shares assigned yet.")
        } else if summary.allocationDifference < 0 {
            InfoNote(
                text: "\(Money.format(-summary.allocationDifference)) of the target isn't assigned to anyone yet.",
                symbol: "exclamationmark.circle.fill",
                tint: Theme.sun
            )
        } else if summary.allocationDifference > 0 {
            InfoNote(
                text: "Shares add up to \(Money.format(summary.allocationDifference)) more than the target.",
                symbol: "exclamationmark.triangle.fill",
                tint: Theme.danger
            )
        }
    }
}

// One row in the plan's section list: icon, title, a short status and a chevron.
struct SectionRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: String
    var badge = 0

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(symbol: symbol, gradient: Theme.gradient(named: tint), size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            if badge > 0 {
                Text("\(badge)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Theme.sunText, in: Capsule())
                    .accessibilityLabel("\(badge) open reminders")
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct MyShareCard: View {
    @ObservedObject var viewModel: PoolViewModel
    let member: Member

    @EnvironmentObject private var reminders: RemindersViewModel
    @State private var isConfirming = false

    var body: some View {
        let state = viewModel.contributionState(for: member)
        let openReminders = reminders.openCount(poolId: viewModel.poolId)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your share")
                    .font(.headline)
                Spacer()
                StatusPill(state: state)
            }

            if member.outstandingMinor > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Money.format(member.outstandingMinor))
                        .font(.title.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text("still to give")
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("All given. Thank you!", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.successText)
            }

            ProgressBar(
                progress: MoneyCalculator.progress(collected: member.collectedMinor, target: member.assignedMinor),
                tint: Theme.tint(for: state)
            )

            Text("\(Money.format(member.collectedMinor)) of \(Money.format(member.assignedMinor)) confirmed")
                .font(.caption)
                .foregroundStyle(.secondary)

            if openReminders > 0 {
                Label(
                    "\(openReminders) open reminder\(openReminders == 1 ? "" : "s") from the organizer",
                    systemImage: "bell.badge.fill"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.sunText)
            }

            if state == .awaitingVerification {
                InfoNote(
                    text: "Waiting for the organizer to confirm they got it.",
                    symbol: "hourglass",
                    tint: Theme.plum
                )
            } else if viewModel.canReportGiven(member) {
                Button {
                    isConfirming = true
                } label: {
                    if viewModel.isBusy("report") {
                        ProgressView()
                    } else {
                        Label("I Have Given", systemImage: "hand.thumbsup.fill")
                    }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.success, fullWidth: true))
                .disabled(viewModel.isBusy("report"))
            }
        }
        .card(padding: 20)
        .alert("Let the organizer know?", isPresented: $isConfirming) {
            Button("Cancel", role: .cancel) {}
            Button("I Have Given") {
                Task { await viewModel.reportGiven() }
            }
        } message: {
            Text("It counts once the organizer confirms they got it.")
        }
    }
}
