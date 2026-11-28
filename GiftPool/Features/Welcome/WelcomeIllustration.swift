import SwiftUI

// Three small scenes built from the same pieces: the gift, friend circles and the brand colors.
// A short loop plays on each page: friends flow in, votes land, shares fill the pool.
struct WelcomeIllustration: View {
    let page: Int
    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var floating = false
    @State private var breathing = false
    @State private var dashPhase: CGFloat = 0

    private let friends = ["Khalid", "Nadia", "Tanvir", "Sara"]
    // The same faces they picked in the demo, so the story matches the screenshots.
    private let friendAvatars = ["cool-1", "cute-4", "chill-1", "cute-1"]
    private let friendColors = [Theme.plum, Theme.mint, Theme.sun, Theme.sky]

    var body: some View {
        ZStack {
            switch page {
            case 0:
                togetherScene
            case 1:
                voteScene
            default:
                poolScene
            }
        }
        .frame(width: 340, height: 340)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                step = 2
                return
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                floating = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                dashPhase = -26
            }
        }
        .task(id: isActive) {
            guard isActive, !reduceMotion else { return }

            // Move the story forward every two seconds while this page is on screen: 0 → 1 → 2 → 0 …
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                    step = (step + 1) % 3
                }
            }
        }
    }

    // MARK: Page 1 – friends come together around the gift

    private var togetherScene: some View {
        let spots = [CGPoint(x: -122, y: -96), CGPoint(x: 122, y: -96), CGPoint(x: -128, y: 98), CGPoint(x: 128, y: 98)]

        return ZStack {
            ForEach(spots.indices, id: \.self) { index in
                flowLine(from: spots[index])
            }

            GiftBox(size: 132)
                .rotationEffect(.degrees(breathing ? -3 : 3))
                .offset(y: floating ? -5 : 5)

            // Friends drift toward the gift and back, like they're gathering around it.
            ForEach(friends.indices, id: \.self) { index in
                let pull: CGFloat = floating ? 0.9 : 1
                friendBubble(index, size: 58)
                    .offset(x: spots[index].x * pull, y: spots[index].y * pull)
            }
        }
    }

    private func flowLine(from point: CGPoint) -> some View {
        Path { path in
            let start = CGPoint(x: 170 + point.x, y: 170 + point.y)
            let end = CGPoint(x: 170, y: 175)
            let control = CGPoint(x: 170 + point.x * 0.2, y: 170 + point.y * 0.9)
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
        }
        .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [2, 11], dashPhase: dashPhase))
        .frame(width: 340, height: 340)
    }

    // MARK: Page 2 – votes land on the favorite

    private var voteScene: some View {
        let voters = Array(friends.indices.prefix(step + 2))

        return ZStack {
            ideaCard(symbol: "ticket.fill", tint: "plum", title: "Concert", voters: [3])
                .rotationEffect(.degrees(floating ? -12 : -9))
                .offset(x: -114, y: 24)

            ideaCard(symbol: "hifispeaker.fill", tint: "sky", title: "Speaker", voters: [])
                .rotationEffect(.degrees(floating ? 12 : 9))
                .offset(x: 114, y: 24)

            ideaCard(symbol: "camera.fill", tint: "sun", title: "Camera", voters: voters)
                .overlay(alignment: .top) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.coralText, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .offset(y: -22)
                        .scaleEffect(step == 2 ? 1 : 0.001)
                        .opacity(step == 2 ? 1 : 0)
                }
                .scaleEffect(1.08)
                .offset(y: (step == 2 ? -18 : -6) + (breathing ? -4 : 4))
        }
    }

    private func ideaCard(symbol: String, tint: String, title: String, voters: [Int]) -> some View {
        VStack(spacing: 14) {
            IconBadge(symbol: symbol, gradient: Theme.gradient(named: tint), size: 64)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: -8) {
                if voters.isEmpty {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 26, height: 26)
                }
                ForEach(voters, id: \.self) { index in
                    AvatarView(name: friends[index], avatarId: friendAvatars[index], size: 26, color: friendColors[index])
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 26)
        }
        .frame(width: 138, height: 188)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 20, y: 10)
    }

    // MARK: Page 3 – everyone's share fills the pool

    private var poolScene: some View {
        let given = step + 2
        let ringSize: CGFloat = 188

        return ZStack {
            Circle()
                .fill(.white.opacity(0.25))
                .frame(width: 236, height: 236)
                .scaleEffect(breathing ? 1.14 : 1)

            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 236, height: 236)
                .shadow(color: .black.opacity(0.14), radius: 24, y: 12)

            ForEach(friends.indices, id: \.self) { index in
                Circle()
                    .trim(from: CGFloat(index) / 4 + 0.02, to: CGFloat(index + 1) / 4 - 0.02)
                    .stroke(
                        index < given ? friendColors[index] : Color(.systemGray5),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
            }

            VStack(spacing: 2) {
                Text(Money.format(given * 200_000))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("of ৳8,000")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(friends.indices, id: \.self) { index in
                let angle = (Double(index) + 0.5) / 4 * 2 * .pi - .pi / 2
                friendBubble(index, size: 46)
                    .overlay(alignment: .bottomTrailing) {
                        if index < given {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, Theme.success)
                                .background(Circle().fill(.white).padding(2))
                                .offset(x: 4, y: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .offset(x: cos(angle) * 148, y: sin(angle) * 148)
            }
        }
    }

    // MARK: Shared

    private func friendBubble(_ index: Int, size: CGFloat) -> some View {
        AvatarView(name: friends[index], avatarId: friendAvatars[index], size: size, color: friendColors[index])
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

#Preview {
    WelcomePanel(colors: [Color(hex: 0xA98BFF), Color(hex: 0xEC5A9C)]) {
        WelcomeIllustration(page: 2)
    }
}
