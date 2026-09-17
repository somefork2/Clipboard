import AppKit
import Vision
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var lastCopiedItem: ClipboardItem?

    private var monitorTask: Task<Void, Never>?
    private var lastChangeCount: Int = 0
    private let typeDetector = TypeDetector()
    private let categorizer = SmartCategorizer.shared
    private let ocrService = OCRService.shared

    var onItemCaptured: ((ClipboardItem) -> Void)?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkClipboard()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    private func checkClipboard() async {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let item = await readPasteboardContents() else { return }

        let hash = computeHash(for: item)
        item.contentHash = hash

        // AI категоризация
        if let text = item.text {
            let result = await categorizer.categorize(text)
            item.category = result.category.rawValue
            item.tags = result.tags
            item.detectedLanguage = result.language
            item.sentiment = result.sentiment
            item.aiConfidence = result.confidence
            item.entities = result.entities
            item.isPassword = result.isSensitive
        }

        // OCR для изображений
        if item.type == .image, let imageData = item.imageData {
            if let ocrText = await ocrService.recognizeText(in: imageData) {
                item.extractedText = ocrText
                // Категоризируем и распознанный текст
                let result = await categorizer.categorize(ocrText)
                if item.category == "uncategorized" {
                    item.category = result.category.rawValue
                }
                item.tags = Array(Set(item.tags + result.tags))
            }
        }

        onItemCaptured?(item)
        lastCopiedItem = item
    }

    private func readPasteboardContents() async -> ClipboardItem? {
        let pasteboard = NSPasteboard.general

        // Изображения
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            let imageData = image.tiffRepresentation
            let thumbnail = generateThumbnail(from: image)
            let item = ClipboardItem(contentType: .image, contentHash: "", imageData: imageData)
            item.imageThumbnail = thumbnail
            item.sourceApp = frontmostAppName()
            return item
        }

        // Текст
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let contentType = typeDetector.detectType(for: trimmed)
            let item = ClipboardItem(
                contentType: contentType, contentHash: "", text: trimmed,
                sourceApp: frontmostAppName(), sourceAppBundleId: frontmostAppBundleId()
            )
            if contentType == .url {
                item.url = trimmed
                item.urlTitle = URL(string: trimmed)?.host()
            }
            return item
        }

        return nil
    }

    private func computeHash(for item: ClipboardItem) -> String {
        var hasher = Hasher()
        hasher.combine(item.text ?? "")
        hasher.combine(item.url ?? "")
        hasher.combine(item.imageData?.count ?? 0)
        return String(abs(hasher.finalize()))
    }

    private func generateThumbnail(from image: NSImage) -> Data? {
        let maxSize: CGFloat = 200
        let aspectRatio = image.size.width / max(image.size.height, 1)
        let newSize = CGSize(width: min(maxSize, image.size.width), height: min(maxSize / aspectRatio, image.size.height))
        guard let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(in: NSRect(origin: .zero, size: newSize))
        NSGraphicsContext.restoreGraphicsState()
        return bitmapRep.representation(using: .png, properties: [:])
    }

    private func frontmostAppName() -> String? { NSWorkspace.shared.frontmostApplication?.localizedName }
    private func frontmostAppBundleId() -> String? { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
}
