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

    /// Prints the real window's geometry.
    ///
    /// A toolbar overlapping the content is invisible to the offscreen renderer,
    /// which draws views without any window chrome. This asks the running window
    /// what it actually looks like.
    static var isDiagnosing: Bool { CommandLine.arguments.contains("--diagnose-layout") }

    /// Opens Settings the way the menu bar button does and reports the result.
    static var isDiagnosingSettings: Bool { CommandLine.arguments.contains("--diagnose-settings") }

    /// Toggles the sidebar and reports whether the main thread kept running.
    static var isDiagnosingSidebar: Bool { CommandLine.arguments.contains("--diagnose-sidebar") }

    /// Clicks the real sidebar toggle. It is a SwiftUI-managed toolbar item
    /// with no action of its own, so the button has to be found and pressed.
    @MainActor
    private static func clickSidebarToggle() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible }),
              let item = window.toolbar?.items.first(where: {
                  $0.itemIdentifier.rawValue.contains("toggleSidebar")
              })
        else { print("  (no sidebar toggle found)"); return }

        func button(in view: NSView) -> NSButton? {
            if let b = view as? NSButton { return b }
            for sub in view.subviews { if let b = button(in: sub) { return b } }
            return nil
        }
        if let view = item.view, let b = button(in: view) {
            b.performClick(nil)
            return
        }
        // SwiftUI items expose no `view`; the button lives in the titlebar.
        if let themeFrame = window.contentView?.superview {
            for sub in themeFrame.subviews where sub.className.contains("Titlebar") || sub.className.contains("Toolbar") {
                if let b = button(in: sub) { b.performClick(nil); return }
            }
        }
        print("  (sidebar toggle button not reachable)")
    }

    static func diagnoseSidebar() {
        // A repeating tick on the main queue. If the main thread blocks, the
        // gap between ticks grows, which is what a hang looks like from inside.
        final class Watch: @unchecked Sendable {
            var last = Date()
            var worst: TimeInterval = 0
        }
        let watch = Watch()
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in
            let now = Date()
            watch.worst = max(watch.worst, now.timeIntervalSince(watch.last))
            watch.last = now
        }
        RunLoop.main.add(timer, forMode: .common)

        func step(_ name: String, after delay: TimeInterval, _ work: @escaping @MainActor () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated {
                    watch.last = Date()
                    work()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        MainActor.assumeIsolated {
                            var widths: [String] = []
                            func find(_ v: NSView) {
                                if let split = v as? NSSplitView {
                                    widths.append(split.arrangedSubviews.map { "\(Int($0.bounds.width))" }.joined(separator: "|"))
                                }
                                for sub in v.subviews { find(sub) }
                            }
                            if let content = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible })?.contentView {
                                find(content)
                            }
                            print("\(name): columns=[\(widths.joined(separator: " , "))] worstGap=\(String(format: "%.2f", watch.worst))s")
                        }
                    }
                }
            }
        }

        step("launch", after: 3) {
            NSApp.activate(ignoringOtherApps: true)
            watch.worst = 0
            if let tb = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible })?.toolbar {
                for item in tb.items {
                    let sel = item.action.map { NSStringFromSelector($0) } ?? "nil"
                    print("  TOOLBAR id=\(item.itemIdentifier.rawValue) action=\(sel) target=\(String(describing: item.target)) label='\(item.label)'")
                }
            }
        }
        step("hide sidebar", after: 4) { clickSidebarToggle() }
        step("show sidebar", after: 7) { clickSidebarToggle() }
        step("hide again", after: 10) { clickSidebarToggle() }
        step("show again", after: 13) { clickSidebarToggle() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 17) {
            MainActor.assumeIsolated {
                let ok = watch.worst < 1.0
                print("RESULT: worst main-thread gap \(String(format: "%.2f", watch.worst))s — \(ok ? "responsive" : "HUNG")")
                exit(ok ? 0 : 1)
            }
        }
    }

    static func diagnoseSettings() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            MainActor.assumeIsolated {
                print("theme=\(ThemeManager.shared.currentTheme.rawValue) wants=\(ThemeManager.shared.palette.appearance?.rawValue ?? "system")")
                let before = NSApp.windows.filter(\.isVisible)
                for w in before {
                    print("  before: '\(w.title)' appearance=\(w.appearance?.name.rawValue ?? "nil (system)")")
                }
                AppCoordinator.shared.openSettingsWindow()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    MainActor.assumeIsolated {
                        let after = NSApp.windows.filter(\.isVisible)
                        for w in after {
                            print("  after:  '\(w.title)' appearance=\(w.appearance?.name.rawValue ?? "nil (system)")")
                        }
                        let opened = after.count > before.count
                        let wanted = ThemeManager.shared.palette.appearance?.rawValue
                        let themed = after
                            .filter { $0.level == .normal }
                            .allSatisfy { $0.appearance?.name.rawValue == wanted }
                        print(opened ? "RESULT: settings window opened" : "RESULT: settings did NOT open")
                        print(themed ? "RESULT: every ordinary window carries the theme appearance"
                                     : "RESULT: some window is NOT themed")
                        exit(opened && themed ? 0 : 1)
                    }
                }
            }
        }
    }

    static func diagnose() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            MainActor.assumeIsolated {
                for window in NSApp.windows where window.canBecomeMain && window.isVisible {
                    print("window            frame            \(window.frame)")
                    print("window            contentLayoutRect \(window.contentLayoutRect)")
                    print("window            styleMask         \(window.styleMask.rawValue)")
                    print("window            titlebarAppears   \(window.titlebarAppearsTransparent)")
                    if let content = window.contentView {
                        print("contentView       bounds            \(content.bounds)")
                        print("contentView       safeAreaInsets    \(content.safeAreaInsets)")
                        let underlap = content.bounds.height - window.contentLayoutRect.height
                        print("=> content extends \(underlap) pt beyond the layout rect")
                        print("=> safe area top is \(content.safeAreaInsets.top) pt")
                    }
                    if let toolbar = window.toolbar {
                        print("toolbar           visible           \(toolbar.isVisible)")
                    }
                    // Anything drawn in the top 60 points of the window is either
                    // the toolbar or something hiding underneath it.
                    if let content = window.contentView {
                        print("--- scroll views in the detail column ---")
                        func scrolls(_ view: NSView) {
                            if let sv = view as? NSScrollView {
                                let f = sv.convert(sv.bounds, to: nil)
                                let top = content.bounds.height - f.maxY
                                print("  \(type(of: sv)) top=\(Int(top)) h=\(Int(sv.bounds.height)) x=\(Int(f.minX)) inset.top=\(sv.contentInsets.top) auto=\(sv.automaticallyAdjustsContentInsets)")
                            }
                            for sub in view.subviews { scrolls(sub) }
                        }
                        scrolls(content)
                        print("--- views intersecting the top 260 pt ---")
                        func walk(_ view: NSView, depth: Int) {
                            let inWindow = view.convert(view.bounds, to: nil)
                            let topOfWindow = content.bounds.height - inWindow.maxY
                            if topOfWindow < 260, view.bounds.height > 8, view.bounds.width > 40 {
                                let pad = String(repeating: "  ", count: depth)
                                print("\(pad)\(type(of: view)) top=\(Int(topOfWindow)) h=\(Int(view.bounds.height)) w=\(Int(view.bounds.width)) x=\(Int(inWindow.minX))")
                            }
                            guard depth < 12 else { return }
                            for sub in view.subviews { walk(sub, depth: depth + 1) }
                        }
                        walk(content, depth: 0)
                    }
                    break
                }
                exit(0)
            }
        }
    }

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
            ("appearance", CGSize(width: 560, height: 420), false,
             dressed(AppearanceSettings().background(Theme.background))),
            // The whole window, tab bar and all: the panes on their own looked
            // right while the chrome around them did not.
            ("settings-window", CGSize(width: 560, height: 620), true,
             dressed(SettingsView())),
            ("settings-general", CGSize(width: 560, height: 560), false,
             dressed(GeneralSettings().background(Theme.background))),
            ("settings-privacy", CGSize(width: 560, height: 520), false,
             dressed(PrivacySettings().background(Theme.background))),
            // Sized to nothing on purpose: `.zero` means "ask the view how tall
            // it wants to be", which is what MenuBarExtra does. Forcing a size
            // here is exactly what hid the popover's footer being pushed out.
            ("menubar-natural", .zero, false,
             dressed(SubscriptionGate { MenuBarContentView() }.frame(minWidth: 320, minHeight: 280))),
        ]

        // `--all-themes` renders every theme, which is how a theme that only
        // half-applies gets noticed: the custom palettes are the ones where a
        // stray system colour shows up.
        let everyTheme = CommandLine.arguments.contains("--all-themes")
        let passes: [(AppTheme, String, NSAppearance.Name?)] = everyTheme
            ? AppTheme.allCases.map { ($0, $0.rawValue, $0.palette.appearance) }
            : [(AppTheme.light, "light", NSAppearance.Name.aqua),
               (AppTheme.dark, "dark", NSAppearance.Name.darkAqua)]

        for (theme, name, look) in passes {
            ThemeManager.shared.currentTheme = theme
            ThemeManager.shared.applyStoredTheme()
            let appearance = look.flatMap { NSAppearance(named: $0) }
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
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        window.appearance = appearance
        window.title = "CopyWell"
        let resolved = size == .zero ? hosting.fittingSize : size
        window.setContentSize(resolved)
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
