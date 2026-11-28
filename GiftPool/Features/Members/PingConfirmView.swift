import SwiftUI

struct PingConfirmView: View {
    let member: Member
    @ObservedObject var viewModel: PoolViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var didSend = false

    private var current: Member {
        viewModel.member(withId: member.uid) ?? member
    }

    private var isSending: Bool {
        viewModel.isBusy("ping-\(member.uid)")
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: didSend ? "checkmark.circle.fill" : "bell.badge.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(didSend ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.brandGradient))
                .contentTransition(.symbolEffect(.replace))
                .padding(.top, 12)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(didSend ? "Reminder sent" : "Remind \(current.displayName)?")
                    .font(.title3.weight(.bold))

                Text("A private nudge about the \(Money.format(current.outstandingMinor)) they still owe. Only they will see it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("You can send one reminder a day.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SoftButtonStyle(tint: .secondary, fullWidth: true))

                Button("Send Reminder", action: send)
                    .buttonStyle(PrimaryButtonStyle(isBusy: isSending))
                    .disabled(isSending || didSend)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .presentationDetents([.medium])
        .sensoryFeedback(.success, trigger: didSend)
    }

    private func send() {
        Task {
            guard await viewModel.ping(current) else { return }

            didSend = true
            try? await Task.sleep(for: .milliseconds(1200))
            dismiss()
        }
    }
}
