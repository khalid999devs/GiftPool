import SwiftUI

struct CelebrationView: View {
    let recipientName: String
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let sparkleColors: [Color] = [Theme.coral, Theme.sun, Theme.plum, Theme.sky, Theme.mint, Theme.rose]

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: onDone)

            VStack(spacing: 16) {
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        let angle = Double(index) / 12 * 2 * .pi
                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 16 : 8))
                            .foregroundStyle(sparkleColors[index % sparkleColors.count])
                            .offset(
                                x: cos(angle) * (appeared ? 92 : 24),
                                y: sin(angle) * (appeared ? 92 : 24)
                            )
                            .opacity(appeared ? 0 : 1)
                    }
                    Image(systemName: "gift.fill")
                        .font(.system(size: 76, weight: .semibold))
                        .foregroundStyle(Theme.brandGradient)
                        .symbolEffect(.bounce, value: appeared)
                }
                .frame(height: 150)
                .accessibilityHidden(true)

                Text("Gift delivered!")
                    .font(.title.weight(.bold))
                Text("You made \(recipientName)'s day, together. This plan now lives in History.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Done", action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(32)
            .scaleEffect(appeared ? 1 : 0.88)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    CelebrationView(recipientName: "Rafi") {}
}
