import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    let senderName: String
    var senderAvatarId: String? = nil
    let isMine: Bool
    let showsSender: Bool
    // Only the last message in a run from the same person shows the avatar.
    var endsGroup = true
    let delivery: MessageDelivery
    let onRetry: (() -> Void)?
    let onDiscard: () -> Void
    // Only set for your own sent messages while the plan is open (editing only for 15 minutes).
    var onEdit: (() -> Void)? = nil
    var onUnsend: (() -> Void)? = nil

    // Tapping a bubble shows its exact time, like Messenger.
    @State private var showsTime = false
    @State private var confirmsUnsend = false

    private var timeText: String {
        message.createdAt?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    // Room taken by the avatar column, so the name and time line up with the bubble.
    private let avatarColumn: CGFloat = 36

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
            if showsTime && !timeText.isEmpty {
                Text(timeText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
                    .transition(.opacity)
            }

            if showsSender && !isMine {
                Text(senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, avatarColumn + 4)
            }

            // The avatar sits level with the bottom of the bubble.
            HStack(alignment: .bottom, spacing: 8) {
                if isMine {
                    Spacer(minLength: 48)
                } else if endsGroup {
                    AvatarView(name: senderName, avatarId: senderAvatarId, size: 28)
                } else {
                    Color.clear.frame(width: 28, height: 1)
                }

                bubble
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showsTime.toggle()
                        }
                    }

                if !isMine {
                    Spacer(minLength: 48)
                }
            }

            statusLine
                .padding(.leading, isMine ? 0 : avatarColumn)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .opacity(delivery == .sending ? 0.7 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityActions {
            if let onEdit {
                Button("Edit", action: onEdit)
            }
            if onUnsend != nil {
                Button("Unsend") { confirmsUnsend = true }
            }
        }
        .alert("Unsend this message?", isPresented: $confirmsUnsend) {
            Button("Unsend", role: .destructive) { onUnsend?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be removed for everyone in the chat.")
        }
    }

    private var unsentText: String {
        isMine ? "You unsent a message" : "\(senderName) unsent a message"
    }

    private var accessibilityText: String {
        if message.isUnsent {
            return "\(unsentText), \(timeText)"
        }
        return "\(isMine ? "You" : senderName): \(message.body)\(message.isEdited ? ", edited" : ""), \(timeText)"
    }

    // Long-press a message to copy it, or to edit or unsend your own, like Messenger. An unsent one keeps its place as an outlined note.
    @ViewBuilder
    private var bubble: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        if message.isUnsent {
            Text(unsentText)
                .font(.subheadline.italic())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.35)))
        } else {
            Text(message.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(isMine ? .white : .primary)
                .background(bubbleBackground, in: shape)
                .contentShape(.contextMenuPreview, shape)
                .contextMenu {
                    Button("Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = message.body
                    }
                    if let onEdit {
                        Button("Edit", systemImage: "pencil", action: onEdit)
                    }
                    if onUnsend != nil {
                        Button("Unsend", systemImage: "arrow.uturn.backward", role: .destructive) {
                            confirmsUnsend = true
                        }
                    }
                }
        }
    }

    private var bubbleBackground: AnyShapeStyle {
        if case .failed = delivery {
            return AnyShapeStyle(Theme.danger.opacity(0.85))
        }
        return isMine ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.cardBackground)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch delivery {
        case .sending:
            Label("Sending…", systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)

        case .failed(let reason):
            HStack(spacing: 10) {
                Text(reason)
                    .foregroundStyle(Theme.danger)
                if let onRetry {
                    Button("Retry", action: onRetry)
                }
                Button("Delete", role: .destructive, action: onDiscard)
            }
            .font(.caption2.weight(.semibold))

        case .delivered:
            if message.isEdited && !message.isUnsent {
                Text("Edited")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack {
        MessageBubble(
            message: ChatMessage(id: "1", senderUid: "b", body: "How about the instant camera?", createdAt: .now, clientNonce: "1"),
            senderName: "Nadia",
            isMine: false,
            showsSender: true,
            delivery: .delivered,
            onRetry: {},
            onDiscard: {}
        )
        MessageBubble(
            message: ChatMessage(id: "2", senderUid: "a", body: "Love it, adding it to ideas!", createdAt: .now, clientNonce: "2"),
            senderName: "You",
            isMine: true,
            showsSender: false,
            delivery: .sending,
            onRetry: {},
            onDiscard: {}
        )
        MessageBubble(
            message: ChatMessage(id: "3", senderUid: "a", body: "", createdAt: .now, clientNonce: "3", unsentAt: .now),
            senderName: "You",
            isMine: true,
            showsSender: false,
            delivery: .delivered,
            onRetry: {},
            onDiscard: {}
        )
    }
    .padding()
}
