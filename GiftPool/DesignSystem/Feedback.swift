import SwiftUI

struct ErrorBannerModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.danger)
                        Text(message)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            self.message = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .accessibilityLabel("Dismiss")
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.danger.opacity(0.3)))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(6))
                        if self.message == message { self.message = nil }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isStaticText)
                }
            }
            .animation(.gentle(reduceMotion), value: message)
    }
}

extension View {
    func errorBanner(_ message: Binding<String?>) -> some View {
        modifier(ErrorBannerModifier(message: message))
    }
}

struct LoadingStateView: View {
    var title = "Loading…"

    // Shown only if loading takes a moment, so fast loads don't flash a spinner.
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isVisible ? 1 : 0)
        .accessibilityElement(children: .combine)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = true
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.coral.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Theme.brandGradient)
            }
            .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
                    .padding(.horizontal, 30)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

struct InfoNote: View {
    let text: String
    var symbol = "info.circle.fill"
    var tint: Color = Theme.sky

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
