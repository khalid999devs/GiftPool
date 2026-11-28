import SwiftUI
import Combine

enum AppRoute: Hashable {
    case pool(id: String, focus: PoolSection?)
}

enum PoolSection: Hashable {
    case ideas
    case contributions
    case chat
    case checklist
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func openPool(_ poolId: String, focus: PoolSection? = nil) {
        path = NavigationPath()
        path.append(AppRoute.pool(id: poolId, focus: focus))
    }
}
