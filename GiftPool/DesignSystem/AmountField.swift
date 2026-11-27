import SwiftUI

struct AmountField: View {
    let title: String
    @Binding var text: String
    var compact = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(Money.symbol)
                .font(compact ? .body.weight(.semibold) : .title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            if compact {
                // Hugs the number, so the ৳ sign stays right next to it.
                field.fixedSize()
            } else {
                field
            }
        }
        .frame(minWidth: compact ? 96 : nil, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private var field: some View {
        TextField(title, text: $text, prompt: Text("0"))
            .focused($isFocused)
            .keyboardType(.decimalPad)
            .font(compact ? .body.weight(.semibold).monospacedDigit() : .title3.weight(.semibold).monospacedDigit())
            .multilineTextAlignment(compact ? .trailing : .leading)
            .accessibilityLabel("\(title), in taka")
    }
}
