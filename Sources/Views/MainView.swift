import SwiftUI
import SwiftData

struct MainView: View {
    @StateObject private var viewModel = ClipboardListViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var pinboards: [Pinboard] = []

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $viewModel.selectedSidebarItem, pinboards: pinboards)
                .onChange(of: viewModel.selectedSidebarItem) { viewModel.applyFilters() }
        } detail: {
            switch viewModel.selectedSidebarItem {
            case .statistics: StatisticsView(viewModel: viewModel)
            case .themes: ThemesView()
            case .pasteStack: PasteStackView(viewModel: viewModel)
            default: ClipboardListView(viewModel: viewModel)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 550)
        .onAppear {
            setupViewModel()
        }
    }

    private func setupViewModel() {
        guard let container = try? ModelContainer(for: ClipboardItem.self, Pinboard.self) else { return }
        let context = ModelContext(container)
        viewModel.setup(modelContext: context)

        // Load pinboards
        let descriptor = FetchDescriptor<Pinboard>(sortBy: [SortDescriptor(\.sortOrder)])
        pinboards = (try? context.fetch(descriptor)) ?? []
    }
}
