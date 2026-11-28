import SwiftUI

struct PoolEditorView: View {
    enum Mode {
        case create
        case edit(Pool)
    }

    let mode: Mode
    let onSave: (PoolDraft, [String]) async throws -> Void

    @EnvironmentObject private var templates: TemplateLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PoolDraft
    @State private var starterTasks: [StarterTaskOption] = []
    @State private var customTask = ""
    @State private var lastSuggestedTitle = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private struct StarterTaskOption: Identifiable {
        let id = UUID()
        var title: String
        var isIncluded = true
        var isCustom = false
    }

    init(mode: Mode, onSave: @escaping (PoolDraft, [String]) async throws -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _draft = State(initialValue: PoolDraft())
        case .edit(let pool):
            _draft = State(initialValue: PoolDraft(pool: pool))
        }
    }

    private var isCreating: Bool {
        if case .create = mode {
            return true
        }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                occasionSection

                Section("Who's it for?") {
                    TextField("Recipient's name", text: $draft.recipientName)
                        .textContentType(.name)
                    TextField("Plan title", text: $draft.title)
                }

                Section("When and how much") {
                    if isCreating {
                        DatePicker("Occasion date", selection: $draft.occasionDate, in: Date.now..., displayedComponents: .date)
                    } else {
                        DatePicker("Occasion date", selection: $draft.occasionDate, displayedComponents: .date)
                    }

                    HStack {
                        // The field already says "Target budget" to VoiceOver, so the visible label is skipped.
                        Text("Target budget")
                            .accessibilityHidden(true)
                        Spacer()
                        AmountField(title: "Target budget", text: $draft.budgetText, compact: true)
                    }
                }

                Section("Note") {
                    TextField("Anything the group should know", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if isCreating {
                    starterChecklistSection
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle(isCreating ? "New Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isCreating ? "Create" : "Save", action: save)
                            .fontWeight(.semibold)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear(perform: loadStarterTasks)
            .onChange(of: draft.occasionKey) {
                suggestTitle()
                loadStarterTasks()
            }
            .onChange(of: draft.recipientName) {
                suggestTitle()
            }
        }
    }

    // MARK: Sections

    private var occasionSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(templates.content.occasions) { occasion in
                        occasionChip(occasion)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Occasion")
        } footer: {
            if let issue = templates.loadIssue {
                Text(issue)
            }
        }
    }

    private func occasionChip(_ occasion: OccasionTemplate) -> some View {
        let isSelected = draft.occasionKey == occasion.id

        return Button {
            draft.occasionKey = occasion.id
        } label: {
            VStack(spacing: 8) {
                IconBadge(symbol: occasion.symbol, gradient: Theme.gradient(named: occasion.tint), size: 44)
                Text(occasion.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 84)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.tint(named: occasion.tint) : .clear, lineWidth: 2)
            )
            .opacity(isSelected ? 1 : 0.75)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(occasion.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var starterChecklistSection: some View {
        Section {
            ForEach($starterTasks) { $task in
                Toggle(task.title, isOn: $task.isIncluded)
            }

            HStack {
                TextField("Add your own task", text: $customTask)
                    .onSubmit(addCustomTask)
                Button("Add", action: addCustomTask)
                    .disabled(Validators.trimmed(customTask).isEmpty)
            }
        } header: {
            Text("Starter checklist")
        }
    }

    // MARK: Actions

    private func loadStarterTasks() {
        guard isCreating else { return }

        let templateTasks = templates.taskTitles(forOccasion: draft.occasionKey).map { StarterTaskOption(title: $0) }
        let customTasks = starterTasks.filter(\.isCustom)
        starterTasks = templateTasks + customTasks
    }

    private func addCustomTask() {
        let title = Validators.trimmed(customTask)
        guard !title.isEmpty, title.count <= GiftTask.maxTitleLength else { return }

        starterTasks.append(StarterTaskOption(title: title, isCustom: true))
        customTask = ""
    }

    private func suggestTitle() {
        guard isCreating else { return }

        let recipient = Validators.trimmed(draft.recipientName)
        guard !recipient.isEmpty else { return }

        // Only replace the title while the user hasn't typed their own.
        guard draft.title.isEmpty || draft.title == lastSuggestedTitle else { return }

        let occasion = templates.occasion(for: draft.occasionKey).title
        let suggestion = String("\(recipient)'s \(occasion) Gift".prefix(Pool.maxTitleLength))
        draft.title = suggestion
        lastSuggestedTitle = suggestion
    }

    private func save() {
        let taskTitles = starterTasks.filter(\.isIncluded).map(\.title)
        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft, taskTitles)
                dismiss()
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
            isSaving = false
        }
    }
}
