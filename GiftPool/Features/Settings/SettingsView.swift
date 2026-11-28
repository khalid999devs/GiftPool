import SwiftUI

struct SettingsView: View {
    let poolIds: [String]

    @EnvironmentObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var push: PushNotifications
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var isSaving = false
    @State private var savedName = false
    @State private var confirmSignOut = false
    @State private var showAvatarPicker = false
    @State private var errorMessage: String?

    private var hasNameChanges: Bool {
        let trimmed = Validators.trimmed(displayName)
        return Validators.displayNameError(trimmed) == nil && trimmed != session.user?.displayName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        // Tap the avatar to pick a face.
                        Button {
                            showAvatarPicker = true
                        } label: {
                            AvatarView(name: session.user?.displayName ?? "", avatarId: session.user?.avatarId, size: 76)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "pencil")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Theme.coral, in: Circle())
                                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 2))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change avatar")
                        .padding(.bottom, 6)
                        Text(session.user?.displayName ?? "")
                            .font(.title2.weight(.bold))
                        Text(session.user?.email ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack {
                        TextField("Display name", text: $displayName)
                            .textContentType(.name)
                            .submitLabel(.done)
                            .onSubmit(saveName)

                        // Save only shows up once the name has actually changed.
                        if isSaving {
                            ProgressView()
                        } else if hasNameChanges {
                            Button("Save", action: saveName)
                                .fontWeight(.semibold)
                                .buttonStyle(.borderless)
                        } else if savedName {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                                .accessibilityLabel("Saved")
                        }
                    }
                } header: {
                    HStack(spacing: 0) {
                        Text("Display name")
                        InfoButton(text: "This is how friends see you in your plans.")
                    }
                }

                Section {
                    Toggle(isOn: notificationsBinding) {
                        Label("Lock-screen reminders", systemImage: "bell.badge.fill")
                    }
                } header: {
                    HStack(spacing: 0) {
                        Text("Notifications")
                        InfoButton(text: "Get a lock-screen alert when an organizer reminds you about your share. Reminders always show under the bell on Home too.")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        confirmSignOut = true
                    }
                    .frame(maxWidth: .infinity)
                    .alert("Sign out?", isPresented: $confirmSignOut) {
                        Button("Cancel", role: .cancel) {}
                        Button("Sign Out", role: .destructive, action: signOut)
                    } message: {
                        Text("Your plans stay saved. Sign in again any time.")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .onAppear {
                displayName = session.user?.displayName ?? ""
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPickerView(name: session.user?.displayName ?? "", current: session.user?.avatarId) { avatarId in
                    try await session.updateAvatar(avatarId, poolIds: poolIds)
                }
            }
            .task {
                await push.refreshStatus()
            }
            // Coming back from iPhone Settings may have changed the permission.
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task { await push.refreshStatus() }
                }
            }
        }
    }

    // On asks iOS for permission. iOS doesn't let apps turn it off, so that opens iPhone Settings.
    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { push.status == .authorized || push.status == .provisional || push.status == .ephemeral },
            set: { turnOn in
                if turnOn && push.status == .notDetermined {
                    Task { await push.requestPermissionIfNeeded() }
                } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func saveName() {
        guard hasNameChanges, !isSaving else { return }
        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await session.updateDisplayName(displayName, poolIds: poolIds)
                savedName = true
                displayName = Validators.trimmed(displayName)
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
            isSaving = false
        }
    }

    private func signOut() {
        Task {
            do {
                try await session.signOut()
                dismiss()
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
        }
    }
}
