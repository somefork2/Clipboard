import AppKit
import FinderSync
import Foundation

/// Adds CopyWell to the top level of Finder's right-click menu.
///
/// Services appear two levels deep and ship switched off; a Finder extension is
/// the only way to sit in the menu itself. It can only speak to the main app
/// through a URL, because an extension runs in its own sandbox and cannot reach
/// the app's database.
final class FinderMenu: FIFinderSync {

    override init() {
        super.init()
        // Without a monitored directory the extension is never asked for a menu.
        // The whole file system is the honest answer for a clipboard tool.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "CopyWell")
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return menu
        }

        let root = NSMenuItem(title: "CopyWell", action: nil, keyEquivalent: "")
        root.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: nil)

        let submenu = NSMenu(title: "CopyWell")
        submenu.addItem(item("Save to CopyWell", #selector(saveToCopyWell(_:))))
        submenu.addItem(item("Copy Path", #selector(copyPath(_:))))
        submenu.addItem(item("Copy Text Contents", #selector(copyContents(_:))))
        submenu.addItem(.separator())
        submenu.addItem(item("Open CopyWell", #selector(openApp(_:))))

        root.submenu = submenu
        menu.addItem(root)
        return menu
    }

    // MARK: - Actions

    /// Hands the selection to the main app through its URL scheme. The extension
    /// cannot write to the app's store itself.
    @objc func saveToCopyWell(_ sender: AnyObject?) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }

        var components = URLComponents()
        components.scheme = "copywell"
        components.host = "save"
        components.queryItems = urls.map { URLQueryItem(name: "path", value: $0.path) }
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func copyPath(_ sender: AnyObject?) {
        let paths = selectedURLs().map(\.path)
        guard !paths.isEmpty else { return }
        write(paths.joined(separator: "\n"))
    }

    /// Reads the file only when it is plain text; anything else is skipped
    /// rather than pasted as mojibake.
    @objc func copyContents(_ sender: AnyObject?) {
        let texts = selectedURLs().compactMap { try? String(contentsOf: $0, encoding: .utf8) }
        guard !texts.isEmpty else { return }
        write(texts.joined(separator: "\n\n"))
    }

    @objc func openApp(_ sender: AnyObject?) {
        guard let url = URL(string: "copywell://open") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Helpers

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    private func selectedURLs() -> [URL] {
        let controller = FIFinderSyncController.default()
        if let items = controller.selectedItemURLs(), !items.isEmpty { return items }
        if let container = controller.targetedURL() { return [container] }
        return []
    }

    private func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
