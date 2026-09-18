import AppKit
import Foundation
import Observation

/// A clip captured from the pasteboard, before it becomes a SwiftData object.
///
/// Keeping capture separate from persistence lets the expensive work (OCR,
/// language analysis, PNG encoding) run off the main actor without touching
/// model objects from the wrong context.
struct CapturedClip: Sendable {
    var contentType: ContentType
    var contentHash: String
    var text: String?
    var url: String?
    var urlTitle: String?
    var imageFileName: String?
    var imageThumbnail: Data?
    var extractedText: String?
    var sourceApp: String?
    var sourceAppBundleId: String?
    var isSensitive: Bool
    var category: String
    var tags: [String]
    var detectedLanguage: String?
    var sentiment: Double
    var confidence: Double
    var entities: [ExtractedEntity]
}

@MainActor
@Observable
final class ClipboardMonitor {
    private(set) var isMonitoring = false
    private(set) var isPaused = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastChangeCount = NSPasteboard.general.changeCount
    @ObservationIgnored private let typeDetector = TypeDetector()

    /// Called on the main actor for every accepted clip.
    var onClipCaptured: ((CapturedClip) -> Void)?

    /// Shared instance so the Services provider can hand clips to the running app.
    static private(set) weak var shared: ClipboardMonitor?

    init() {
        ClipboardMonitor.shared = self
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        isPaused = false
        lastChangeCount = NSPasteboard.general.changeCount

        // A repeating timer on the main run loop only reads `changeCount`, which
        // is cheap; everything expensive is handed to a background task.
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            stopMonitoring()
            isPaused = true
        } else {
            startMonitoring()
        }
    }

    // MARK: - Capture

    private func tick() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let settings = AppSettings.shared

        // Never record what a password manager marked as secret.
        if settings.skipConcealedPasteboard, PasteboardPrivacy.isConcealed(pasteboard) { return }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if PasteboardPrivacy.isExcluded(bundleIdentifier: sourceBundleID) { return }

        // Snapshot the pasteboard synchronously — its contents can change under us.
        let snapshot = PasteboardSnapshot(
            string: pasteboard.string(forType: .string),
            tiff: pasteboard.data(forType: .tiff),
            png: pasteboard.data(forType: .png),
            rtf: pasteboard.data(forType: .rtf)
        )

        Task.detached(priority: .utility) { [typeDetector] in
            guard let clip = await Self.process(
                snapshot: snapshot,
                sourceApp: sourceApp,
                sourceBundleID: sourceBundleID,
                typeDetector: typeDetector,
                skipPasswords: settings.skipPasswords
            ) else { return }

            await MainActor.run { [weak self] in
                self?.onClipCaptured?(clip)
            }
        }
    }

    private struct PasteboardSnapshot: Sendable {
        var string: String?
        var tiff: Data?
        var png: Data?
        var rtf: Data?
    }

    private static func process(
        snapshot: PasteboardSnapshot,
        sourceApp: String?,
        sourceBundleID: String?,
        typeDetector: TypeDetector,
        skipPasswords: Bool
    ) async -> CapturedClip? {
        // Images first: a copied screenshot also carries a string on some pasteboards.
        if let imageData = snapshot.png ?? snapshot.tiff, let image = NSImage(data: imageData) {
            let hash = ContentHasher.hash(text: nil, url: nil, imageData: imageData)
            let fileName = "\(hash.prefix(32)).png"
            guard ImageStore.write(image, fileName: fileName) != nil else { return nil }

            let thumbnail = ImageStore.thumbnail(from: image)
            let ocrText = await OCRService.shared.recognizeText(in: imageData)

            var category = "uncategorized"
            var tags: [String] = []
            if let ocrText {
                let result = await SmartCategorizer.shared.categorize(ocrText)
                category = result.category.rawValue
                tags = result.tags
            }

            return CapturedClip(
                contentType: .image,
                contentHash: hash,
                text: nil,
                url: nil,
                urlTitle: nil,
                imageFileName: fileName,
                imageThumbnail: thumbnail,
                extractedText: ocrText,
                sourceApp: sourceApp,
                sourceAppBundleId: sourceBundleID,
                isSensitive: false,
                category: category,
                tags: tags,
                detectedLanguage: nil,
                sentiment: 0,
                confidence: 0.5,
                entities: []
            )
        }

        guard let raw = snapshot.string else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let detected = typeDetector.detectType(for: trimmed)
        let analysis = await SmartCategorizer.shared.categorize(trimmed)
        let sensitive = analysis.isSensitive || detected == .password

        // The user asked us not to keep secrets at all — honour that over storing
        // an encrypted copy.
        if sensitive && skipPasswords { return nil }

        var url: String?
        var urlTitle: String?
        if detected == .url {
            url = trimmed
            urlTitle = URL(string: trimmed)?.host()
        }

        return CapturedClip(
            contentType: sensitive ? .password : detected,
            contentHash: ContentHasher.hash(text: trimmed, url: url, imageData: nil),
            text: trimmed,
            url: url,
            urlTitle: urlTitle,
            imageFileName: nil,
            imageThumbnail: nil,
            extractedText: nil,
            sourceApp: sourceApp,
            sourceAppBundleId: sourceBundleID,
            isSensitive: sensitive,
            category: analysis.category.rawValue,
            tags: analysis.tags,
            detectedLanguage: analysis.language,
            sentiment: analysis.sentiment,
            confidence: analysis.confidence,
            entities: analysis.entities
        )
    }

    /// Builds a clip from arbitrary text — used by the Services provider and the
    /// "save selection" shortcut.
    static func makeClip(
        text: String,
        sourceApp: String?,
        sourceBundleID: String?
    ) async -> CapturedClip? {
        let snapshot = PasteboardSnapshot(string: text, tiff: nil, png: nil, rtf: nil)
        return await process(
            snapshot: snapshot,
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            typeDetector: TypeDetector(),
            skipPasswords: await AppSettings.shared.skipPasswords
        )
    }

    static func makeClip(image: NSImage, sourceApp: String?, sourceBundleID: String?) async -> CapturedClip? {
        guard let data = ImageStore.png(from: image, maxSize: nil) else { return nil }
        let snapshot = PasteboardSnapshot(string: nil, tiff: nil, png: data, rtf: nil)
        return await process(
            snapshot: snapshot,
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            typeDetector: TypeDetector(),
            skipPasswords: false
        )
    }
}
