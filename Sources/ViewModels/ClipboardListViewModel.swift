import Foundation
import SwiftData
import SwiftUI

@MainActor
final class ClipboardListViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var filteredItems: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: ContentType? = nil
    @Published var selectedSidebarItem: SidebarItem = .history
    @Published var pasteStackManager = PasteStackManager()
    @Published var statistics = StatisticsViewModel()
    @Published var isSyncing = false
    @Published var isPaused = false

    private let monitor = ClipboardMonitor()
    private let typeDetector = TypeDetector()
    private let shortcutsManager = GlobalShortcutsManager.shared
    private let themeManager = ThemeManager.shared
    private let syncManager = CloudKitSyncManager.shared

    var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        monitor.onItemCaptured = { [weak self] item in
            Task { @MainActor in self?.saveItem(item) }
        }
        monitor.startMonitoring()
        loadItems()
        registerShortcuts()
    }

    // MARK: - Shortcuts

    private func registerShortcuts() {
        shortcutsManager.onQuickPaste = { [weak self] in
            Task { @MainActor in self?.showQuickPaste() }
        }
        shortcutsManager.onTogglePause = { [weak self] in
            Task { @MainActor in self?.togglePause() }
        }
        shortcutsManager.registerShortcuts()
    }

    func showQuickPaste() {
        // Показать quick paste окно
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            monitor.stopMonitoring()
        } else {
            monitor.startMonitoring()
        }
    }

    // MARK: - CRUD

    func loadItems() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { !$0.isDeleted }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            items = try context.fetch(descriptor)
            NSLog("ClipStack: Loaded \(items.count) items")
            applyFilters()
            NSLog("ClipStack: Filtered \(filteredItems.count) items")
        } catch { NSLog("ClipStack: Failed to load: \(error)") }
    }

    func saveItem(_ item: ClipboardItem) {
        guard let context = modelContext else { return }
        let sub = SubscriptionManager.shared
        if !sub.isPro && !sub.isInTrial && items.count >= 100 { sub.showingPaywall = true; return }
        let hash = item.contentHash
        let existing = try? context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.contentHash == hash && !$0.isDeleted })).first
        if let existing { existing.updatedAt = Date(); try? context.save(); loadItems(); return }
        context.insert(item)
        try? context.save()
        StatisticsTracker.shared.recordCopy(from: item.sourceApp)
        loadItems()

        // CloudKit sync
        Task { try? await syncManager.saveItem(item) }
    }

    func deleteItem(_ item: ClipboardItem) {
        guard let context = modelContext else { return }
        item.isDeleted = true; try? context.save(); loadItems()
        Task { try? await syncManager.deleteItem(withID: item.id) }
    }

    func toggleFavorite(_ item: ClipboardItem) {
        guard let context = modelContext else { return }
        item.isFavorite.toggle(); try? context.save(); loadItems()
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if item.type == .image, let imageData = item.imageData, let image = NSImage(data: imageData) {
            pasteboard.writeObjects([image])
        } else if let text = item.text { pasteboard.setString(text, forType: .string) }
        StatisticsTracker.shared.recordPaste()
    }

    // MARK: - Search (AI-powered)

    func applyFilters() {
        var result = items

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                if item.text?.lowercased().contains(query) == true { return true }
                if item.url?.lowercased().contains(query) == true { return true }
                if item.tags.contains(where: { $0.lowercased().contains(query) }) { return true }
                if item.category.lowercased().contains(query) { return true }
                if item.entities.contains(where: { $0.value.lowercased().contains(query) }) { return true }
                if item.extractedText?.lowercased().contains(query) == true { return true }
                if item.detectedLanguage?.lowercased().contains(query) == true { return true }
                return false
            }
        }

        if let filter = selectedFilter { result = result.filter { $0.type == filter } }

        NSLog("ClipStack applyFilters: items=\(items.count) result=\(result.count) sidebar=\(selectedSidebarItem)")

        switch selectedSidebarItem {
        case .history: filteredItems = result
        case .favorites: filteredItems = result.filter { $0.isFavorite }
        case .pinboard(let uuid, _): filteredItems = result.filter { $0.pinboard?.id == uuid }
        case .pasteStack: filteredItems = pasteStackManager.stackItems
        case .statistics, .themes: filteredItems = []
        }

        NSLog("ClipStack applyFilters: filteredItems=\(filteredItems.count)")
    }

    // MARK: - Sync

    func syncWithCloud() async {
        isSyncing = true
        defer { isSyncing = false }
        try? await syncManager.sync(localItems: items)
        loadItems()
    }

    // MARK: - Export

    func exportItems(format: ExportFormat) -> Data? {
        switch format {
        case .json: return ExportManager.exportToJSON(items: items)
        case .csv: return ExportManager.exportToCSV(items: items).data(using: .utf8)
        case .markdown: return ExportManager.exportToMarkdown(items: items).data(using: .utf8)
        case .html: return ExportManager.exportToHTML(items: items).data(using: .utf8)
        }
    }
}

enum SidebarItem: Hashable, Identifiable {
    case history, favorites, pasteStack, statistics, themes
    case pinboard(UUID, String)

    var id: String {
        switch self {
        case .history: return "history"; case .favorites: return "favorites"
        case .pasteStack: return "pasteStack"; case .statistics: return "statistics"
        case .themes: return "themes"; case .pinboard(let uuid, _): return uuid.uuidString
        }
    }
}

enum ExportFormat { case json, csv, markdown, html }

@Observable
final class StatisticsViewModel {
    var totalCopied = 0; var totalPasted = 0; var dailyCopies = 0
    var topApps: [(app: String, count: Int)] = []; var weeklyStats: [Int] = []

    func load() {
        let t = StatisticsTracker.shared
        totalCopied = t.totalCopied; totalPasted = t.totalPasted; dailyCopies = t.dailyCopies
        topApps = t.getTopApps(); weeklyStats = t.getWeeklyStats()
    }
}
