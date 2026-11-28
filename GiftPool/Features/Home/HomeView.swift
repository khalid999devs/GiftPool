import SwiftUI

struct HomeView: View {
    let user: SessionUser
    @StateObject private var viewModel: HomeViewModel
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var reminders: RemindersViewModel
    @EnvironmentObject private var push: PushNotifications
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeSheet: HomeSheet?

    private enum HomeSheet: String, Identifiable {
        case create, join, reminders, settings
        var id: String { rawValue }
    }

    init(user: SessionUser, repository: GiftPoolRepository) {
        self.user = user
        _viewModel = StateObject(wrappedValue: HomeViewModel(uid: user.uid, repository: repository))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Picker("Plans", selection: $viewModel.segment.animation(.gentle(reduceMotion))) {
                        ForEach(HomeViewModel.Segment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    content
                }
                .animation(.easeOut(duration: 0.3), value: viewModel.isLoading)
                .padding(.horizontal, Theme.margin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(HomeBackground())
            .toolbar { toolbarContent }
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if hasAnyPlans {
                    actionBar
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .pool(let id, let focus):
                    PoolDetailView(poolId: id, focus: focus, user: user, repository: session.repository)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                sheetContent(sheet)
            }
            .errorBanner($viewModel.errorMessage)
            .errorBanner($session.profileError)
            .onAppear { viewModel.start() }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hi, \(firstName)")
                .font(.largeTitle.weight(.bold))
            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        let items = viewModel.segment == .active ? viewModel.activePools : viewModel.historyPools

        if viewModel.isLoading {
            VStack(spacing: 14) {
                ForEach(0..<2, id: \.self) { _ in
                    PoolCardPlaceholder()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading your plans")
            .transition(.opacity)
        } else if items.isEmpty, let loadError = viewModel.loadError {
            ContentUnavailableView {
                Label("Couldn't load your plans", systemImage: "wifi.exclamationmark")
            } description: {
                Text(loadError)
            } actions: {
                Button("Try Again") { viewModel.retry() }
                    .buttonStyle(.bordered)
            }
            .transition(.opacity)
        } else if items.isEmpty {
            emptyState
                .transition(.opacity)
        } else {
            LazyVStack(spacing: 14) {
                ForEach(items) { overview in
                    NavigationLink(value: AppRoute.pool(id: overview.id, focus: nil)) {
                        PoolCardView(overview: overview)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .animation(.gentle(reduceMotion), value: items.map(\.id))
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.segment == .active {
            GetStartedCards(
                onStart: { activeSheet = .create },
                onJoin: { activeSheet = .join }
            )
        } else {
            EmptyStateView(
                symbol: "clock.arrow.circlepath",
                title: "No history yet",
                message: "Delivered and cancelled plans will appear here."
            )
            .card()
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                activeSheet = .join
            } label: {
                Label("Join", systemImage: "ticket.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)

            Button {
                activeSheet = .create
            } label: {
                Label("New Plan", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, Theme.margin)
        .padding(.bottom, 8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // The app's mark and name, without the glass capsule so nothing gets clipped.
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text("GiftPool")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("GiftPool")
            .accessibilityAddTraits(.isHeader)
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                activeSheet = .reminders
            } label: {
                Image(systemName: reminders.unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: reminders.unreadCount)
            }
            .badge(reminders.unreadCount)
            .accessibilityLabel(reminders.unreadCount > 0 ? "Reminders, \(reminders.unreadCount) unread" : "Reminders")
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        // The profile picture sits on its own, without a glass button around it.
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                activeSheet = .settings
            } label: {
                AvatarView(avatar: user.avatar, size: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")
        }
        .sharedBackgroundVisibility(.hidden)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .create:
            PoolEditorView(mode: .create) { draft, taskTitles in
                let poolId = try await viewModel.createPool(draft, taskTitles: taskTitles, owner: user)
                router.openPool(poolId)
                await push.requestPermissionIfNeeded()
            }
        case .join:
            JoinPoolView(user: user, repository: session.repository) { poolId in
                router.openPool(poolId)
                Task { await push.requestPermissionIfNeeded() }
            }
        case .reminders:
            RemindersView()
                .environmentObject(router)
        case .settings:
            SettingsView(poolIds: viewModel.poolIds)
        }
    }

    // MARK: Helpers

    private var hasAnyPlans: Bool {
        !viewModel.activePools.isEmpty || !viewModel.historyPools.isEmpty
    }

    private var firstName: String {
        String(user.displayName.split(separator: " ").first ?? "there")
    }

    private var headerSubtitle: String {
        let count = viewModel.activePools.count
        switch count {
        case 0: return "Let's plan something lovely."
        case 1: return "1 gift in the works"
        default: return "\(count) gifts in the works"
        }
    }
}

private struct HomeBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Theme.background
            LinearGradient(
                colors: [Theme.coral.opacity(0.16), Theme.rose.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 420)
        }
        .ignoresSafeArea()
    }
}
