import SwiftUI

struct IdeasView: View {
    @ObservedObject var viewModel: PoolViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editorTarget: EditorTarget?

    private enum EditorTarget: Identifiable {
        case new
        case edit(GiftIdea)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let idea): return idea.id ?? "edit"
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                header

                if viewModel.ideas.isEmpty {
                    EmptyStateView(
                        symbol: "lightbulb.max.fill",
                        title: "No ideas yet",
                        message: viewModel.isDeciding
                            ? "Suggest the first gift for \(viewModel.pool?.recipientName ?? "them")."
                            : "No ideas were suggested for this plan.",
                        actionTitle: viewModel.isDeciding ? "Suggest an Idea" : nil,
                        action: { editorTarget = .new }
                    )
                    .card()
                }

                ForEach(orderedIdeas) { idea in
                    IdeaCard(
                        idea: idea,
                        viewModel: viewModel,
                        onSelect: { Task { await viewModel.select(idea) } },
                        onEdit: { editorTarget = .edit(idea) },
                        onDelete: { Task { await viewModel.deleteIdea(idea) } }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 16)
            .animation(.gentle(reduceMotion), value: orderedIdeas.map(\.id))
        }
        .background(Theme.background)
        .navigationTitle("Ideas & Voting")
        .toolbar {
            if viewModel.isDeciding {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Suggest an Idea")
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            editor(for: target)
        }
        .errorBanner($viewModel.errorMessage)
    }

    // A one-line summary, with the voting rules behind the (i).
    @ViewBuilder
    private var header: some View {
        if !viewModel.ideas.isEmpty {
            let ideaCount = viewModel.ideas.count
            let voteCount = viewModel.votes.count

            HStack(spacing: 2) {
                Text("\(ideaCount) idea\(ideaCount == 1 ? "" : "s") · \(voteCount) vote\(voteCount == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                InfoButton(text: viewModel.isOwner
                           ? "Everyone gets one vote and can change it. Pick the winner when you're ready."
                           : "You get one vote and can change it anytime. The organizer picks the winner.")
                Spacer()
            }
        }
    }

    // The picked idea comes first; the rest stay in the order they were suggested.
    private var orderedIdeas: [GiftIdea] {
        let pickedId = viewModel.pool?.selectedIdeaId
        let picked = viewModel.ideas.filter { $0.id == pickedId }
        let others = viewModel.ideas.filter { $0.id != pickedId }
        return picked + others
    }

    @ViewBuilder
    private func editor(for target: EditorTarget) -> some View {
        switch target {
        case .new:
            IdeaEditorView(idea: nil) { draft in
                try await viewModel.saveIdea(draft, editing: nil)
            }
        case .edit(let idea):
            IdeaEditorView(idea: idea) { draft in
                try await viewModel.saveIdea(draft, editing: idea)
            }
        }
    }
}
