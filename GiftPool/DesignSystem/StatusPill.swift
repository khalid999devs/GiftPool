import SwiftUI

struct StatusPill: View {
    let text: String
    var symbol: String?
    var tint: Color = Theme.coral
    var onColor = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(onColor ? .white : tint)
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(onColor ? Color.white : Color.primary.opacity(0.8))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(onColor ? Color.white.opacity(0.22) : tint.opacity(0.14), in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

extension StatusPill {
    init(status: PoolStatus, onColor: Bool = false) {
        self.init(text: status.title, symbol: status.symbol, tint: Theme.tint(for: status), onColor: onColor)
    }

    init(state: ContributionState) {
        self.init(text: state.title, symbol: state.symbol, tint: Theme.tint(for: state))
    }

    init(reminder: ReminderStatus) {
        self.init(text: reminder.title, tint: Theme.tint(for: reminder))
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusPill(status: .planning)
        StatusPill(state: .awaitingVerification)
        StatusPill(reminder: .resolved)
        AvatarStack(avatars: ["Khalid", "Nadia Islam", "Tanvir Hasan", "Mehedi", "Sara"].map { AvatarInfo(name: $0) })
    }
    .padding()
}
