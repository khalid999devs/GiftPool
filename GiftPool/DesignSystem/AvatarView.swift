import SwiftUI

// What it takes to draw someone's avatar: their name for the initials, and the face they picked.
struct AvatarInfo: Equatable {
    let name: String
    var avatarId: String?
}

// The faces people can pick in Account. The images live in Assets.xcassets/Avatars.
enum AvatarLibrary {
    struct Category: Identifiable {
        let title: String
        let ids: [String]

        var id: String { title }
    }

    static let groups = [
        Category(title: "Cute", ids: (1...8).map { "cute-\($0)" }),
        Category(title: "Cool", ids: (1...8).map { "cool-\($0)" }),
        Category(title: "Chill", ids: (1...8).map { "chill-\($0)" }),
        Category(title: "Funny", ids: (1...8).map { "funny-\($0)" })
    ]

    static func contains(_ id: String?) -> Bool {
        guard let id else { return false }
        return groups.contains { $0.ids.contains(id) }
    }
}

struct AvatarView: View {
    let name: String
    var avatarId: String?
    var size: CGFloat = 36
    var color: Color?

    init(name: String, avatarId: String? = nil, size: CGFloat = 36, color: Color? = nil) {
        self.name = name
        self.avatarId = avatarId
        self.size = size
        self.color = color
    }

    init(avatar: AvatarInfo, size: CGFloat = 36) {
        self.init(name: avatar.name, avatarId: avatar.avatarId, size: size)
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        Group {
            // A picked face, or the initials when there isn't one.
            if AvatarLibrary.contains(avatarId), let avatarId {
                Image("Avatars/\(avatarId)")
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill((color ?? Theme.avatarColor(for: name)).gradient)
                    .overlay {
                        Text(initials)
                            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct AvatarStack: View {
    let avatars: [AvatarInfo]
    var size: CGFloat = 30
    var maxVisible = 4

    var body: some View {
        HStack(spacing: -size * 0.25) {
            ForEach(Array(avatars.prefix(maxVisible).enumerated()), id: \.offset) { _, avatar in
                AvatarView(avatar: avatar, size: size)
                    .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
            }
            if avatars.count > maxVisible {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay {
                        Text("+\(avatars.count - maxVisible)")
                            .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(avatars.count) members")
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            AvatarView(name: "Khalid", avatarId: "cool-1", size: 60)
            AvatarView(name: "Sara Ahmed", size: 60)
        }
        AvatarStack(avatars: [
            AvatarInfo(name: "Khalid", avatarId: "cute-1"),
            AvatarInfo(name: "Nadia Islam"),
            AvatarInfo(name: "Tanvir Hasan", avatarId: "funny-2"),
            AvatarInfo(name: "Sara Ahmed"),
            AvatarInfo(name: "Mehedi Hasan")
        ])
    }
}
