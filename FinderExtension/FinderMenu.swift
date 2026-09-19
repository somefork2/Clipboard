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

    /// Puts the files themselves on the pasteboard.
    ///
    /// The file, not what is inside it: pasted into Finder it copies the file,
    /// into Mail it attaches it. "Copy Text Contents" is the item for the text
    /// inside, and the two are deliberately different.
    ///
    /// It used to send the app a `copywell://save?path=…` URL. The app is
    /// sandboxed and has no right to read a file it was merely told the path of
    /// — measured: `isReadable` false, "Operation not permitted" — and its
    /// fallback quietly stored the path as though it were the contents.
    @objc func saveToCopyWell(_ sender: AnyObject?) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    @objc func copyPath(_ sender: AnyObject?) {
        let paths = selectedURLs().map(\.path)
        guard !paths.isEmpty else { return }
        write(paths.joined(separator: "\n"))
    }

    /// Reads the file as text, whatever encoding it turns out to be in.
    ///
    /// This used to insist on UTF-8 and swallow the error, so a file saved in
    /// UTF-16 or a Windows codepage — or any binary at all — made the menu item
    /// do nothing whatsoever, with no way to tell why.
    @objc func copyContents(_ sender: AnyObject?) {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }

        var texts: [String] = []
        var unreadable: [String] = []
        for url in urls {
            if let text = Self.readText(at: url) {
                texts.append(text)
            } else {
                unreadable.append(url.lastPathComponent)
            }
        }

        guard !texts.isEmpty else {
            report(unreadable: unreadable)
            return
        }
        write(texts.joined(separator: "\n\n"))
    }

    /// Text out of a file, trying the encodings that actually turn up.
    private static func readText(at url: URL) -> String? {
        var detected = String.Encoding.utf8
        if let text = try? String(contentsOf: url, usedEncoding: &detected) { return text }
        for encoding in [String.Encoding.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian,
                         .isoLatin1, .windowsCP1251, .windowsCP1252, .macOSRoman] {
            if let text = try? String(contentsOf: url, encoding: encoding), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    /// Says so, rather than looking broken.
    private func report(unreadable: [String]) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Nothing to copy")
        alert.informativeText = unreadable.count == 1
            ? String(localized: "“\(unreadable[0])” is not a text file, so there is no text in it to copy.")
            : String(localized: "None of the selected files contain text.")
        alert.alertStyle = .informational
        alert.runModal()
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
