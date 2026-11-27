import SwiftUI

enum Theme {
    static let coral = Color(hex: 0xFF6B5A)
    // Darker shades for text on light backgrounds (about 5:1 contrast on white).
    static let coralText = Color(hex: 0xD2453A)
    static let successText = Color(hex: 0x1B7F4D)
    static let sunText = Color(hex: 0x9A6200)
    static let rose = Color(hex: 0xF0508C)
    static let sky = Color(hex: 0x3B9EF5)
    static let plum = Color(hex: 0x8B5CF6)
    static let mint = Color(hex: 0x14B8A6)
    static let sun = Color(hex: 0xF5A524)
    static let success = Color(hex: 0x22A867)
    static let danger = Color(hex: 0xE5484D)

    // Layout: one side margin and an 8-point spacing rhythm used on every screen.
    static let margin: CGFloat = 20
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let buttonHeight: CGFloat = 56

    static let cardRadius: CGFloat = 22
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0xFF8A5B), Color(hex: 0xF0508C)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let avatarPalette: [Color] = [coral, sky, plum, mint, sun, rose]

    static func tint(named name: String) -> Color {
        switch name {
        case "sky": return sky
        case "plum": return plum
        case "mint": return mint
        case "sun": return sun
        case "rose": return rose
        default: return coral
        }
    }

    static func gradient(named name: String) -> LinearGradient {
        let colors: [Color]
        switch name {
        case "sky": colors = [Color(hex: 0x5AC8FA), Color(hex: 0x3B6CF5)]
        case "plum": colors = [Color(hex: 0xB18CFF), Color(hex: 0x7C3AED)]
        case "mint": colors = [Color(hex: 0x3DDBB4), Color(hex: 0x0E9F8E)]
        case "sun": colors = [Color(hex: 0xFFC94A), Color(hex: 0xF5841F)]
        case "rose": colors = [Color(hex: 0xFF7EB3), Color(hex: 0xE0457B)]
        default: colors = [Color(hex: 0xFF8A5B), Color(hex: 0xF0508C)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // hashValue changes every launch, so use the character values instead.
    static func avatarColor(for name: String) -> Color {
        let seed = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return avatarPalette[seed % avatarPalette.count]
    }

    static func tint(for status: PoolStatus) -> Color {
        switch status {
        case .planning: return sky
        case .purchased: return plum
        case .completed: return success
        case .cancelled: return .gray
        }
    }

    static func tint(for state: ContributionState) -> Color {
        switch state {
        case .notAssigned, .archived: return .gray
        case .pending: return sun
        case .partiallyCollected: return sky
        case .awaitingVerification: return plum
        case .collected: return success
        }
    }

    static func tint(for status: ReminderStatus) -> Color {
        switch status {
        case .open: return sun
        case .resolved: return success
        case .closed: return .gray
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Animation {
    static func gentle(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
    }
}
