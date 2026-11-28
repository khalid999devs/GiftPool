import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var reminders: RemindersViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !reminders.items.isEmpty {
                    Section {
                        ForEach(reminders.items) { item in
                            Button {
                                open(item)
                            } label: {
                                ReminderRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                if item.ping.isUnread {
                                    Button("Mark Read") {
                                        Task { await reminders.markRead(item) }
                                    }
                                    .tint(Theme.sky)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if reminders.items.isEmpty {
                    ContentUnavailableView(
                        "No reminders",
                        systemImage: "bell.slash",
                        description: Text("When an organizer nudges you about your share, it appears here.")
                    )
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
                if reminders.unreadCount > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task { await reminders.markAllRead() }
                        } label: {
                            Label {
                                Text("Mark All Read")
                            } icon: {
                                DoubleCheckmark()
                            }
                        }
                    }
                }
            }
            .errorBanner($reminders.errorMessage)
        }
    }

    private func open(_ item: ReminderItem) {
        Task { await reminders.markRead(item) }
        dismiss()
        router.openPool(item.poolId, focus: .contributions)
    }
}

struct ReminderRow: View {
    let item: ReminderItem
    var compact = false
    var onAcknowledge: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: item.status == .resolved ? "checkmark" : "bell.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.tint(for: item.status).gradient, in: Circle())

                if item.ping.isUnread {
                    Circle()
                        .fill(Theme.coral)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
                        .accessibilityLabel("Unread")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if !compact {
                    Text(item.poolTitle)
                        .font(.subheadline.weight(.semibold))
                }

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(compact ? .primary : .secondary)

                HStack(spacing: 8) {
                    StatusPill(reminder: item.status)
                    if let sentAt = item.ping.sentAt {
                        Text(sentAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            if compact, item.ping.isUnread, let onAcknowledge {
                Button("Got it", action: onAcknowledge)
                    .buttonStyle(SoftButtonStyle(tint: Theme.sky))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        switch item.status {
        case .open:
            return "Your \(Money.format(item.ping.memberAmountAtSend)) share is still open."
        case .resolved:
            return "Your \(Money.format(item.ping.memberAmountAtSend)) share is settled. Thank you!"
        case .closed:
            return "This reminder no longer applies."
        }
    }
}

// Two overlapping ticks, the "read" sign people know from messaging apps.
private struct DoubleCheckmark: View {
    var body: some View {
        HStack(spacing: -7) {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark")
        }
        .font(.body.weight(.semibold))
    }
}
