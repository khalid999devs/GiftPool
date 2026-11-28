import SwiftUI

struct JoinPoolView: View {
    let user: SessionUser
    let onJoined: (String) -> Void

    @StateObject private var viewModel: JoinPoolViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var codeFocused: Bool

    init(user: SessionUser, repository: GiftPoolRepository, onJoined: @escaping (String) -> Void) {
        self.user = user
        self.onJoined = onJoined
        _viewModel = StateObject(wrappedValue: JoinPoolViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    IconBadge(symbol: "ticket.fill", size: 72)
                        .padding(.top, 12)
                    VStack(spacing: 6) {
                        Text("Join a plan")
                            .font(.title2.weight(.bold))
                        Text("Enter the code a friend shared with you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let invite = viewModel.invite {
                        previewCard(invite)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    } else {
                        codeEntry
                            .transition(.opacity)
                    }

                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .animation(.gentle(reduceMotion), value: viewModel.invite)
            }
            .background(Theme.background)
            .navigationTitle("Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { codeFocused = true }
        }
    }

    private var codeEntry: some View {
        VStack(spacing: 14) {
            HStack {
                TextField("ABCD-EFGH-JKLM-NPQR", text: $viewModel.code)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($codeFocused)
                    .submitLabel(.search)
                    .onSubmit(lookUp)
                    .accessibilityLabel("Invitation code")
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first {
                        viewModel.code = first
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
            }
            .fieldBackground()

            Button("Find Plan", action: lookUp)
                .buttonStyle(PrimaryButtonStyle(isBusy: viewModel.isWorking))
                .disabled(viewModel.code.isEmpty || viewModel.isWorking)
        }
    }

    private func previewCard(_ invite: Invite) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("You're invited to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(invite.poolTitle)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    AvatarView(name: invite.ownerName, size: 24)
                    Text("Organized by \(invite.ownerName)")
                        .font(.subheadline)
                }
            }
            Text("Code valid until \(invite.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Join Plan") {
                Task {
                    if let poolId = await viewModel.join(as: user) {
                        dismiss()
                        onJoined(poolId)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(isBusy: viewModel.isWorking))
            .disabled(viewModel.isWorking)

            Button("Use a different code") {
                viewModel.reset()
            }
            .font(.subheadline)
        }
        .card(padding: 20)
    }

    private func lookUp() {
        codeFocused = false
        Task { await viewModel.lookUp(uid: user.uid) }
    }
}
