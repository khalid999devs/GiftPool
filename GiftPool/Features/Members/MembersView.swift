import SwiftUI

struct MembersView: View {
    @ObservedObject var viewModel: PoolViewModel

    @EnvironmentObject private var reminders: RemindersViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showAssignments = false
    @State private var showInvite = false
    @State private var recordTarget: Member?
    @State private var pingTarget: Member?
    @State private var confirmRemindAll = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BudgetCard(summary: viewModel.summary)

                if let me = viewModel.me, !viewModel.isOwner, me.assignedMinor > 0 {
                    MyShareCard(viewModel: viewModel, member: me)
                }

                myReminders

                if viewModel.isOwner && viewModel.isActive {
                    Button {
                        showAssignments = true
                    } label: {
                        Label(
                            viewModel.summary.assigned == 0 ? "Assign Amounts" : "Adjust Amounts",
                            systemImage: "slider.horizontal.3"
                        )
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.coral, fullWidth: true))
                }

                HStack {
                    SectionHeader(title: "Members", info: "Money changes hands in person. The organizer confirms what arrives, and only then does it count as collected.")
                    remindAllButton
                }
                .padding(.top, Theme.spacingS)

                ForEach(viewModel.sortedMembers) { member in
                    MemberContributionRow(
                        member: member,
                        viewModel: viewModel,
                        onRecord: { recordTarget = member },
                        onPing: { pingTarget = member }
                    )
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 16)
            .animation(.gentle(reduceMotion), value: viewModel.members)
        }
        .background(Theme.background)
        .navigationTitle("Contributions")
        .toolbar {
            if viewModel.isOwner && viewModel.isActive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInvite = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Invite friends")
                }
            }
        }
        .sheet(isPresented: $showAssignments) {
            AssignmentsEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $showInvite) {
            InviteSheet(viewModel: viewModel)
        }
        .sheet(item: $recordTarget) { member in
            ContributionEditorView(member: member, viewModel: viewModel)
        }
        .sheet(item: $pingTarget) { member in
            PingConfirmView(member: member, viewModel: viewModel)
        }
        .errorBanner($viewModel.errorMessage)
    }

    // One tap reminds everyone who still owes and wasn't reminded today.
    @ViewBuilder
    private var remindAllButton: some View {
        let count = viewModel.membersToRemind.count

        if viewModel.isOwner && viewModel.isActive && count > 1 {
            Button {
                confirmRemindAll = true
            } label: {
                if viewModel.isBusy("remind-all") {
                    ProgressView()
                } else {
                    Label("Remind All", systemImage: "bell")
                }
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.sun))
            .disabled(viewModel.isBusy("remind-all"))
            .alert("Remind \(count) people?", isPresented: $confirmRemindAll) {
                Button("Cancel", role: .cancel) {}
                Button("Remind") {
                    Task { await viewModel.remindAll() }
                }
            } message: {
                Text("Each gets a private nudge about what they still owe.")
            }
        }
    }

    @ViewBuilder
    private var myReminders: some View {
        let items = reminders.items(forPool: viewModel.poolId)

        if !viewModel.isOwner && !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reminders for you")
                    .font(.headline)

                ForEach(items) { item in
                    ReminderRow(item: item, compact: true) {
                        Task { await reminders.markRead(item) }
                    }
                }
            }
            .card()
        }
    }
}
