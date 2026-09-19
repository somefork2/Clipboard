import AppKit
import SwiftUI

/// The right-click menu for a clip, shared by the main list, the palette and the
/// menu bar so the same actions are always in the same order.
struct ClipContextMenu: View {
    let item: ClipboardItem
    var onPaste: (() -> Void)?
    var onPastePlain: (() -> Void)?
    var onPreview: (() -> Void)?

    @Environment(ClipboardStore.self) private var store

    var body: some View {
        if let onPaste {
            Button(L("Paste"), action: onPaste)
        }
        if let onPastePlain, item.type != .image {
            Button(L("Paste as Plain Text"), action: onPastePlain)
        }
        Button(L("Copy")) {
            guard let content = item.pasteContent else { return }
            PasteService.write(content)
            store.recordUse(item)
        }

        Divider()

        Button(item.isFavorite ? L("Remove from Favourites") : L("Add to Favourites")) {
            store.toggleFavorite(item)
        }

        Button(L("Add to Paste Stack")) {
            guard SubscriptionManager.shared.requestAccess(for: .pasteStack) else { return }
            PasteStackManager.shared.add(item)
        }

        if !store.pinboards.isEmpty || SubscriptionManager.shared.hasFullAccess {
            Menu("Move to Pinboard") {
                Button(L("None")) { store.assign(item, to: nil) }
                if !store.pinboards.isEmpty { Divider() }
                ForEach(store.pinboards) { board in
                    Button(board.name) { store.assign(item, to: board) }
                }
            }
        }

        Divider()

        if let onPreview {
            Button(L("Quick Look"), action: onPreview)
        }

        if item.type == .url, let urlString = item.url, let url = URL(string: urlString) {
            Button(L("Open Link")) { NSWorkspace.shared.open(url) }
        }

        if item.type == .image, let fileName = item.imageFileName {
            Button(L("Reveal Image in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([ImageStore.url(for: fileName)])
            }
            Button(L("Save Image As…")) { saveImage(fileName: fileName) }
        }

        if let bundleID = item.sourceAppBundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Button(L("Open \(item.sourceApp ?? L("Source App"))")) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }

        if !item.isSensitive {
            Button(L("Mark as Sensitive")) {
                item.markSensitive()
                store.save()
                store.reload()
            }
        }

        Divider()

        Button(L("Delete"), role: .destructive) { store.delete(item) }
        if let app = item.sourceApp {
            Button(L("Delete All from \(app)"), role: .destructive) { store.deleteAll(fromApp: app) }
        }
    }

    private func saveImage(fileName: String) {
        guard let data = ImageStore.read(fileName: fileName) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Clip.png"
        panel.allowedContentTypes = [.png]
        // A save panel is how a sandboxed app legitimately gains write access
        // to a location the user picks.
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
