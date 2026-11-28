import SwiftUI

struct WelcomePage: Identifiable {
    let id: Int
    let title: String
    let message: String
    let colors: [Color]
}

struct WelcomeView: View {
    @Binding var path: [AuthViewModel.Mode]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The page the scroll view has settled on, and how far it has scrolled (0.0 to 2.0) while swiping.
    @State private var scrolledPage: Int? = 0
    @State private var progress: CGFloat = 0

    private let pages = [
        WelcomePage(
            id: 0,
            title: "Gift together.",
            message: "Plan one group gift with friends, all in one private place.",
            colors: [Color(hex: 0xFF9A5C), Color(hex: 0xF0508C)]
        ),
        WelcomePage(
            id: 1,
            title: "Decide as a group.",
            message: "Suggest ideas, vote once each, and talk it through.",
            colors: [Color(hex: 0xFFC24B), Color(hex: 0xFF7A59)]
        ),
        WelcomePage(
            id: 2,
            title: "Chip in fairly.",
            message: "Split the cost and see who has given. No payments in the app.",
            colors: [Color(hex: 0xA98BFF), Color(hex: 0xEC5A9C)]
        )
    ]

    private var currentPage: Int {
        scrolledPage ?? 0
    }

    private var clampedProgress: CGFloat {
        min(max(progress, 0), CGFloat(pages.count - 1))
    }

    // The page whose text is showing: whichever one is closest to the middle of the screen.
    private var textPage: Int {
        Int(clampedProgress.rounded())
    }

    private var isLastPage: Bool {
        textPage == pages.count - 1
    }

    var body: some View {
        VStack(spacing: -34) {
            WelcomePanel(colors: panelColors) {
                illustrations
            }
            .frame(maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)

            sheet
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                show(pages.count - 1)
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.7))
            .padding(.horizontal, Theme.margin)
            .frame(height: 44)
            .opacity(isLastPage ? 0 : 1)
            .allowsHitTesting(!isLastPage)
        }
        .animation(.easeInOut(duration: 0.25), value: isLastPage)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Pieces

    // A native paging scroll view, so the pictures follow the finger.
    private var illustrations: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(pages) { item in
                    WelcomeIllustration(page: item.id, isActive: item.id == currentPage)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollPosition(id: $scrolledPage)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x / max(geometry.containerSize.width, 1)
        } action: { _, newValue in
            progress = newValue
        }
    }

    private var sheet: some View {
        let page = pages[textPage]
        let distance = clampedProgress - CGFloat(textPage)

        return VStack(spacing: Theme.spacingL) {
            // The text fades out as its page leaves and the next one fades in.
            VStack(alignment: .leading, spacing: 12) {
                Text(page.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(page.message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(1 - min(abs(distance) * 2.5, 1))
            .offset(x: reduceMotion ? 0 : -distance * 40)

            pageDots

            VStack(spacing: Theme.spacingS) {
                Button {
                    if isLastPage {
                        path.append(.signUp)
                    } else {
                        show(currentPage + 1)
                    }
                } label: {
                    Text(isLastPage ? "Create account" : "Continue")
                        .contentTransition(.opacity)
                }
                .buttonStyle(InkButtonStyle())

                NavigationLink(value: AuthViewModel.Mode.signIn) {
                    Text("I already have an account")
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
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -50 {
                        show(currentPage + 1)
                    } else if value.translation.width > 50 {
                        show(currentPage - 1)
                    }
                }
        )
    }

    // The active dot stretches and darkens smoothly as you swipe.
    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(pages) { item in
                let closeness = max(0, 1 - abs(clampedProgress - CGFloat(item.id)))

                Capsule()
                    .fill(Color.primary.opacity(0.15 + 0.85 * closeness))
                    .frame(width: 6 + 18 * closeness, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(textPage + 1) of \(pages.count)")
    }

    // The background blends from one page's colors to the next while swiping.
    private var panelColors: [Color] {
        let lower = Int(clampedProgress.rounded(.down))
        let upper = min(lower + 1, pages.count - 1)
        let amount = Double(clampedProgress - CGFloat(lower))

        return zip(pages[lower].colors, pages[upper].colors).map { from, to in
            from.mix(with: to, by: amount)
        }
    }

    private func show(_ index: Int) {
        guard pages.indices.contains(index) else { return }

        withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) {
            scrolledPage = index
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView(path: .constant([]))
    }
}
