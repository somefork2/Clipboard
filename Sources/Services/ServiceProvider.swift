import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ServiceProvider: NSObject {

    // MARK: - Save selected text to ClipStack (from any app)

    @objc func saveSelectionToClipStack(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        // Get selected text from any app
        if let text = pboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
            let sourceBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

            let item = ClipboardItem(
                contentType: TypeDetector().detectType(for: text),
                contentHash: "",
                text: text,
                sourceApp: sourceApp,
                sourceAppBundleId: sourceBundleId
            )
            ClipboardMonitor.sharedSave(item: item)
        }

        // Get file URLs from Finder
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            for url in urls {
                saveFileToClipStack(url: url)
            }
        }

        // Get images
        if let tiffData = pboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            let item = ClipboardItem(
                contentType: .image,
                contentHash: "",
                imageData: tiffData,
                sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
                sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            )
            item.imageThumbnail = generateThumbnail(from: image)
            ClipboardMonitor.sharedSave(item: item)
        }

        // Get RTF
        if let rtfData = pboard.data(forType: .rtf),
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            let text = attributedString.string
            if !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                let item = ClipboardItem(
                    contentType: .richText,
                    contentHash: "",
                    text: text,
                    sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
                    sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                )
                ClipboardMonitor.sharedSave(item: item)
            }
        }
    }

    // MARK: - Quick Paste from ClipStack (into any text field)

    @objc func quickPasteFromClipStack(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        // Get the last copied item from ClipStack
        guard let lastItem = ClipboardMonitor.getLastItem() else { return }

        pboard.clearContents()
        if let text = lastItem.text {
            pboard.setString(text, forType: .string)
        } else if let imageData = lastItem.imageData, let image = NSImage(data: imageData) {
            pboard.writeObjects([image])
        }
    }

    // MARK: - Pin to ClipStack

    @objc func pinToClipStack(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        if let text = pboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let item = ClipboardItem(
                contentType: TypeDetector().detectType(for: text),
                contentHash: "",
                text: text,
                sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
                sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            )
            item.isFavorite = true
            ClipboardMonitor.sharedSave(item: item)
        }
    }

    // MARK: - Helpers

    private func saveFileToClipStack(url: URL) {
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()

        if let textContent = try? String(contentsOf: url, encoding: .utf8) {
            let item = ClipboardItem(
                contentType: .text,
                contentHash: "",
                text: "[\(fileName)]\n\(textContent)",
                sourceApp: "Finder",
                sourceAppBundleId: "com.apple.finder"
            )
            ClipboardMonitor.sharedSave(item: item)
        } else if ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp", "heic"].contains(fileExtension),
                  let imageData = try? Data(contentsOf: url),
                  let image = NSImage(data: imageData) {
            let item = ClipboardItem(
                contentType: .image,
                contentHash: "",
                imageData: imageData,
                sourceApp: "Finder",
                sourceAppBundleId: "com.apple.finder"
            )
            item.imageThumbnail = generateThumbnail(from: image)
            ClipboardMonitor.sharedSave(item: item)
        } else {
            let item = ClipboardItem(
                contentType: .url,
                contentHash: "",
                text: url.path,
                sourceApp: "Finder",
                sourceAppBundleId: "com.apple.finder"
            )
            item.url = url.absoluteString
            ClipboardMonitor.sharedSave(item: item)
        }
    }

    private func generateThumbnail(from image: NSImage) -> Data? {
        let maxSize: CGFloat = 200
        let aspectRatio = image.size.width / max(image.size.height, 1)
        let newSize = CGSize(
            width: min(maxSize, image.size.width),
            height: min(maxSize / aspectRatio, image.size.height)
        )
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(in: NSRect(origin: .zero, size: newSize))
        NSGraphicsContext.restoreGraphicsState()
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
