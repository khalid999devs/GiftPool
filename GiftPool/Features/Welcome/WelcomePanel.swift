import SwiftUI

// The colorful top half of the welcome screens: a gradient with soft light and a little confetti.
struct WelcomePanel<Content: View>: View {
    let colors: [Color]
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 40)
                .offset(x: drift ? -110 : -90, y: -150)

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .offset(x: drift ? 140 : 120, y: 120)

            confetti

            content
                .padding(.top, 72)
                .padding(.bottom, 48)
        }
        .clipped()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private var confetti: some View {
        ZStack {
            dot(size: 8, x: -150, y: -210)
            dot(size: 5, x: 130, y: -240)
            dot(size: 10, x: 160, y: -60)
            dot(size: 6, x: -170, y: 40)
            dot(size: 7, x: -60, y: 190)
        }
        .accessibilityHidden(true)
    }

    private func dot(size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(.white.opacity(0.5))
            .frame(width: size, height: size)
            .offset(x: x, y: drift ? y - 6 : y + 6)
    }
}

extension View {
    // White rounded sheet that sits over the bottom of a WelcomePanel.
    func welcomeSheet() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous)
                    .fill(Color(.systemBackground))
                    .ignoresSafeArea(edges: .bottom)
            )
    }
}
