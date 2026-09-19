import AppKit
import SwiftUI

@main
struct CopyWellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store = ClipboardStore.shared
    @State private var coordinator = AppCoordinator.shared
    @State private var settings = AppSettings.shared
    @State private var subscriptions = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            SubscriptionGate { MainView() }
                .environment(store)
                .environment(coordinator)
                .environment(settings)
                .environment(subscriptions)
                .tint(ThemeManager.shared.accentColor)
                .dynamicTypeSize(settings.textSize.dynamicTypeSize)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 980, height: 640)
        .commands { CopyWellCommands() }

        MenuBarExtra("CopyWell", systemImage: coordinator.isPaused ? "clipboard" : "clipboard.fill", isInserted: menuBarBinding) {
            SubscriptionGate { MenuBarContentView() }
                .frame(minWidth: 320, minHeight: 280)
                .environment(store)
                .environment(coordinator)
                .environment(subscriptions)
                .tint(ThemeManager.shared.accentColor)
                .dynamicTypeSize(settings.textSize.dynamicTypeSize)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
                .environment(coordinator)
                .environment(settings)
                .environment(subscriptions)
                .tint(ThemeManager.shared.accentColor)
                .dynamicTypeSize(settings.textSize.dynamicTypeSize)
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
struct CopyWellCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("CopyWell Pro…") { SubscriptionManager.shared.showingPaywall = true }
        }
        CommandGroup(replacing: .help) {
            Button("CopyWell Setup Guide") {
                AppCoordinator.shared.showSetupGuide()
            }
            Divider()
            Link("Support", destination: LegalLinks.support)
            Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
        }
        CommandMenu("Clipboard") {
            Button("Open Palette") { QuickPastePanel.shared.toggle() }
                .keyboardShortcut("v", modifiers: [.option, .command])
            Button("Quick Look") {
                NotificationCenter.default.post(name: .copyWellRequestPreviewSelection, object: nil)
            }
            .keyboardShortcut("y", modifiers: .command)
            Divider()
            Button(AppCoordinator.shared.isPaused ? "Resume Recording" : "Pause Recording") {
                AppCoordinator.shared.togglePause()
            }
            .keyboardShortcut("p", modifiers: [.control, .option])
            Divider()
            Button("Clear History…") {
                NotificationCenter.default.post(name: .copyWellRequestClearHistory, object: nil)
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
            #if DEBUG
            if ScreenshotRenderer.isActive { ScreenshotRenderer.run() }
            #endif
        }

        observeWindowPrivacy()
    }

    /// Handles `copywell://save?path=…` and `copywell://open` from the Finder
    /// extension. Paths arrive from a user's right-click on files they selected,
    /// which is what grants us access to them.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "copywell" else { continue }
            switch url.host {
            case "open":
                MainActor.assumeIsolated { AppCoordinator.shared.openMainWindow() }
            case "save":
                let paths = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .filter { $0.name == "path" }
                    .compactMap(\.value) ?? []
                MainActor.assumeIsolated { Self.ingest(paths: paths) }
            default:
                break
            }
        }
    }

    @MainActor
    private static func ingest(paths: [String]) {
        for path in paths {
            let fileURL = URL(fileURLWithPath: path)
            Task {
                if let image = NSImage(contentsOf: fileURL),
                   let clip = await ClipboardMonitor.makeClip(
                        image: image,
                        sourceApp: "Finder",
                        sourceBundleID: "com.apple.finder"
                   ) {
                    ClipboardStore.shared.insert(clip)
                    return
                }
                let body = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? fileURL.path
                if let clip = await ClipboardMonitor.makeClip(
                    text: body,
                    sourceApp: "Finder",
                    sourceBundleID: "com.apple.finder"
                ) {
                    ClipboardStore.shared.insert(clip)
                }
            }
        }
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
            forName: .copyWellWindowPrivacyChanged,
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

    /// When enabled, CopyWell's windows are excluded from screen recordings and
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
    static let copyWellRequestClearHistory = Notification.Name("copyWellRequestClearHistory")
    /// Menu-driven Quick Look: a menu item is both a reliable key handler and a
    /// discoverable one, unlike a hidden button holding a shortcut.
    static let copyWellRequestPreviewSelection = Notification.Name("copyWellRequestPreviewSelection")
    /// Reopens the first-run guide from Settings.
    static let copyWellRequestSetupWizard = Notification.Name("copyWellRequestSetupWizard")
}
