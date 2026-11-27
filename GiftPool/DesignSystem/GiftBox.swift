import SwiftUI

// The gift from the app icon: a white box, a rose ribbon and a bow made of three friends.
struct GiftBox: View {
    var size: CGFloat = 140
    // 0 is closed; 1 lifts the lid and bow a little, like the gift is about to open.
    var lidLift: CGFloat = 0

    private let ribbon = Color(hex: 0xF0508C)

    var body: some View {
        VStack(spacing: 0) {
            bow
                .zIndex(1)
                .offset(y: -size * 0.12 * lidLift)

            lid
                .padding(.top, -size * 0.06)
                .offset(y: -size * 0.12 * lidLift)
                .rotationEffect(.degrees(-4 * lidLift), anchor: .bottomLeading)

            box
                .padding(.top, -size * 0.02)
        }
        .shadow(color: Color(hex: 0x7A1A3A).opacity(0.25), radius: size * 0.12, y: size * 0.08)
        .accessibilityHidden(true)
    }

    private var bow: some View {
        ZStack {
            friend(Theme.sun, diameter: size * 0.3)
                .offset(x: -size * 0.24, y: size * 0.04)
            friend(Theme.sky, diameter: size * 0.3)
                .offset(x: size * 0.24, y: size * 0.04)
            friend(Theme.plum, diameter: size * 0.36)
        }
        .frame(height: size * 0.36)
    }

    private var lid: some View {
        RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
            .fill(.white)
            .frame(width: size, height: size * 0.26)
            .overlay {
                Rectangle()
                    .fill(ribbon)
                    .frame(width: size * 0.16)
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.09, style: .continuous))
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
            .fill(LinearGradient(colors: [.white, Color(hex: 0xFFEAF0)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.86, height: size * 0.64)
            .overlay {
                Rectangle()
                    .fill(ribbon)
                    .frame(width: size * 0.16)
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.11, style: .continuous))
    }

    private func friend(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .overlay(Circle().stroke(.white, lineWidth: diameter * 0.12))
    }
}

#Preview {
    GiftBox(size: 180)
        .padding(40)
        .background(Theme.brandGradient)
}
