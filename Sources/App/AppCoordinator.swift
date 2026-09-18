import AppKit
import Foundation
import Observation

/// Wires global shortcuts, capture and the palette together.
///
/// Lives for the lifetime of the process so hotkeys work whether or not a window
/// is open — a clipboard manager is useless if it only responds while focused.
@MainActor
@Observable
final class AppCoordinator {
    static let shared = AppCoordinator()

    private let monitor = ClipboardMonitor()
    private let store = ClipboardStore.shared
    private let shortcuts = GlobalShortcutsManager.shared

    private(set) var isPaused = false
    /// Non-nil when a shortcut could not be registered because another app owns it.
    private(set) var shortcutConflictMessage: String?

    private init() {}

    func start() {
        StatisticsTracker.shared.resetDailyIfNeeded()
        PasteService.beginTrackingFrontmostApp()
        store.pruneOrphanedImages()
        store.backfillImageMetadata()

        monitor.onClipCaptured = { [weak self] clip in
            self?.store.insert(clip)
        }
        monitor.startMonitoring()

        registerShortcuts()
        SubscriptionManager.shared.start()
        SyncCoordinator.shared.start()
        AppSettings.shared.applyActivationPolicy()
    }

    func stop() {
        monitor.stopMonitoring()
        shortcuts.unregisterAll()
        SyncCoordinator.shared.stop()
    }

    // MARK: - Shortcuts

    private func registerShortcuts() {
        shortcuts.setHandler(for: .quickPaste) { QuickPastePanel.shared.toggle() }
        shortcuts.setHandler(for: .pastePrevious) { [weak self] in self?.pastePrevious() }
        shortcuts.setHandler(for: .pastePlainText) { [weak self] in self?.pastePlainText() }
        shortcuts.setHandler(for: .saveSelection) { [weak self] in self?.saveSelection() }
        shortcuts.setHandler(for: .pinLast) { [weak self] in self?.pinLast() }
        shortcuts.setHandler(for: .togglePause) { [weak self] in self?.togglePause() }
        shortcuts.setHandler(for: .pasteStackNext) { [weak self] in self?.pasteStackNext() }

        shortcuts.registerAll()
        updateConflictMessage()
    }

    func updateConflictMessage() {
        let conflicted = shortcuts.conflicts
        guard !conflicted.isEmpty else {
            shortcutConflictMessage = nil
            return
        }
        let names = conflicted.map(\.title).sorted().joined(separator: ", ")
        shortcutConflictMessage = "Another app already uses the shortcut for: \(names). Pick a different one in Settings ▸ Shortcuts."
    }

    // MARK: - Actions

    func togglePause() {
        isPaused.toggle()
        monitor.setPaused(isPaused)
    }

    /// Pastes the clip before the current one, so ⇧⌘V flips between the last two.
    private func pastePrevious() {
        guard store.items.count > 1 else { return }
        paste(store.items[1], plainText: false)
    }

    private func pastePlainText() {
        guard let item = store.items.first else { return }
        paste(item, plainText: true)
    }

    private func paste(_ item: ClipboardItem, plainText: Bool) {
        guard let content = item.pasteContent else { return }
        PasteService.rememberFrontmostApp()
        store.recordUse(item)
        StatisticsTracker.shared.recordPaste()
        PasteService.paste(content, plainText: plainText)
    }

    /// Captures the selection in the frontmost app without replacing the user's clipboard.
    private func saveSelection() {
        let app = NSWorkspace.shared.frontmostApplication
        PasteService.captureSelection { [weak self] text in
            guard let self, let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            Task { @MainActor in
                guard let clip = await ClipboardMonitor.makeClip(
                    text: text,
                    sourceApp: app?.localizedName,
                    sourceBundleID: app?.bundleIdentifier
                ) else { return }
                self.store.insert(clip)
            }
        }
    }

    private func pinLast() {
        guard let item = store.items.first else { return }
        if !item.isFavorite { store.toggleFavorite(item) }
    }

    private func pasteStackNext() {
        guard SubscriptionManager.shared.requestAccess(for: .pasteStack) else { return }
        guard let item = PasteStackManager.shared.pasteNext() else { return }
        paste(item, plainText: false)
    }

    // MARK: - Windows

    func openMainWindow() {
        NSApp.setActivationPolicy(AppSettings.shared.showInDock ? .regular : .regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window is NSPanel == false {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
