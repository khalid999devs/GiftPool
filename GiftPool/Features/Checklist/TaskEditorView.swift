import SwiftUI

struct TaskEditorView: View {
    let task: GiftTask?
    let members: [Member]
    let currentUid: String
    let onSave: (TaskDraft) async throws -> Void
    var onDelete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskDraft
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        task: GiftTask?,
        members: [Member],
        currentUid: String,
        onSave: @escaping (TaskDraft) async throws -> Void,
        onDelete: (() async -> Void)? = nil
    ) {
        self.task = task
        self.members = members
        self.currentUid = currentUid
        self.onSave = onSave
        self.onDelete = onDelete

        if let task = task {
            _draft = State(initialValue: TaskDraft(task: task))
        } else {
            _draft = State(initialValue: TaskDraft())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("e.g. Wrap the gift", text: $draft.title)
                }

                Section("Who's doing it?") {
                    Picker("Assigned to", selection: $draft.assignedToUid) {
                        Text("No one yet").tag(String?.none)
                        ForEach(members) { member in
                            Text(member.uid == currentUid ? "Me" : member.displayName)
                                .tag(Optional(member.uid))
                        }
                    }
                }

                Section("Due date") {
                    Toggle("Set a due date", isOn: $draft.hasDueDate.animation())
                    if draft.hasDueDate {
                        DatePicker("Due", selection: $draft.dueDate, displayedComponents: .date)
                    }
                }

                if let onDelete {
                    Section {
                        Button("Delete Task", role: .destructive) {
                            Task {
                                await onDelete()
                                dismiss()
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(task == nil ? "Add" : "Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(Validators.trimmed(draft.title).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft)
                dismiss()
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
            isSaving = false
        }
    }
}
