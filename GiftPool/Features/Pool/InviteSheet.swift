import SwiftUI

struct InviteSheet: View {
    @ObservedObject var viewModel: PoolViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var invite: Invite?
    @State private var copied = false
    @State private var confirmRegenerate = false
    @State private var confirmRevoke = false

    private var token: String? {
        viewModel.pool?.inviteToken
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    IconBadge(symbol: "person.2.fill", size: 72)
                        .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text("Invite friends")
                            .font(.title2.weight(.bold))
                        Text("Friends tap Join in GiftPool and enter this code. Keep it away from \(viewModel.pool?.recipientName ?? "the recipient")!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let token {
                        codeCard(token)
                        manageButtons
                    } else {
                        invitationsOff
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .task(id: token) {
                invite = await viewModel.fetchCurrentInvite()
            }
            .errorBanner($viewModel.errorMessage)
        }
        .presentationDetents([.large])
    }

    private func codeCard(_ token: String) -> some View {
        let code = InviteService.displayCode(token)

        return VStack(spacing: 16) {
            Text(code)
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .textSelection(.enabled)
                .accessibilityLabel("Invitation code \(code.map(String.init).joined(separator: " "))")

            if let invite {
                Text(expiryText(for: invite))
                    .font(.caption)
                    .foregroundStyle(invite.isUsable() ? Color.secondary : Theme.danger)
            }

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(SoftButtonStyle(fullWidth: true))
                .sensoryFeedback(.success, trigger: copied)
                .disabled(invite?.isUsable() == false)

                ShareLink(item: shareMessage(code: code)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.sky, fullWidth: true))
                .disabled(invite?.isUsable() == false)
            }
        }
        .card(padding: 20)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private var manageButtons: some View {
        VStack(spacing: 10) {
            Button("Generate a New Code") {
                confirmRegenerate = true
            }
            .disabled(viewModel.isBusy("invite"))
            .alert("Generate a new code?", isPresented: $confirmRegenerate) {
                Button("Cancel", role: .cancel) {}
                Button("Generate") {
                    Task { await viewModel.regenerateInvite() }
                }
            } message: {
                Text("The old code stops working. Everyone who joined stays.")
            }

            Button("Turn Off Invitations", role: .destructive) {
                confirmRevoke = true
            }
            .disabled(viewModel.isBusy("invite"))
            .alert("Turn off invitations?", isPresented: $confirmRevoke) {
                Button("Cancel", role: .cancel) {}
                Button("Turn Off", role: .destructive) {
                    Task { await viewModel.revokeInvite() }
                }
            } message: {
                Text("Nobody new can join until you make a new code.")
            }
        }
        .font(.subheadline.weight(.medium))
    }

    private var invitationsOff: some View {
        VStack(spacing: 14) {
            InfoNote(text: "Invitations are turned off for this plan.", symbol: "lock.fill", tint: .gray)

            Button("Create Invitation Code") {
                Task { await viewModel.regenerateInvite() }
            }
            .buttonStyle(PrimaryButtonStyle(isBusy: viewModel.isBusy("invite")))
        }
    }

    private func expiryText(for invite: Invite) -> String {
        if !invite.isActive {
            return "This code has been turned off."
        }
        if invite.expiresAt <= .now {
            return "This code expired. Generate a new one."
        }
        return "Valid until \(invite.expiresAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func shareMessage(code: String) -> String {
        let title = viewModel.pool?.title ?? "our gift"
        return "Join my GiftPool plan \"\(title)\"! Open GiftPool, tap Join, and enter this code: \(code)"
    }
}
