import AppKit
import Foundation
import Observation

/// Keeps the local history and the user's private iCloud database in step.
///
/// Sync used to exist only as a button in Settings, which is not sync — a second
/// Mac only caught up if you remembered to press it. This runs on launch, when
/// the app comes forward, on a timer, and shortly after anything is captured or
/// deleted locally.
@MainActor
@Observable
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    enum Status: Equatable {
        case idle
        case syncing
        case synced(Date)
        case unavailable(String)
        case failed(String)

        var message: String? {
            switch self {
            case .idle: return nil
            case .syncing: return "Syncing…"
            case .synced(let date):
                return "Last synced \(date.formatted(date: .omitted, time: .shortened))."
            case .unavailable(let reason), .failed(let reason): return reason
            }
        }
    }

    private(set) var status: Status = .idle

    private let store = ClipboardStore.shared
    private let manager = CloudKitSyncManager.shared

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var pendingPush: Task<Void, Never>?
    @ObservationIgnored private var isRunning = false

    /// How often a foregrounded app checks for clips from other devices.
    private let pollInterval: TimeInterval = 300

    private init() {}

    var isEnabled: Bool {
        AppSettings.shared.iCloudSync && SubscriptionManager.shared.checkAccess(for: .cloudSync)
    }

    // MARK: - Lifecycle

    func start() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.syncIfDue() }
        }

        let timer = Timer(timeInterval: pollInterval, repeats: true) { _ in
            Task { @MainActor in self.syncIfDue() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        Task { await syncNow(userInitiated: false) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pendingPush?.cancel()
    }

    /// Called when the user turns sync on, so the first exchange is immediate.
    func settingsChanged() {
        guard isEnabled else {
            status = .idle
            return
        }
        Task { await syncNow(userInitiated: true) }
    }

    // MARK: - Triggers

    /// A clip was captured or removed locally; push it shortly afterwards.
    /// Debounced, because copying a handful of things in a row is normal and
    /// each one does not deserve its own round trip.
    func localHistoryChanged() {
        guard isEnabled else { return }
        pendingPush?.cancel()
        pendingPush = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await self?.syncNow(userInitiated: false)
        }
    }

    private func syncIfDue() {
        guard isEnabled else { return }
        if case .synced(let last) = status, Date().timeIntervalSince(last) < 60 { return }
        Task { await syncNow(userInitiated: false) }
    }

    // MARK: - The exchange

    func syncNow(userInitiated: Bool) async {
        guard isEnabled else {
            if userInitiated {
                status = .unavailable("Turn on iCloud sync in Settings first.")
            }
            return
        }
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        status = .syncing

        let payload = store.items.map(CloudClip.init)
        let deletions = DeletionLog.pending()

        let result = await manager.sync(localItems: payload, deletedHashes: deletions)

        switch result {
        case .success(let incoming):
            for clip in incoming {
                store.insert(clip, origin: .remote)
            }
            DeletionLog.clear(deletions)
            status = .synced(Date())
        case .failure(let message):
            // A missing account or no network is a state to report, not an error
            // to keep retrying loudly.
            status = .failed(message)
        }
    }
}

/// Records clips deleted locally so the deletion can be replayed to iCloud, and
/// so a clip deleted here does not simply come back on the next pull.
enum DeletionLog {
    private static let key = "sync_deleted_hashes"
    /// Deletions stay on the list long enough for every device to see them.
    private static let retention: TimeInterval = 60 * 60 * 24 * 30

    static func record(_ contentHash: String) {
        var log = stored()
        log[contentHash] = Date().timeIntervalSince1970
        save(log)
    }

    static func pending() -> [String] {
        Array(stored().keys)
    }

    /// True when a clip arriving from iCloud was deleted here on purpose.
    static func contains(_ contentHash: String) -> Bool {
        stored()[contentHash] != nil
    }

    /// The user copied this again, so the deletion no longer applies.
    static func forget(_ contentHash: String) {
        var log = stored()
        guard log.removeValue(forKey: contentHash) != nil else { return }
        save(log)
    }

    static func clear(_ hashes: [String]) {
        // Keep the entries: another device may not have synced yet. Only drop
        // the ones that have aged out.
        var log = stored()
        let cutoff = Date().timeIntervalSince1970 - retention
        log = log.filter { $0.value > cutoff }
        save(log)
    }

    private static func stored() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
    }

    private static func save(_ log: [String: TimeInterval]) {
        UserDefaults.standard.set(log, forKey: key)
    }
}
