import AppKit
import Foundation

/// Stores clip images on disk instead of inside the SwiftData store.
///
/// Full-resolution `tiffRepresentation` of a 5K screenshot is ~50 MB uncompressed;
/// keeping those in the database made it grow by gigabytes in a week. We keep a
/// small PNG thumbnail in the model and the full image as a PNG file on disk.
enum ImageStore {
    static let thumbnailMaxSize: CGFloat = 320

    /// Immutable so it is safe to touch from any isolation domain.
    private static let directory: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipStack/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// Writes the image as PNG and returns the file name to store in the model.
    @discardableResult
    static func write(_ image: NSImage, fileName: String) -> String? {
        guard let data = png(from: image, maxSize: nil) else { return nil }
        let target = url(for: fileName)
        do {
            try data.write(to: target, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func read(fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    static func remove(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Removes image files that no longer belong to any live clip.
    static func pruneOrphans(keeping liveFileNames: Set<String>) {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where !liveFileNames.contains(name) {
            remove(fileName: name)
        }
    }

    /// True pixel dimensions. `NSImage.size` is in points, so a Retina
    /// screenshot reports half its real size there.
    static func pixelSize(of image: NSImage) -> CGSize {
        for case let rep as NSBitmapImageRep in image.representations {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        if let rep = image.representations.first {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
    }

    static func thumbnail(from image: NSImage) -> Data? {
        png(from: image, maxSize: thumbnailMaxSize)
    }

    /// Renders `image` to PNG, optionally downscaled so its longest side is `maxSize`.
    static func png(from image: NSImage, maxSize: CGFloat?) -> Data? {
        let source = image.size
        guard source.width > 0, source.height > 0 else { return nil }

        var target = source
        if let maxSize, max(source.width, source.height) > maxSize {
            let scale = maxSize / max(source.width, source.height)
            target = CGSize(width: (source.width * scale).rounded(),
                            height: (source.height * scale).rounded())
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(Int(target.width), 1),
            pixelsHigh: max(Int(target.height), 1),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: target))
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}
