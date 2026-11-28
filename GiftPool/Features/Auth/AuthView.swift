import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field {
        case name, email, password
    }

    init(mode: AuthViewModel.Mode = .signIn) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(mode: mode))
    }

    private var isSignUp: Bool {
        viewModel.mode == .signUp
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacingXL) {
                header
                formCard
                switchModeButton
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, Theme.spacingM)
            .padding(.bottom, Theme.spacingL)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Wait for the push animation to finish, so the keyboard doesn't slide in at the same time.
            try? await Task.sleep(for: .milliseconds(450))
            focusedField = isSignUp ? .name : .email
        }
        .animation(.gentle(reduceMotion), value: viewModel.mode)
        .animation(.gentle(reduceMotion), value: viewModel.errorMessage)
        .animation(.gentle(reduceMotion), value: viewModel.notice)
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSignUp ? "Create account" : "Sign in")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .contentTransition(.opacity)

            Text(isSignUp ? "Plan group gifts with your friends." : "Good to see you again.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formCard: some View {
        VStack(spacing: 14) {
            if isSignUp {
                HStack(spacing: 12) {
                    fieldIcon("person.fill")
                    TextField("Your name", text: $viewModel.displayName)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }
                .fieldBackground()
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                fieldIcon("envelope.fill")
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }
            .fieldBackground()

            HStack(spacing: 12) {
                fieldIcon("lock.fill")
                SecureField("Password", text: $viewModel.password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
            }
            .fieldBackground()

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            if viewModel.errorMessage == nil, let notice = viewModel.notice {
                Label(notice, systemImage: "envelope.badge.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.successText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            } else if isSignUp {
                Text("At least 6 characters.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button("Forgot password?") {
                    focusedField = nil
                    Task { await viewModel.resetPassword(using: session) }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.coralText)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(viewModel.isWorking)
            }

            Button {
                submit()
            } label: {
                if viewModel.isWorking {
                    ProgressView()
                        .tint(Color(.systemBackground))
                } else {
                    Text(isSignUp ? "Create account" : "Sign in")
                }
            }
            .buttonStyle(InkButtonStyle())
            .disabled(!viewModel.canSubmit)
            .opacity(viewModel.canSubmit || viewModel.isWorking ? 1 : 0.4)
            .padding(.top, 8)
        }
    }

    private var switchModeButton: some View {
        Button {
            viewModel.errorMessage = nil
            viewModel.notice = nil
            viewModel.mode = isSignUp ? .signIn : .signUp
        } label: {
            HStack(spacing: 4) {
                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                    .foregroundStyle(Color.secondary)
                Text(isSignUp ? "Sign in" : "Create one")
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.coralText)
            }
            .font(.subheadline)
            .frame(minHeight: 44)
        }
    }

    private func fieldIcon(_ name: String) -> some View {
        Image(systemName: name)
            .foregroundStyle(.secondary)
            .frame(width: 20)
            .accessibilityHidden(true)
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.submit(using: session) }
    }
}
