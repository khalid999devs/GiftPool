import SwiftUI

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, padding)
            .padding(.vertical, padding + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View {
        modifier(CardModifier(padding: padding))
    }

    func fieldBackground() -> some View {
        modifier(FieldBackground())
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var info: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                if let info {
                    InfoButton(text: info)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IconBadge: View {
    let symbol: String
    var gradient: LinearGradient = Theme.brandGradient
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
