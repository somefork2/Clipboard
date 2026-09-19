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
    var richTextData: Data?
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0
    var imageByteSize: Int = 0
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
        // A locked app records nothing. The history already on disk is left
        // untouched, so subscribing brings it all back.
        guard SubscriptionManager.shared.hasFullAccess else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        // Our own paste. Recording it would move the clip to the top of the
        // history and count a copy the user did not make.
        guard pasteboard.changeCount != PasteboardPrivacy.lastSelfWriteChangeCount else { return }

        let settings = AppSettings.shared
        // Language, entities and tags are the Pro half of categorisation; type
        // detection stays free. Read here, on the main actor, before the work
        // moves to a background task.
        let analyse = SubscriptionManager.shared.checkAccess(for: .smartCategorize)

        // Never record what a password manager marked as secret.
        if settings.skipConcealedPasteboard, PasteboardPrivacy.isConcealed(pasteboard) { return }

        // One lookup, not two: `frontmostApplication` crosses to the window
        // server, and this runs on every copy.
        let frontmost = NSWorkspace.shared.frontmostApplication
        let sourceApp = frontmost?.localizedName
        let sourceBundleID = frontmost?.bundleIdentifier
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
                skipPasswords: settings.skipPasswords,
                analyse: analyse
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
        skipPasswords: Bool,
        analyse: Bool = true
    ) async -> CapturedClip? {
        // Images first: a copied screenshot also carries a string on some pasteboards.
        if let imageData = snapshot.png ?? snapshot.tiff, let image = NSImage(data: imageData) {
            let hash = ContentHasher.hash(text: nil, url: nil, imageData: imageData)
            let fileName = "\(hash.prefix(32)).png"
            guard ImageStore.write(image, fileName: fileName) != nil else { return nil }

            let thumbnail = ImageStore.thumbnail(from: image)
            let pixels = ImageStore.pixelSize(of: image)
            let storedBytes = ImageStore.read(fileName: fileName)?.count ?? imageData.count
            let ocrText = await OCRService.shared.recognizeText(in: imageData)

            var category = "uncategorized"
            var tags: [String] = []
            if analyse, let ocrText {
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
                pixelWidth: Int(pixels.width),
                pixelHeight: Int(pixels.height),
                imageByteSize: storedBytes,
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

        // Prefer the styled version when the source offered one; the plain
        // string stays alongside it for search and for plain-text pasting.
        guard let raw = snapshot.string
            ?? snapshot.rtf.flatMap({ NSAttributedString(rtf: $0, documentAttributes: nil)?.string })
        else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let detected = typeDetector.detectType(for: trimmed)
        // Sensitivity is never gated: skipping a password is a safety promise,
        // not a feature.
        let analysis = analyse ? await SmartCategorizer.shared.categorize(trimmed) : nil
        let sensitive = (analysis?.isSensitive ?? false) || detected == .password

        // The user asked us not to keep secrets at all — honour that over storing
        // an encrypted copy. It is recorded as a count so the app can say a clip
        // was skipped instead of appearing broken.
        if sensitive && skipPasswords {
            await MainActor.run { PrivacyLog.shared.recordSkip() }
            return nil
        }

        var url: String?
        var urlTitle: String?
        if detected == .url {
            url = trimmed
            urlTitle = URL(string: trimmed)?.host()
        }

        return CapturedClip(
            contentType: sensitive ? .password : (snapshot.rtf != nil && detected == .text ? .richText : detected),
            contentHash: ContentHasher.hash(text: trimmed, url: url, imageData: nil),
            text: trimmed,
            url: url,
            urlTitle: urlTitle,
            imageFileName: nil,
            imageThumbnail: nil,
            richTextData: sensitive ? nil : snapshot.rtf,
            extractedText: nil,
            sourceApp: sourceApp,
            sourceAppBundleId: sourceBundleID,
            isSensitive: sensitive,
            category: analysis?.category.rawValue ?? "uncategorized",
            tags: analysis?.tags ?? [],
            detectedLanguage: analysis?.language,
            sentiment: analysis?.sentiment ?? 0,
            confidence: analysis?.confidence ?? 0.5,
            entities: analysis?.entities ?? []
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
            skipPasswords: await AppSettings.shared.skipPasswords,
            analyse: await SubscriptionManager.shared.checkAccess(for: .smartCategorize)
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
