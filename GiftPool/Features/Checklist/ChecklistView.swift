import SwiftUI

struct ChecklistView: View {
    @ObservedObject var viewModel: PoolViewModel

    @State private var editorTarget: EditorTarget?
    @State private var editMode: EditMode = .inactive

    private enum EditorTarget: Identifiable {
        case new
        case edit(GiftTask)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let task): return task.id ?? "edit"
            }
        }
    }

    private var canManage: Bool {
        viewModel.isOwner && viewModel.isActive
    }

    var body: some View {
        List {
            Section {
                progressHeader
            }

            if !viewModel.tasks.isEmpty {
                Section {
                    ForEach(viewModel.sortedTasks) { task in
                        TaskRow(
                            task: task,
                            isDone: doneBinding(for: task),
                            assigneeName: task.assignedToUid.map { viewModel.displayName(for: $0) },
                            canToggle: viewModel.canToggle(task),
                            isClosed: !viewModel.isActive
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if canManage {
                                editorTarget = .edit(task)
                            }
                        }
                        .swipeActions {
                            if canManage {
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.deleteTask(task) }
                                }
                            }
                        }
                        .moveDisabled(!canManage)
                    }
                    .onMove { source, destination in
                        moveTasks(from: source, to: destination)
                    }
                } header: {
                    HStack(spacing: 0) {
                        Text("Tasks")
                        InfoButton(text: !viewModel.isActive
                                   ? "This plan is closed, so the tasks are read-only."
                                   : canManage
                                   ? "Tap a task to edit or assign it. Tap the pencil to reorder or delete tasks."
                                   : "You can tick off the tasks assigned to you.")
                    }
                }
            }
        }
        .overlay {
            if viewModel.tasks.isEmpty {
                ContentUnavailableView {
                    Label("No tasks yet", systemImage: "checklist")
                } description: {
                    Text(!viewModel.isActive
                         ? "No tasks were added to this plan."
                         : canManage ? "Add who buys, wraps and delivers the gift." : "The organizer hasn't added tasks yet.")
                } actions: {
                    if canManage {
                        Button("Add Task") { editorTarget = .new }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Checklist")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canManage {
                    // Pencil to reorder or delete tasks; it turns into a checkmark while editing.
                    Button {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: editMode.isEditing ? "checkmark" : "pencil")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(editMode.isEditing ? "Done Editing" : "Edit Tasks")

                    Button {
                        editorTarget = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add task")
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            editor(for: target)
        }
        .errorBanner($viewModel.errorMessage)
    }

    private var progressHeader: some View {
        let total = viewModel.tasks.count
        let done = viewModel.completedTaskCount
        let progress = total > 0 ? Double(done) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(done) of \(total) done")
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                Spacer()
                if total > 0 && done == total {
                    Label("All set", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.successText)
                }
            }
            ProgressBar(progress: progress, tint: Theme.plum)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func editor(for target: EditorTarget) -> some View {
        switch target {
        case .new:
            TaskEditorView(task: nil, members: viewModel.sortedMembers, currentUid: viewModel.uid) { draft in
                try await viewModel.saveTask(draft, editing: nil)
            }
        case .edit(let task):
            TaskEditorView(task: task, members: viewModel.sortedMembers, currentUid: viewModel.uid) { draft in
                try await viewModel.saveTask(draft, editing: task)
            } onDelete: {
                await viewModel.deleteTask(task)
            }
        }
    }

    private func doneBinding(for task: GiftTask) -> Binding<Bool> {
        Binding(
            get: { task.isDone },
            set: { newValue in
                Task { await viewModel.setTask(task, done: newValue) }
            }
        )
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        Task { await viewModel.moveTasks(from: source, to: destination) }
    }
}
