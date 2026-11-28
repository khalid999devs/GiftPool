import SwiftUI

struct PoolCardView: View {
    let overview: PoolOverview
    @EnvironmentObject private var templates: TemplateLibrary

    private var pool: Pool { overview.pool }

    var body: some View {
        let occasion = templates.occasion(for: pool.occasionKey)
        let summary = overview.summary

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                IconBadge(symbol: occasion.symbol, gradient: Theme.gradient(named: occasion.tint), size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pool.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text("For \(pool.recipientName) · \(occasion.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                if pool.status.isActive {
                    countdownChip(tint: Theme.tint(named: occasion.tint))
                }
            }

            HStack(spacing: 8) {
                Image(systemName: overview.selectedIdeaTitle == nil ? "lightbulb" : "gift.fill")
                    .foregroundStyle(overview.selectedIdeaTitle == nil ? Color.secondary : Theme.coral)
                Text(overview.selectedIdeaTitle ?? "No gift picked yet")
                    .lineLimit(1)
                    .foregroundStyle(overview.selectedIdeaTitle == nil ? .secondary : .primary)
            }
            .font(.subheadline.weight(.medium))

            VStack(alignment: .leading, spacing: 8) {
                ProgressBar(progress: summary.progress, tint: Theme.tint(named: occasion.tint))
                HStack {
                    Text("\(Money.format(summary.collected)) of \(Money.format(summary.target))")
                        .monospacedDigit()
                    Spacer()
                    if pool.status.isActive {
                        Text(tasksText)
                    } else {
                        StatusPill(status: pool.status)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .card()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the gift plan")
    }

    private var tasksText: String {
        let remaining = overview.remainingTaskCount
        if overview.tasks.isEmpty { return "No tasks" }
        return remaining == 0 ? "All tasks done" : "\(remaining) task\(remaining == 1 ? "" : "s") left"
    }

    private func countdownChip(tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(DateHelpers.countdownText(pool.occasionDate))
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
            Text(DateHelpers.occasionText(pool.occasionDate, style: .dateTime.day().month(.abbreviated)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

// A grey outline of a plan card, shown while plans load. It gently pulses.
struct PoolCardPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 8) {
                    Capsule()
                        .frame(width: 170, height: 14)
                    Capsule()
                        .frame(width: 110, height: 10)
                }
            }

            Capsule()
                .frame(width: 140, height: 10)

            Capsule()
                .frame(height: 8)
        }
        .foregroundStyle(Color(.systemFill))
        .opacity(pulse ? 0.45 : 1)
        .card()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
