import AppKit
import Foundation
import Observation
import SwiftData

/// Owns the one and only `ModelContainer` for the app.
///
/// The container used to be created inside `MainView.onAppear`, so every window
/// (and the Settings scene) got a separate database handle and the views drifted
/// out of sync. There is exactly one store, created once, shared everywhere.
@MainActor
@Observable
final class ClipboardStore {
    static let shared = ClipboardStore()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private(set) var items: [ClipboardItem] = []
    private(set) var pinboards: [Pinboard] = []
    /// Set when the store could not be opened; surfaced in the UI instead of a silent no-op.
    private(set) var loadError: String?

    private init() {
        let schema = Schema([ClipboardItem.self, Pinboard.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt or incompatible store must not take the app down; fall back
            // to memory so the user can still use and export the session.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [memory])
        }
        reload()
    }

    // MARK: - Reading

    func reload() {
        do {
            items = try context.fetch(
                FetchDescriptor<ClipboardItem>(
                    predicate: #Predicate { !$0.isTrashed },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            )
            pinboards = try context.fetch(
                FetchDescriptor<Pinboard>(sortBy: [SortDescriptor(\.sortOrder)])
            )
            loadError = nil
        } catch {
            loadError = "Could not read the clipboard history."
        }
        NotificationCenter.default.post(name: .clipStackHistoryChanged, object: nil)
    }

    /// The most recent clips, for the menu bar and the palette.
    func recent(limit: Int) -> [ClipboardItem] {
        Array(items.prefix(limit))
    }

    // MARK: - Writing

    /// Inserts a captured clip, or refreshes the existing one with the same content.
    @discardableResult
    func insert(_ clip: CapturedClip) -> ClipboardItem? {
        let hash = clip.contentHash
        let existing = try? context.fetch(
            FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.contentHash == hash })
        ).first

        if let existing {
            // Re-copying something already in history moves it back to the top
            // instead of creating a duplicate.
            existing.updatedAt = Date()
            existing.createdAt = Date()
            existing.isTrashed = false
            save()
            reload()
            return existing
        }

        let item = ClipboardItem(
            contentType: clip.contentType,
            contentHash: clip.contentHash,
            text: nil,
            imageFileName: clip.imageFileName,
            url: clip.url,
            sourceApp: clip.sourceApp,
            sourceAppBundleId: clip.sourceAppBundleId,
            isSensitive: clip.isSensitive
        )
        item.setBody(clip.text)
        item.urlTitle = clip.urlTitle
        item.imageThumbnail = clip.imageThumbnail
        item.extractedText = clip.extractedText
        item.category = clip.category
        item.tags = clip.tags
        item.detectedLanguage = clip.detectedLanguage
        item.sentiment = clip.sentiment
        item.aiConfidence = clip.confidence
        item.entities = clip.entities

        context.insert(item)
        save()
        StatisticsTracker.shared.recordCopy(from: clip.sourceApp)
        enforceLimits()
        reload()
        return item
    }

    func toggleFavorite(_ item: ClipboardItem) {
        item.isFavorite.toggle()
        item.updatedAt = Date()
        save()
        reload()
    }

    func recordUse(_ item: ClipboardItem) {
        item.useCount += 1
        item.updatedAt = Date()
        save()
    }

    func assign(_ item: ClipboardItem, to pinboard: Pinboard?) {
        item.pinboard = pinboard
        item.updatedAt = Date()
        save()
        reload()
    }

    /// Permanently removes a clip and its image file. "Delete" means delete.
    func delete(_ item: ClipboardItem) {
        if let fileName = item.imageFileName {
            ImageStore.remove(fileName: fileName)
        }
        context.delete(item)
        save()
        reload()
    }

    func delete(_ itemsToDelete: [ClipboardItem]) {
        for item in itemsToDelete {
            if let fileName = item.imageFileName { ImageStore.remove(fileName: fileName) }
            context.delete(item)
        }
        save()
        reload()
    }

    func deleteAll(fromApp app: String) {
        delete(items.filter { $0.sourceApp == app })
    }

    func clearHistory(keepingFavorites: Bool) {
        delete(items.filter { keepingFavorites ? !$0.isFavorite : true })
    }

    // MARK: - Pinboards

    @discardableResult
    func createPinboard(name: String, icon: String = "pin", color: String = "blue") -> Pinboard? {
        let limit = SubscriptionManager.shared.pinboardLimit
        if limit >= 0 && pinboards.count >= limit {
            SubscriptionManager.shared.requestAccess(for: .unlimitedPinboards)
            return nil
        }
        let board = Pinboard(name: name, icon: icon, color: color)
        board.sortOrder = pinboards.count
        context.insert(board)
        save()
        reload()
        return board
    }

    func deletePinboard(_ board: Pinboard) {
        for item in board.items { item.pinboard = nil }
        context.delete(board)
        save()
        reload()
    }

    // MARK: - Retention

    /// Applies the free-tier cap, the user's history cap and the age-based cleanup.
    func enforceLimits() {
        let settings = AppSettings.shared
        var doomed: [ClipboardItem] = []

        let live = (try? context.fetch(
            FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []

        // Age-based cleanup (Pro).
        if settings.autoCleanupDays > 0, SubscriptionManager.shared.checkAccess(for: .autoCleanup) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -settings.autoCleanupDays, to: Date()) ?? .distantPast
            doomed += live.filter { !$0.isFavorite && $0.pinboard == nil && $0.createdAt < cutoff }
        }

        // Hard cap: the free tier keeps the 100 most recent clips. We keep
        // recording and drop the oldest rather than blocking capture and
        // throwing a paywall at every copy.
        let subscriptionLimit = SubscriptionManager.shared.historyLimit
        let userLimit = settings.maxHistoryItems > 0 ? settings.maxHistoryItems : Int.max
        let effectiveLimit = subscriptionLimit < 0 ? userLimit : min(subscriptionLimit, userLimit)

        if effectiveLimit != Int.max {
            let doomedIDs = Set(doomed.map(\.persistentModelID))
            let keepable = live.filter { item in
                !item.isFavorite && item.pinboard == nil && !doomedIDs.contains(item.persistentModelID)
            }
            if keepable.count > effectiveLimit {
                doomed += keepable.dropFirst(effectiveLimit)
            }
        }

        guard !doomed.isEmpty else { return }
        for item in doomed {
            if let fileName = item.imageFileName { ImageStore.remove(fileName: fileName) }
            context.delete(item)
        }
        save()
    }

    /// Deletes image files left behind by clips that no longer exist.
    func pruneOrphanedImages() {
        let live = (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        ImageStore.pruneOrphans(keeping: Set(live.compactMap(\.imageFileName)))
    }

    // MARK: - Persistence

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            loadError = "Could not save the last change."
        }
    }
}
