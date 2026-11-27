import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var gradient: LinearGradient = Theme.brandGradient
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.gentle(reduceMotion), value: progress)
        }
        .accessibilityElement()
        .accessibilityLabel("Collected")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

struct ProgressBar: View {
    let progress: Double
    var tint: Color = Theme.coral
    var height: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), progress > 0 ? height : 0))
            }
        }
        .frame(height: height)
        .animation(.gentle(reduceMotion), value: progress)
        .accessibilityElement()
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
