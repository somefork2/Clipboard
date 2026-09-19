#if DEBUG
import AppKit
import SwiftUI

/// Renders the app's real windows to PNG files for the App Store listing.
///
/// `cacheDisplay(in:to:)` draws a window's own view hierarchy from inside the
/// process. Unlike `ImageRenderer` it draws AppKit-backed views — the clip
/// list, the search field, materials — which is most of what these screens are,
/// and unlike a screen capture it needs no Screen Recording permission and does
/// not care which Space anything is on. Windows are placed far off-screen so
/// nothing flashes on the display while this runs.
@MainActor
enum ScreenshotRenderer {
    static var isActive: Bool { CommandLine.arguments.contains("--render-screenshots") }

    private static var outputDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Screenshots", isDirectory: true)
    }

    static func run() {
        guard let directory = outputDirectory else { exit(2) }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let store = ClipboardStore.shared
        let subscriptions = SubscriptionManager.shared
        let locked = CommandLine.arguments.contains("--locked")
        subscriptions.simulatedPro = !locked
        subscriptions.forcedLock = locked
        let settings = AppSettings.shared
        settings.hasCompletedOnboarding = true
        let coordinator = AppCoordinator.shared

        func dressed<V: View>(_ view: V) -> AnyView {
            AnyView(
                view
                    .environment(store)
                    .environment(subscriptions)
                    .environment(settings)
                    .environment(coordinator)
                    .tint(ThemeManager.shared.accentColor)
                    // Off-screen windows never become key, and SwiftUI would
                    // draw every label in its dimmed inactive state.
                    .environment(\.controlActiveState, .key)
            )
        }

        // The two panes of the main window are captured separately and placed
        // side by side by the composer. `NavigationSplitView` puts its sidebar
        // in a visual-effect view, which `cacheDisplay` draws as blank white —
        // the panes themselves draw perfectly.
        let shots: [(String, CGSize, Bool, AnyView)] = [
            ("sidebar", CGSize(width: 232, height: 700), false,
             dressed(SidebarView(selection: .constant(.history)).background(Theme.secondaryBackground))),
            ("list", CGSize(width: 948, height: 700), false,
             dressed(ClipboardListView(items: store.items, searchText: "", typeFilter: .constant(nil))
                .background(Theme.background))),
            ("palette", CGSize(width: 460, height: 540), false,
             dressed(QuickPasteView(onSelect: { _, _ in }, onDismiss: {}).background(Theme.background))),
            ("menubar", CGSize(width: 340, height: 460), false,
             dressed(MenuBarContentView().background(Theme.background))),
            ("statistics", CGSize(width: 980, height: 660), true,
             dressed(StatisticsView().background(Theme.background))),
            ("wizard", CGSize(width: 660, height: 600), false, dressed(SetupWizard(onFinish: {}))),
            ("paywall", CGSize(width: 460, height: 660), false, dressed(PaywallView())),
            ("wall", CGSize(width: 900, height: 620), false, dressed(SubscriptionWallView())),
        ]

        for (theme, name, look) in [(AppTheme.light, "light", NSAppearance.Name.aqua),
                                    (AppTheme.dark, "dark", NSAppearance.Name.darkAqua)] {
            ThemeManager.shared.currentTheme = theme
            ThemeManager.shared.applyStoredTheme()
            let appearance = NSAppearance(named: look)
            for (key, size, titled, view) in shots {
                capture(view, size: size, titled: titled, appearance: appearance,
                        to: directory.appendingPathComponent("\(key)-\(name).png"))
            }
        }

        print("rendered to \(directory.path)")
        exit(0)
    }

    private static func capture(_ view: AnyView, size: CGSize, titled: Bool, appearance: NSAppearance?, to url: URL) {
        let style: NSWindow.StyleMask = titled
            ? [.titled, .closable, .miniaturizable, .fullSizeContentView]
            : [.borderless]
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: view)
        window.appearance = appearance
        window.title = "CopyWell"
        window.setContentSize(size)
        // Far off the left edge of any real display, so the user never sees it.
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFront(nil)

        // Let SwiftUI lay out, and let any asynchronous work the views kick off
        // on appear settle before the pixels are taken.
        spin(for: 1.5)
        window.contentView?.layoutSubtreeIfNeeded()
        spin(for: 0.6)
        window.displayIfNeeded()

        guard let content = window.contentView else { return }
        let bounds = content.bounds
        guard let rep = content.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        rep.size = bounds.size
        content.cacheDisplay(in: bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try png.write(to: url)
            print("  \(url.lastPathComponent) \(rep.pixelsWide)×\(rep.pixelsHigh)")
        } catch {
            FileHandle.standardError.write(Data("could not write \(url.path): \(error)\n".utf8))
        }
        window.orderOut(nil)
    }

    private static func spin(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }
}
#endif
