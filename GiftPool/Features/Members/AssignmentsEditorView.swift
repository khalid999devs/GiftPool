import SwiftUI

struct AssignmentsEditorView: View {
    @ObservedObject var viewModel: PoolViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var amountTexts: [String: String] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var members: [Member] {
        viewModel.sortedMembers
    }

    private var target: Int {
        viewModel.pool?.budgetMinor ?? 0
    }

    private var parsedAmounts: [String: Int]? {
        var result: [String: Int] = [:]

        for member in members {
            let text = Validators.trimmed(amountTexts[member.uid] ?? "")
            if text.isEmpty {
                result[member.uid] = 0
            } else if let amount = Money.parse(text) {
                result[member.uid] = amount
            } else {
                return nil
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                totalsSection

                Section {
                    ForEach(members) { member in
                        memberRow(member)
                    }
                } header: {
                    HStack(spacing: 0) {
                        Text("Amount per person")
                        InfoButton(text: "Split equally gives any leftover paisa to the first few people, so the total matches exactly. Money already received never changes.")
                    }
                }

                Section {
                    Button(action: splitEqually) {
                        Label("Split \(Money.format(target)) equally", systemImage: "equal.circle.fill")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle("Assign Amounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                            .fontWeight(.semibold)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear(perform: loadCurrentAmounts)
        }
    }

    // MARK: Sections

    private var totalsSection: some View {
        Section {
            LabeledContent("Target budget", value: Money.format(target))

            if let total = parsedAmounts?.values.reduce(0, +) {
                let difference = total - target

                LabeledContent("Assigned") {
                    Text(Money.format(total))
                        .monospacedDigit()
                        .foregroundStyle(difference == 0 ? Theme.success : .primary)
                }

                if difference < 0 {
                    Label("\(Money.format(-difference)) still unassigned", systemImage: "exclamationmark.circle")
                        .foregroundStyle(Theme.sunText)
                } else if difference > 0 {
                    Label("\(Money.format(difference)) over the target", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.danger)
                } else {
                    Label("Matches the target", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.successText)
                }
            } else {
                Label("One of the amounts isn't a valid number", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Theme.danger)
            }
        }
        .font(.subheadline)
    }

    private func memberRow(_ member: Member) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                AvatarView(avatar: member.avatar, size: 30)
                Text(member.uid == viewModel.uid ? "You" : member.displayName)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer()
                AmountField(title: "\(member.displayName)'s share", text: binding(for: member.uid), compact: true)
                    .frame(maxWidth: 130)
            }

            if let amount = Money.parse(amountTexts[member.uid] ?? ""), amount < member.collectedMinor {
                Text("Can't be less than the \(Money.format(member.collectedMinor)) already given.")
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    // MARK: Actions

    private func binding(for uid: String) -> Binding<String> {
        Binding(
            get: { amountTexts[uid] ?? "" },
            set: { amountTexts[uid] = $0 }
        )
    }

    private func loadCurrentAmounts() {
        for member in members {
            amountTexts[member.uid] = Money.editingText(member.assignedMinor)
        }
    }

    private func splitEqually() {
        let shares = MoneyCalculator.equalSplit(total: target, count: members.count)

        for (member, share) in zip(members, shares) {
            amountTexts[member.uid] = Money.editingText(share)
        }
    }

    private func save() {
        guard let amounts = parsedAmounts else {
            errorMessage = "Fix the amounts that aren't valid numbers."
            return
        }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await viewModel.saveAssignments(amounts)
                dismiss()
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
            isSaving = false
        }
    }
}
