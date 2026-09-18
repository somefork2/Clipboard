import AppKit
import Foundation
import UniformTypeIdentifiers

/// Backs the entries ClipStack adds to the system Services menu, which is how a
/// Mac app legitimately appears in the right-click menu of other applications.
///
/// macOS does not let a third-party app inject items into the top level of
/// another app's context menu; Services is the supported route, and the entries
/// appear under the Services submenu (or at the top level in Finder for files).
@MainActor
final class ServiceProvider: NSObject {

    // MARK: - Save selection

    @objc func saveSelectionToClipStack(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        ingest(pboard, favorite: false)
    }

    // MARK: - Pin selection

    @objc func pinToClipStack(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        ingest(pboard, favorite: true)
    }

    // MARK: - Add to paste stack

    @objc func addToPasteStack(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        ingest(pboard, favorite: false) { item in
            guard SubscriptionManager.shared.requestAccess(for: .pasteStack) else { return }
            PasteStackManager.shared.add(item)
        }
    }

    // MARK: - Paste from ClipStack

    /// Returns a clip to the requesting app. Opens the palette so the user picks
    /// which one, rather than silently inserting whatever happened to be last.
    @objc func quickPasteFromClipStack(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        QuickPastePanel.shared.show()
    }

    // MARK: - Ingest

    private func ingest(
        _ pboard: NSPasteboard,
        favorite: Bool,
        then completion: (@MainActor (ClipboardItem) -> Void)? = nil
    ) {
        // Respect the same privacy rules as automatic capture.
        if AppSettings.shared.skipConcealedPasteboard, PasteboardPrivacy.isConcealed(pboard) { return }

        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName
        let bundleID = app?.bundleIdentifier

        if let image = images(from: pboard).first {
            Task { @MainActor in
                guard let clip = await ClipboardMonitor.makeClip(
                    image: image,
                    sourceApp: appName,
                    sourceBundleID: bundleID
                ) else { return }
                finish(clip, favorite: favorite, completion: completion)
            }
            return
        }

        guard let text = text(from: pboard) else { return }
        Task { @MainActor in
            guard let clip = await ClipboardMonitor.makeClip(
                text: text,
                sourceApp: appName,
                sourceBundleID: bundleID
            ) else { return }
            finish(clip, favorite: favorite, completion: completion)
        }
    }

    private func finish(
        _ clip: CapturedClip,
        favorite: Bool,
        completion: (@MainActor (ClipboardItem) -> Void)?
    ) {
        guard let item = ClipboardStore.shared.insert(clip) else { return }
        if favorite && !item.isFavorite {
            ClipboardStore.shared.toggleFavorite(item)
        }
        completion?(item)
    }

    // MARK: - Pasteboard reading

    private func text(from pboard: NSPasteboard) -> String? {
        if let string = pboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return string
        }
        if let rtf = pboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil),
           !attributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return attributed.string
        }
        // Files handed to us by the user through Services: the sandbox grants
        // access to exactly these, so we record their paths and read images.
        if let urls = pboard.readObjects(forClasses: [NSURL.self],
                                         options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls.map(\.path).joined(separator: "\n")
        }
        return nil
    }

    private func images(from pboard: NSPasteboard) -> [NSImage] {
        if let data = pboard.data(forType: .png) ?? pboard.data(forType: .tiff),
           let image = NSImage(data: data) {
            return [image]
        }
        if let urls = pboard.readObjects(forClasses: [NSURL.self],
                                         options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            let imageTypes: Set<String> = ["png", "jpg", "jpeg", "gif", "tiff", "heic", "bmp", "webp"]
            return urls
                .filter { imageTypes.contains($0.pathExtension.lowercased()) }
                .compactMap { NSImage(contentsOf: $0) }
        }
        return []
    }
}
