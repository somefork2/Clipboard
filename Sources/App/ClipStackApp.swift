import AppKit
import SwiftUI

@main
struct ClipStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store = ClipboardStore.shared
    @State private var coordinator = AppCoordinator.shared
    @State private var settings = AppSettings.shared
    @State private var subscriptions = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environment(store)
                .environment(coordinator)
                .environment(settings)
                .environment(subscriptions)
                .tint(ThemeManager.shared.accentColor)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 980, height: 640)
        .commands { ClipStackCommands() }

        MenuBarExtra("ClipStack", systemImage: coordinator.isPaused ? "clipboard" : "clipboard.fill", isInserted: menuBarBinding) {
            MenuBarContentView()
                .environment(store)
                .environment(coordinator)
                .environment(subscriptions)
                .tint(ThemeManager.shared.accentColor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
                .environment(coordinator)
                .environment(settings)
                .environment(subscriptions)
                .tint(ThemeManager.shared.accentColor)
        }
    }

    private var menuBarBinding: Binding<Bool> {
        Binding(
            get: { settings.showInMenuBar },
            set: { settings.showInMenuBar = $0 }
        )
    }
}

/// App menu additions, so every shortcut is discoverable from the menu bar and
/// not only from a settings screen.
struct ClipStackCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("ClipStack Pro…") { SubscriptionManager.shared.showingPaywall = true }
        }
        CommandMenu("Clipboard") {
            Button("Open Palette") { QuickPastePanel.shared.toggle() }
                .keyboardShortcut("v", modifiers: [.option, .command])
            Button("Quick Look") {
                NotificationCenter.default.post(name: .clipStackRequestPreviewSelection, object: nil)
            }
            .keyboardShortcut("y", modifiers: .command)
            Divider()
            Button(AppCoordinator.shared.isPaused ? "Resume Recording" : "Pause Recording") {
                AppCoordinator.shared.togglePause()
            }
            .keyboardShortcut("p", modifiers: [.control, .option])
            Divider()
            Button("Clear History…") {
                NotificationCenter.default.post(name: .clipStackRequestClearHistory, object: nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = ServiceProvider()
        NSUpdateDynamicServices()

        MainActor.assumeIsolated {
            AppCoordinator.shared.start()
            ThemeManager.shared.applyStoredTheme()
        }

        observeWindowPrivacy()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppCoordinator.shared.stop()
            ClipboardStore.shared.save()
        }
    }

    /// Keeping the app alive without windows is the point: the menu bar item and
    /// the global shortcuts must keep working.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainActor.assumeIsolated { AppCoordinator.shared.openMainWindow() }
        }
        return true
    }

    // MARK: - Screen capture privacy

    private func observeWindowPrivacy() {
        applyWindowPrivacy()
        NotificationCenter.default.addObserver(
            forName: .clipStackWindowPrivacyChanged,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { AppDelegate.applyPrivacyToAllWindows() }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AppDelegate.applyPrivacyToAllWindows()
                // A window created after the theme was chosen still has AppKit's
                // default backdrop until it is told otherwise.
                ThemeManager.shared.applyStoredTheme()
            }
        }
    }

    private func applyWindowPrivacy() {
        MainActor.assumeIsolated { AppDelegate.applyPrivacyToAllWindows() }
    }

    /// When enabled, ClipStack's windows are excluded from screen recordings and
    /// screenshots — a clipboard manager shows exactly the things you do not want
    /// captured during a screen share.
    @MainActor
    static func applyPrivacyToAllWindows() {
        let hide = AppSettings.shared.hideFromScreenCapture
        for window in NSApp.windows {
            window.sharingType = hide ? .none : .readOnly
        }
    }
}

extension Notification.Name {
    static let clipStackRequestClearHistory = Notification.Name("clipStackRequestClearHistory")
    /// Menu-driven Quick Look: a menu item is both a reliable key handler and a
    /// discoverable one, unlike a hidden button holding a shortcut.
    static let clipStackRequestPreviewSelection = Notification.Name("clipStackRequestPreviewSelection")
}
