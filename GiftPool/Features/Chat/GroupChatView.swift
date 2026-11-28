import SwiftUI

struct GroupChatView: View {
    @ObservedObject var pool: PoolViewModel
    @StateObject private var chat: ChatViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var composerFocused: Bool

    init(pool: PoolViewModel) {
        self.pool = pool
        _chat = StateObject(wrappedValue: ChatViewModel(poolId: pool.poolId, repository: pool.repository))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    olderMessagesButton(proxy: proxy)

                    if chat.isLoading {
                        LoadingStateView(title: "Loading messages…")
                            .frame(height: 240)
                    } else if chat.messages.isEmpty, let loadError = chat.loadError {
                        EmptyStateView(
                            symbol: "wifi.exclamationmark",
                            title: "Couldn't load messages",
                            message: loadError
                        )
                        .padding(.top, 40)
                    } else if chat.messages.isEmpty {
                        EmptyStateView(
                            symbol: "bubble.left.and.bubble.right.fill",
                            title: pool.isActive ? "Start the conversation" : "No messages",
                            message: pool.isActive
                                ? "Only people in this plan can read it. \(pool.pool?.recipientName ?? "The recipient") can't."
                                : "Nobody wrote in this plan's chat."
                        )
                        .padding(.top, 40)
                    }

                    ForEach(rows) { row in
                        if let dateLabel = row.dateLabel {
                            Text(dateLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 12)
                        }

                        MessageBubble(
                            message: row.message,
                            senderName: pool.displayName(for: row.message.senderUid),
                            senderAvatarId: pool.member(withId: row.message.senderUid)?.avatarId,
                            isMine: row.message.senderUid == pool.uid,
                            showsSender: row.showsSender,
                            endsGroup: row.endsGroup,
                            delivery: chat.delivery(of: row.message),
                            onRetry: pool.isActive ? { chat.retry(row.message) } : nil,
                            onDiscard: { chat.discard(row.message) },
                            onEdit: pool.isActive && chat.canEdit(row.message, myUid: pool.uid) ? { edit(row.message) } : nil,
                            onUnsend: pool.isActive && chat.canUnsend(row.message, myUid: pool.uid) ? { chat.unsend(row.message) } : nil
                        )
                        .id(row.id)
                        .padding(.top, row.showsSender ? 10 : 0)
                        .padding(.bottom, row.endsGroup ? 4 : 0)
                        .transition(.opacity.combined(with: .offset(y: 12)))
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .animation(.gentle(reduceMotion), value: chat.messages.count)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chat.messages.last?.stableId) {
                withAnimation(.gentle(reduceMotion)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if pool.isActive {
                composer
            } else {
                InfoNote(text: "This plan is closed. You can still read the chat.", symbol: "lock.fill", tint: .gray)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("Group Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AvatarStack(avatars: pool.sortedMembers.map(\.avatar), size: 28, maxVisible: 3)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .errorBanner($chat.errorMessage)
        .onAppear { chat.start() }
    }

    // MARK: Pieces

    @ViewBuilder
    private func olderMessagesButton(proxy: ScrollViewProxy) -> some View {
        if chat.hasOlder {
            Button {
                let anchorId = rows.first?.id
                Task {
                    await chat.loadOlder()
                    if let anchorId {
                        proxy.scrollTo(anchorId, anchor: .top)
                    }
                }
            } label: {
                if chat.isLoadingOlder {
                    ProgressView()
                } else {
                    Text("Load earlier messages")
                }
            }
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 12)
        }
    }

    private var composer: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if chat.draft.count > ChatMessage.maxBodyLength - 100 {
                Text("\(chat.draft.count)/\(ChatMessage.maxBodyLength)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(chat.draft.count > ChatMessage.maxBodyLength ? Theme.danger : .secondary)
                    .padding(.trailing, 64)
            }

            if let editing = chat.editing {
                editingBar(editing)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message", text: $chat.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    chat.send(as: pool.uid)
                } label: {
                    Image(systemName: chat.editing == nil ? "arrow.up" : "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.brandGradient, in: Circle())
                        .opacity(chat.canSend ? 1 : 0.4)
                }
                .disabled(!chat.canSend)
                .sensoryFeedback(.impact(weight: .light), trigger: chat.messages.count)
                .accessibilityLabel(chat.editing == nil ? "Send message" : "Save edit")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: chat.draft) { _, newValue in
            if newValue.count > ChatMessage.maxBodyLength {
                chat.draft = String(newValue.prefix(ChatMessage.maxBodyLength))
            }
        }
    }

    // Shown above the message box while you edit one of your messages.
    private func editingBar(_ message: ChatMessage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.coral)

            VStack(alignment: .leading, spacing: 1) {
                Text("Editing message")
                    .font(.caption.weight(.semibold))
                Text(message.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                chat.cancelEditing()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Cancel editing")
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func edit(_ message: ChatMessage) {
        chat.startEditing(message)
        composerFocused = true
    }

    // MARK: Grouping

    private struct ChatRow: Identifiable {
        let message: ChatMessage
        let showsSender: Bool
        let endsGroup: Bool
        let dateLabel: String?

        var id: String { message.stableId }
    }

    private var rows: [ChatRow] {
        let messages = chat.messages
        var result: [ChatRow] = []

        for (index, message) in messages.enumerated() {
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil
            let date = message.createdAt ?? .now
            let startsNewBlock = startsTimeBlock(message, after: previous)

            result.append(ChatRow(
                message: message,
                showsSender: startsNewBlock || startsNewGroup(message, after: previous),
                endsGroup: next.map { startsNewGroup($0, after: message) || startsTimeBlock($0, after: message) } ?? true,
                dateLabel: startsNewBlock ? timeLabel(for: date) : nil
            ))
        }
        return result
    }

    // A new group starts when someone else speaks, or after five quiet minutes.
    private func startsNewGroup(_ message: ChatMessage, after previous: ChatMessage?) -> Bool {
        guard let previous else { return true }
        let gap = (message.createdAt ?? .now).timeIntervalSince(previous.createdAt ?? .now)
        return previous.senderUid != message.senderUid || gap > 300
    }

    // Like Messenger: a time heading starts each block, on a new day or after a quiet spell of 2 hours or more.
    // Messages in between share that heading; tap one to see its exact time.
    private static let quietSpell: TimeInterval = 2 * 60 * 60

    private func startsTimeBlock(_ message: ChatMessage, after previous: ChatMessage?) -> Bool {
        guard let previous else { return true }
        let date = message.createdAt ?? .now
        let previousDate = previous.createdAt ?? .now
        return !Calendar.current.isDate(date, inSameDayAs: previousDate) || date.timeIntervalSince(previousDate) >= Self.quietSpell
    }

    private func timeLabel(for date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return "Today · \(time)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday · \(time)"
        }
        return "\(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(time)"
    }
}
