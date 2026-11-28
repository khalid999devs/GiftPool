import SwiftUI

// The first thing a new user sees: two clear paths, one for organizers and one for invited friends.
struct GetStartedCards: View {
    let onStart: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would you like to do?")
                .font(.title3.weight(.bold))
                .padding(.bottom, 4)

            choiceCard(
                symbol: "gift.fill",
                tint: "coral",
                title: "Start a gift",
                message: "Organize a gift and invite friends with a code.",
                action: onStart
            )

            choiceCard(
                symbol: "ticket.fill",
                tint: "plum",
                title: "Join with a code",
                message: "A friend invited you? Enter their code.",
                action: onJoin
            )
        }
    }

    private func choiceCard(symbol: String, tint: String, title: String, message: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                IconBadge(symbol: symbol, gradient: Theme.gradient(named: tint), size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GetStartedCards(onStart: {}, onJoin: {})
        .padding()
        .background(Theme.background)
}
