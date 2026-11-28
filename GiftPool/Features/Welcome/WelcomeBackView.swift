import SwiftUI

// Shown to returning users who are signed out.
struct WelcomeBackView: View {
    @State private var floating = false
    @State private var opening = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: -34) {
            WelcomePanel(colors: [Color(hex: 0xFF9A5C), Color(hex: 0xF0508C)]) {
                hero
            }
            .frame(maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: Theme.spacingL) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome back.")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Your gift plans are right where you left them.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }

                VStack(spacing: Theme.spacingS) {
                    NavigationLink(value: AuthViewModel.Mode.signIn) {
                        Text("Sign in")
                    }
                    .buttonStyle(InkButtonStyle())

                    NavigationLink(value: AuthViewModel.Mode.signUp) {
                        Text("Create account")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.primary.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, Theme.spacingXL)
            .padding(.bottom, Theme.spacingS)
            .welcomeSheet()
        }
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                floating = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                opening = true
            }
        }
    }

    // The gift from the app icon, gently opening, with a few of your plans floating around it.
    private var hero: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 300, height: 300)

            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 220, height: 220)
                .scaleEffect(floating ? 1.06 : 0.94)

            GiftBox(size: 132, lidLift: opening ? 1 : 0)
                .offset(y: floating ? -6 : 6)

            planChip(symbol: "birthday.cake.fill", tint: Theme.coral, title: "Rafi's birthday", detail: "In 12 days")
                .offset(x: -70, y: floating ? -152 : -142)

            planChip(symbol: "checkmark.circle.fill", tint: Theme.success, title: "৳4,800", detail: "collected")
                .offset(x: 124, y: floating ? 74 : 62)

            planChip(symbol: "lightbulb.fill", tint: Theme.sun, title: "3 new ideas", detail: nil)
                .offset(x: -92, y: floating ? 128 : 138)
        }
        .frame(width: 360, height: 360)
        .accessibilityHidden(true)
    }

    private func planChip(symbol: String, tint: Color, title: String, detail: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

#Preview {
    NavigationStack {
        WelcomeBackView()
    }
}
