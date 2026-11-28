import SwiftUI

struct PoolDetailView: View {
    let focus: PoolSection?

    @StateObject private var viewModel: PoolViewModel
    @EnvironmentObject private var templates: TemplateLibrary
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var reminders: RemindersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var activeSheet: PoolSheet?
    @State private var pendingStatus: PoolStatus?
    @State private var pendingAction: NextStepAction?
    @State private var showDeleteConfirmation = false
    @State private var didApplyFocus = false

    private enum PoolSheet: String, Identifiable {
        case edit
        case invite

        var id: String { rawValue }
    }

    init(poolId: String, focus: PoolSection?, user: SessionUser, repository: GiftPoolRepository) {
        self.focus = focus
        _viewModel = StateObject(wrappedValue: PoolViewModel(poolId: poolId, user: user, repository: repository))
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .loading:
                LoadingStateView(title: "Opening plan…")

            case .missing:
                ContentUnavailableView(
                    "Plan not available",
                    systemImage: "gift",
                    description: Text("It may have been deleted, or you're not a member of it.")
                )

            case .failed(let message):
                ContentUnavailableView(
                    "Couldn't open this plan",
                    systemImage: "wifi.exclamationmark",
                    description: Text(message)
                )

            case .loaded:
                if let pool = viewModel.pool {
                    content(for: pool)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.loadState)
        .background(Theme.background)
        .navigationTitle(viewModel.pool?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isOwner, let pool = viewModel.pool {
                ToolbarItem(placement: .topBarTrailing) {
                    ownerMenu(for: pool)
                }
            }
        }
        .navigationDestination(for: PoolSection.self) { section in
            destination(for: section)
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(
            pendingStatus.map(actionTitle(for:)) ?? "",
            isPresented: isConfirmingStatus,
            presenting: pendingStatus
        ) { status in
            Button("Not Now", role: .cancel) {}
            Button(actionTitle(for: status), role: status == .cancelled ? .destructive : nil) {
                Task { await viewModel.changeStatus(to: status) }
            }
        } message: { status in
            Text(confirmationMessage(for: status))
        }
        .alert(pendingAction?.question ?? "", isPresented: isConfirmingAction, presenting: pendingAction) { action in
            Button("Cancel", role: .cancel) {}
            Button(action.confirmTitle) {
                Task { await viewModel.run(action) }
            }
        } message: { action in
            Text(action.message)
        }
        .alert("Delete this plan?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Plan", role: .destructive) {
                Task {
                    if await viewModel.deletePlan() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("It disappears for everyone in the plan.")
        }
        .overlay {
            if viewModel.showCelebration, let pool = viewModel.pool {
                CelebrationView(recipientName: pool.recipientName) {
                    viewModel.showCelebration = false
                }
                .transition(.opacity)
            }
        }
        .errorBanner($viewModel.errorMessage)
        .onAppear { viewModel.start() }
        .onChange(of: viewModel.loadState) {
            applyFocusIfNeeded()
        }
    }

    // MARK: Content

    private func content(for pool: Pool) -> some View {
        let occasion = templates.occasion(for: pool.occasionKey)
        let step = viewModel.nextStep

        return ScrollView {
            VStack(spacing: Theme.spacingM) {
                PoolHeroCard(pool: pool, occasion: occasion, summary: viewModel.summary)

                // A member who owes money sees their share card instead; it's their next step.
                if let me = viewModel.me, !viewModel.isOwner, viewModel.isActive, me.outstandingMinor > 0 {
                    MyShareCard(viewModel: viewModel, member: me)
                } else {
                    NextStepCard(step: step, isBusy: viewModel.isRunningShortcut) { action in
                        if case .markStatus(let status) = action {
                            pendingStatus = status
                        } else {
                            pendingAction = action
                        }
                    }
                }

                sectionList

                membersCard(for: pool)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private var sectionList: some View {
        VStack(spacing: 0) {
            NavigationLink(value: PoolSection.ideas) {
                SectionRow(title: "Ideas & Voting", subtitle: ideasSubtitle, symbol: "lightbulb.fill", tint: "sun")
            }

            Divider().padding(.leading, 68)

            NavigationLink(value: PoolSection.contributions) {
                SectionRow(
                    title: "Contributions",
                    subtitle: contributionsSubtitle,
                    symbol: "chart.pie.fill",
                    tint: "mint",
                    badge: reminders.openCount(poolId: viewModel.poolId)
                )
            }

            Divider().padding(.leading, 68)

            NavigationLink(value: PoolSection.checklist) {
                SectionRow(title: "Checklist", subtitle: checklistSubtitle, symbol: "checklist", tint: "plum")
            }

            Divider().padding(.leading, 68)

            NavigationLink(value: PoolSection.chat) {
                SectionRow(title: "Group Chat", subtitle: "Only members can read it", symbol: "bubble.left.and.bubble.right.fill", tint: "sky")
            }
        }
        .buttonStyle(.plain)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }

    private func membersCard(for pool: Pool) -> some View {
        HStack(spacing: 12) {
            AvatarStack(avatars: viewModel.sortedMembers.map(\.avatar), maxVisible: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.members.count) member\(viewModel.members.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                Text("Organized by \(viewModel.displayName(for: pool.ownerUid))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .layoutPriority(1)

            Spacer()

            if viewModel.isOwner && pool.isActive {
                // Icon only, so the member count and organizer name keep their room.
                Button {
                    activeSheet = .invite
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .buttonStyle(SoftButtonStyle())
                .accessibilityLabel("Invite")
            }
        }
        .card()
    }

    // MARK: Navigation and sheets

    @ViewBuilder
    private func destination(for section: PoolSection) -> some View {
        switch section {
        case .ideas:
            IdeasView(viewModel: viewModel)
        case .contributions:
            MembersView(viewModel: viewModel)
        case .chat:
            GroupChatView(pool: viewModel)
        case .checklist:
            ChecklistView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: PoolSheet) -> some View {
        switch sheet {
        case .edit:
            if let pool = viewModel.pool {
                PoolEditorView(mode: .edit(pool)) { draft, _ in
                    try await viewModel.updateDetails(draft)
                }
            }
        case .invite:
            InviteSheet(viewModel: viewModel)
        }
    }

    private func ownerMenu(for pool: Pool) -> some View {
        Menu {
            if pool.isActive {
                Button {
                    activeSheet = .invite
                } label: {
                    Label("Invite Friends", systemImage: "person.badge.plus")
                }

                Button {
                    activeSheet = .edit
                } label: {
                    Label("Edit Details", systemImage: "pencil")
                }
            }

            if !pool.status.allowedNextStatuses.isEmpty {
                Section {
                    ForEach(pool.status.allowedNextStatuses, id: \.self) { status in
                        Button(role: status == .cancelled ? .destructive : nil) {
                            pendingStatus = status
                        } label: {
                            Label(actionTitle(for: status), systemImage: status.symbol)
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Plan", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("Plan options")
    }

    private func applyFocusIfNeeded() {
        guard !didApplyFocus, viewModel.loadState == .loaded, let focus else { return }
        didApplyFocus = true
        router.path.append(focus)
    }

    // MARK: Copy

    private var isConfirmingStatus: Binding<Bool> {
        Binding(
            get: { pendingStatus != nil },
            set: { isPresented in
                if !isPresented {
                    pendingStatus = nil
                }
            }
        )
    }

    private var isConfirmingAction: Binding<Bool> {
        Binding(
            get: { pendingAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingAction = nil
                }
            }
        )
    }

    private func actionTitle(for status: PoolStatus) -> String {
        switch status {
        case .purchased: return "Mark as Purchased"
        case .completed: return "Mark as Delivered"
        case .cancelled: return "Cancel Plan"
        case .planning: return "Back to Planning"
        }
    }

    private func confirmationMessage(for status: PoolStatus) -> String {
        let recipient = viewModel.pool?.recipientName ?? "the recipient"

        switch status {
        case .purchased:
            return "Only once the gift is bought. You can't undo this."
        case .completed:
            return "\(recipient) has the gift. The plan moves to History."
        case .cancelled:
            return "Stops the plan for everyone. The chat stays readable."
        case .planning:
            return ""
        }
    }

    private var ideasSubtitle: String {
        if let selected = viewModel.selectedIdea {
            return "Picked: \(selected.title)"
        }
        let count = viewModel.ideas.count
        return count == 0 ? "No ideas yet" : "\(count) idea\(count == 1 ? "" : "s") · \(viewModel.votes.count) vote\(viewModel.votes.count == 1 ? "" : "s")"
    }

    private var contributionsSubtitle: String {
        let assigned = viewModel.members.filter { $0.assignedMinor > 0 }
        guard !assigned.isEmpty else { return "Nothing assigned yet" }

        let settled = assigned.filter { $0.outstandingMinor == 0 }.count
        return "\(settled) of \(assigned.count) settled"
    }

    private var checklistSubtitle: String {
        let done = viewModel.tasks.filter(\.isDone).count
        return viewModel.tasks.isEmpty ? "No tasks yet" : "\(done) of \(viewModel.tasks.count) done"
    }
}
