import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.brandGradient
    var isBusy = false

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, gradient: gradient, isBusy: isBusy)
    }

    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        let gradient: LinearGradient
        let isBusy: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            ZStack {
                configuration.label
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView().tint(.white)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(gradient, in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.coral
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        SoftButtonBody(configuration: configuration, tint: tint, fullWidth: fullWidth)
    }

    private struct SoftButtonBody: View {
        let configuration: Configuration
        let tint: Color
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.colorScheme) private var colorScheme

        // Bright tints are too light for text on a pale background, so the label uses a deeper shade.
        private var textColor: Color {
            colorScheme == .dark ? tint.mix(with: .white, by: 0.25) : tint.mix(with: .black, by: 0.4)
        }

        var body: some View {
            // Labels stay on one line. A row that runs out of room should reflow, not wrap a button.
            configuration.label
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: !fullWidth, vertical: false)
                .foregroundStyle(isEnabled ? textColor : .secondary)
                .padding(.horizontal, 14)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
                .background((isEnabled ? tint : Color.gray).opacity(0.13), in: Capsule())
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}

// A full-width button that sits under a PrimaryButtonStyle button as the second choice.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

// A calm, high-contrast button for entry screens, where the illustration should stay the hero.
// It inverts automatically in dark mode.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.primary, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
