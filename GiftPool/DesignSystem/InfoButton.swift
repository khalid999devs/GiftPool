import SwiftUI

// A small (i) next to a heading. The explanation only shows when someone taps it,
// instead of a paragraph of grey text under every section.
struct InfoButton: View {
    let text: String

    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More info")
        .accessibilityHint(text)
        .popover(isPresented: $isShowing) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 250, alignment: .leading)
                .padding(16)
                .presentationCompactAdaptation(.popover)
        }
    }
}

#Preview {
    HStack {
        Text("Members")
            .font(.title3.weight(.bold))
        InfoButton(text: "Money changes hands in person. The organizer confirms what arrives.")
    }
}
