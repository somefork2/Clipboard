import SwiftUI

/// Sections of the sidebar.
enum SidebarSection: Hashable, Identifiable {
    case history
    case favorites
    case pasteStack
    case statistics
    case pinboard(UUID)

    var id: String {
        switch self {
        case .history: return "history"
        case .favorites: return "favorites"
        case .pasteStack: return "pasteStack"
        case .statistics: return "statistics"
        case .pinboard(let id): return id.uuidString
        }
    }
}

struct MainView: View {
    @Environment(ClipboardStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AppCoordinator.self) private var coordinator

    @State private var section: SidebarSection = .history
    @State private var searchText = ""
    @State private var typeFilter: ContentType?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingClearConfirmation = false
    @State private var showingWelcome = false

    var body: some View {
        @Bindable var subscriptions = subscriptions

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $section)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 280)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .background(Theme.background)
        .themedWindow()
        // The title bar is a separate AppKit surface; without this it keeps the
        // default white and floats above a themed window.
        .toolbarBackground(Theme.background, for: .windowToolbar)
        .frame(minWidth: 860, minHeight: 520)
        .toolbar { toolbar }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search clips")
        .sheet(isPresented: $showingWelcome) {
            WelcomeView { showingWelcome = false }
        }
        .onAppear {
            showingWelcome = !AppSettings.shared.hasCompletedOnboarding
        }
        .sheet(isPresented: $subscriptions.showingPaywall) {
            PaywallView()
                .environment(subscriptions)
        }
        .confirmationDialog(
            "Clear clipboard history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Except Favourites", role: .destructive) {
                store.clearHistory(keepingFavorites: true)
            }
            Button("Delete Everything", role: .destructive) {
                store.clearHistory(keepingFavorites: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the clips and any images stored with them. It cannot be undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyWellRequestClearHistory)) { _ in
            showingClearConfirmation = true
        }
        .overlay(alignment: .top) { conflictBanner }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .statistics:
            StatisticsView()
        case .pasteStack:
            PasteStackView()
        default:
            ClipboardListView(
                items: filteredItems,
                searchText: searchText,
                typeFilter: $typeFilter
            )
        }
    }

    private var filteredItems: [ClipboardItem] {
        var result = store.items

        switch section {
        case .favorites: result = result.filter(\.isFavorite)
        case .pinboard(let id): result = result.filter { $0.pinboard?.id == id }
        default: break
        }

        if let typeFilter {
            result = result.filter { $0.type == typeFilter }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.searchCorpus.contains(query) }
        }

        return result
    }

    // MARK: - Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Both icon buttons keep the system's toolbar styling so they match each
        // other and the Upgrade button. The stray patch behind them came from
        // forcing the appearance app-wide, which is fixed in ThemeManager, not
        // from the button style.
        ToolbarItemGroup {
            Button {
                QuickPastePanel.shared.toggle()
            } label: {
                Label("Palette", systemImage: "rectangle.and.text.magnifyingglass")
            }
            .help("Open the clipboard palette (⌥⌘V)")

            Button {
                coordinator.togglePause()
            } label: {
                Label(
                    coordinator.isPaused ? "Resume" : "Pause",
                    systemImage: coordinator.isPaused ? "play" : "pause"
                )
            }
            .help(coordinator.isPaused ? "Resume recording" : "Pause recording")

            if !subscriptions.isPro {
                Button("Upgrade") { subscriptions.showingPaywall = true }
            }
        }
    }

    @ViewBuilder
    private var conflictBanner: some View {
        if let message = coordinator.shortcutConflictMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Theme.separator, lineWidth: 0.5))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
