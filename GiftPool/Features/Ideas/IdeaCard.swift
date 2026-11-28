import SwiftUI

struct IdeaCard: View {
    let idea: GiftIdea
    @ObservedObject var viewModel: PoolViewModel
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var templates: TemplateLibrary
    @State private var confirmPick = false
    @State private var confirmDelete = false
    @State private var photo: UIImage?

    private var ideaId: String { idea.id ?? "" }
    private var isSelected: Bool { viewModel.pool?.selectedIdeaId == ideaId }
    private var isMyVote: Bool { viewModel.myVoteIdeaId == ideaId }
    private var voteCount: Int { viewModel.voteCounts[ideaId] ?? 0 }

    var body: some View {
        let category = templates.category(for: idea.categoryKey)

        VStack(alignment: .leading, spacing: 14) {
            if idea.photoId != nil {
                photoView
            }

            HStack(alignment: .top, spacing: 12) {
                IconBadge(
                    symbol: category?.symbol ?? "gift.fill",
                    gradient: isSelected ? Theme.brandGradient : Theme.gradient(named: "sun"),
                    size: 44
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(idea.title)
                        .font(.headline)
                    Text(subtitle(category: category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Text(Money.format(idea.estimatedMinor))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .fixedSize()
            }

            if let note = idea.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let link = idea.link, let url = URL(string: link) {
                Link(destination: url) {
                    Label(shopName(for: url), systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .tint(Theme.coralText)
                .accessibilityHint("Opens the product page")
            }

            voteSummary

            actions
        }
        .card()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.brandGradient, lineWidth: 2)
            }
        }
    }

    // MARK: Pieces

    private var photoView: some View {
        Color(.tertiarySystemFill)
            .frame(height: 180)
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("Photo of \(idea.title)")
            .task(id: idea.photoId) {
                await loadPhoto()
            }
    }

    // Photos are downloaded once, then kept in memory.
    private func loadPhoto() async {
        guard let photoId = idea.photoId, let ideaId = idea.id else { return }

        if let cached = PhotoCache.images.object(forKey: photoId as NSString) {
            photo = cached
            return
        }

        guard let data = try? await viewModel.repository.fetchIdeaPhoto(ideaId: ideaId, poolId: viewModel.poolId),
              let image = UIImage(data: data) else { return }

        PhotoCache.images.setObject(image, forKey: photoId as NSString)
        withAnimation(.easeOut(duration: 0.25)) {
            photo = image
        }
    }

    private func shopName(for url: URL) -> String {
        let host = url.host() ?? "Open link"
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var voteSummary: some View {
        let memberCount = max(viewModel.members.count, 1)

        return VStack(alignment: .leading, spacing: 6) {
            ProgressBar(progress: Double(voteCount) / Double(memberCount), tint: isMyVote ? Theme.coral : Theme.sun, height: 6)

            HStack(spacing: 8) {
                Text("\(voteCount) vote\(voteCount == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .contentTransition(.numericText())

                if voteCount > 0 {
                    AvatarStack(avatars: viewModel.voterAvatars(for: ideaId), size: 20, maxVisible: 5)
                }

                Spacer()

                badge
            }
            .foregroundStyle(.secondary)
        }
    }

    // One row when it fits. With bigger text, Pick moves to its own line instead of squeezing.
    @ViewBuilder
    private var actions: some View {
        if viewModel.isDeciding {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    voteButton
                    pickButton
                    Spacer(minLength: 0)
                    moreMenu
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        voteButton
                        Spacer(minLength: 0)
                        moreMenu
                    }
                    pickButton
                }
            }
            .alert("Pick \(idea.title)?", isPresented: $confirmPick) {
                Button("Cancel", role: .cancel) {}
                Button("Pick", action: onSelect)
            } message: {
                Text("Everyone will see it as the group's gift.")
            }
            .alert("Delete this idea?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: onDelete)
            } message: {
                if isSelected {
                    Text("It's the group's pick, so the plan goes back to choosing a gift.")
                } else if voteCount > 0 {
                    Text("Its \(voteCount) vote\(voteCount == 1 ? "" : "s") will be cleared too.")
                }
            }
        }
    }

    private var voteButton: some View {
        Button {
            Task { await viewModel.toggleVote(for: idea) }
        } label: {
            Label(isMyVote ? "Voted" : "Vote", systemImage: isMyVote ? "hand.thumbsup.fill" : "hand.thumbsup")
                .symbolEffect(.bounce, value: isMyVote)
        }
        .buttonStyle(SoftButtonStyle(tint: isMyVote ? Theme.coral : .secondary))
        .disabled(viewModel.isBusy("vote"))
        .sensoryFeedback(.selection, trigger: isMyVote)
        .accessibilityHint(isMyVote ? "Removes your vote" : "Moves your single vote to this idea")
    }

    @ViewBuilder
    private var pickButton: some View {
        if viewModel.isOwner && !isSelected {
            Button("Pick This Gift") {
                confirmPick = true
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.plum))
            .disabled(viewModel.isBusy("select"))
        }
    }

    @ViewBuilder
    private var moreMenu: some View {
        if viewModel.canEdit(idea) || viewModel.canDelete(idea) {
            Menu {
                if viewModel.canEdit(idea) {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                }
                if viewModel.canDelete(idea) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("More actions for \(idea.title)")
        }
    }

    @ViewBuilder
    private var badge: some View {
        if isSelected {
            StatusPill(text: "Picked", symbol: "crown.fill", tint: Theme.coral)
        } else if viewModel.leadingIdeaIds.contains(ideaId) {
            let isTie = viewModel.leadingIdeaIds.count > 1
            StatusPill(text: isTie ? "Tied" : "Leading", symbol: isTie ? "equal" : "flame.fill", tint: Theme.sun)
        }
    }

    private func subtitle(category: GiftCategory?) -> String {
        let author = idea.createdBy == viewModel.uid ? "you" : viewModel.displayName(for: idea.createdBy)
        if let category {
            return "\(category.title) · suggested by \(author)"
        }
        return "Suggested by \(author)"
    }
}
