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
        var fallbackNotice: String?
        let schema = Schema([ClipboardItem.self, Pinboard.self])

        #if DEBUG
        // Screenshot runs must never touch, or show, the real history.
        if DemoContent.isActive {
            let demo = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            container = try! ModelContainer(for: schema, configurations: [demo])
            DemoContent.seed(into: container.mainContext)
            reload()
            return
        }
        #endif

        // `.none` is deliberate. The iCloud entitlement makes SwiftData's default
        // `.automatic` switch CloudKit mirroring on, which then refuses to open
        // the store at all because mirroring requires every attribute to be
        // optional or defaulted. Sync is ours: `CloudKitSyncManager` owns its own
        // record zone, so SwiftData must stay a purely local store.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        let memory = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt or incompatible store must not take the app down; fall back
            // to memory so the user can still use and export the session.
            do {
                container = try ModelContainer(for: schema, configurations: [memory])
                fallbackNotice = String(localized: "The saved history could not be opened. This session is being kept in memory only.")
            } catch {
                // Nothing left to fall back to, but crashing on launch is never the
                // answer: an empty in-memory schema still gives a usable window.
                container = try! ModelContainer(
                    for: Schema([]),
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
                fallbackNotice = String(localized: "Clipboard history is unavailable on this Mac.")
            }
        }
        reload()
        // `reload()` clears `loadError` when the fetch works, and against an empty
        // in-memory store it always does — so the notice goes on afterwards.
        if let fallbackNotice { loadError = fallbackNotice }
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
            loadError = String(localized: "Could not read the clipboard history.")
        }
        NotificationCenter.default.post(name: .copyWellHistoryChanged, object: nil)
    }

    /// The most recent clips, for the menu bar and the palette.
    func recent(limit: Int) -> [ClipboardItem] {
        Array(items.prefix(limit))
    }

    // MARK: - Writing

    /// Inserts a captured clip, or refreshes the existing one with the same content.
    /// Where a clip came from. It decides whether a past deletion should block
    /// it: copying something again is an explicit act and must always be
    /// recorded, while the same clip arriving from iCloud is just a device that
    /// has not caught up with the deletion yet.
    enum Origin {
        case local
        case remote
    }

    @discardableResult
    func insert(_ clip: CapturedClip, origin: Origin = .local) -> ClipboardItem? {
        let hash = clip.contentHash
        if origin == .remote, DeletionLog.contains(hash) { return nil }
        if origin == .local { DeletionLog.forget(hash) }
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
        item.richTextData = clip.richTextData
        item.pixelWidth = clip.pixelWidth
        item.pixelHeight = clip.pixelHeight
        item.imageByteSize = clip.imageByteSize
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
        if origin == .local { SoundPlayer.play(.captured) }
        enforceLimits()
        reload()
        SyncCoordinator.shared.localHistoryChanged()
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
        delete([item])
    }

    func delete(_ itemsToDelete: [ClipboardItem]) {
        for item in itemsToDelete {
            if let fileName = item.imageFileName { ImageStore.remove(fileName: fileName) }
            // Remember the deletion so iCloud replays it instead of handing the
            // clip back on the next pull.
            if !item.isSensitive { DeletionLog.record(item.contentHash) }
            context.delete(item)
        }
        save()
        reload()
        SyncCoordinator.shared.localHistoryChanged()
    }

    /// Applies a deletion that arrived from another device. It deliberately does
    /// not go through `delete`, which would log the deletion again and push it
    /// straight back to iCloud.
    func deleteFromRemote(contentHashes: [String]) {
        let wanted = Set(contentHashes)
        let doomed = items.filter { wanted.contains(ContentHasher.recordName(for: $0.contentHash)) || wanted.contains($0.contentHash) }
        guard !doomed.isEmpty else { return }
        for item in doomed {
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

    func rename(_ board: Pinboard, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        board.name = trimmed
        board.updatedAt = Date()
        save()
        reload()
    }

    func update(_ board: Pinboard, icon: String, color: String) {
        board.icon = icon
        board.color = color
        board.updatedAt = Date()
        save()
        reload()
    }

    /// Reorders the sidebar. `sortOrder` is rewritten for every board so the
    /// order is stable rather than dependent on insertion time.
    func movePinboards(from source: IndexSet, to destination: Int) {
        var ordered = pinboards
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, board) in ordered.enumerated() {
            board.sortOrder = index
        }
        save()
        reload()
    }

    func deletePinboard(_ board: Pinboard) {
        for item in board.items { item.pinboard = nil }
        context.delete(board)
        save()
        reload()
    }

    // MARK: - Retention

    /// Applies the retention policy, and the free tier's age window on top of it.
    ///
    /// Favourites and anything filed on a pinboard are never removed: those are
    /// the clips the user deliberately kept.
    func enforceLimits() {
        let live = (try? context.fetch(
            FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []

        let keepable = live.filter { !$0.isFavorite && $0.pinboard == nil }
        var doomed: [ClipboardItem] = []

        let subscriptions = SubscriptionManager.shared
        if subscriptions.checkAccess(for: .autoCleanup) {
            switch AppSettings.shared.retention {
            case .count(let limit):
                if keepable.count > limit {
                    doomed += keepable.dropFirst(limit)
                }
            case .days(let days):
                let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
                doomed += keepable.filter { $0.createdAt < cutoff }
            case .forever:
                break
            }
        }

        // The free tier keeps a window of recent history rather than a fixed
        // number of clips: nothing is ever refused, old clips simply age out.
        if let window = subscriptions.historyWindow {
            let cutoff = Date().addingTimeInterval(-window)
            let doomedIDs = Set(doomed.map(\.persistentModelID))
            doomed += keepable.filter { $0.createdAt < cutoff && !doomedIDs.contains($0.persistentModelID) }
        }

        guard !doomed.isEmpty else { return }
        for item in doomed {
            if let fileName = item.imageFileName { ImageStore.remove(fileName: fileName) }
            context.delete(item)
        }
        save()
    }

    /// Fills in dimensions and file size for image clips captured before the
    /// app recorded them, so their rows can describe the picture.
    func backfillImageMetadata() {
        let stale = items.filter { $0.type == .image && $0.imageFileName != nil && $0.pixelWidth == 0 }
        guard !stale.isEmpty else { return }

        var changed = false
        for item in stale {
            guard let fileName = item.imageFileName,
                  let data = ImageStore.read(fileName: fileName),
                  let image = NSImage(data: data) else { continue }
            let pixels = ImageStore.pixelSize(of: image)
            item.pixelWidth = Int(pixels.width)
            item.pixelHeight = Int(pixels.height)
            item.imageByteSize = data.count
            if item.imageThumbnail == nil {
                item.imageThumbnail = ImageStore.thumbnail(from: image)
            }
            changed = true
        }

        if changed {
            save()
            reload()
        }
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
            loadError = String(localized: "Could not save the last change.")
        }
    }
}
