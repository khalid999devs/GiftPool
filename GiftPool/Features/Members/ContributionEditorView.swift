import SwiftUI

struct ContributionEditorView: View {
    let member: Member
    @ObservedObject var viewModel: PoolViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var collectedText: String
    @State private var isSaving = false
    @State private var confirmUndo = false
    @State private var errorMessage: String?

    init(member: Member, viewModel: PoolViewModel) {
        self.member = member
        self.viewModel = viewModel
        _collectedText = State(initialValue: Money.editingText(member.collectedMinor))
    }

    private var current: Member {
        viewModel.member(withId: member.uid) ?? member
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        AvatarView(avatar: current.avatar, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.displayName)
                                .font(.headline)
                            StatusPill(state: viewModel.contributionState(for: current))
                        }
                    }

                    LabeledContent("Assigned", value: Money.format(current.assignedMinor))
                    LabeledContent("Confirmed so far", value: Money.format(current.collectedMinor))
                    LabeledContent("Outstanding", value: Money.format(current.outstandingMinor))
                }

                if current.hasReportedGiving {
                    Section {
                        InfoNote(
                            text: "\(current.displayName) says they've given. Record it once it's in your hands.",
                            symbol: "hourglass",
                            tint: Theme.plum
                        )
                    }
                }

                Section {
                    AmountField(title: "Total received", text: $collectedText)
                } header: {
                    Text("Received so far")
                }

                // Once everything is in, the shortcut flips to undo it, in case it was recorded by mistake.
                if current.outstandingMinor > 0 {
                    Section {
                        Button {
                            save(amount: current.assignedMinor)
                        } label: {
                            Label("Mark Fully Collected", systemImage: "checkmark.seal.fill")
                        }
                        .disabled(isSaving)
                    }
                } else if current.collectedMinor > 0 {
                    Section {
                        Button(role: .destructive) {
                            confirmUndo = true
                        } label: {
                            Label("Mark as Not Collected", systemImage: "arrow.uturn.backward.circle.fill")
                        }
                        .disabled(isSaving)
                        .alert("Mark as not collected?", isPresented: $confirmUndo) {
                            Button("Cancel", role: .cancel) {}
                            Button("Not Collected", role: .destructive) {
                                save(amount: 0)
                            }
                        } message: {
                            Text("The \(Money.format(current.collectedMinor)) goes back to \(Money.format(0)). You can then enter what actually arrived.")
                        }
                    }
                }

                if current.hasReportedGiving {
                    Section {
                        Button("Not Received Yet", role: .destructive, action: rejectReport)
                            .disabled(isSaving)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle("Record Contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveTypedAmount()
                        }
                        .fontWeight(.semibold)
                        .disabled(Money.parse(Validators.trimmed(collectedText)) == current.collectedMinor)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func saveTypedAmount() {
        let text = Validators.trimmed(collectedText)
        let amount = text.isEmpty ? 0 : Money.parse(text)

        guard let amount else {
            errorMessage = "Enter a valid amount."
            return
        }
        save(amount: amount)
    }

    private func save(amount: Int) {
        run {
            try await viewModel.recordCollection(amount, for: current)
        }
    }

    private func rejectReport() {
        run {
            try await viewModel.rejectReport(for: current)
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await work()
                dismiss()
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
            isSaving = false
        }
    }
}
