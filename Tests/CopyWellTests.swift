import AppKit
import Testing
import Foundation
@testable import CopyWell

// MARK: - Hashing

@Suite("Content hashing")
struct ContentHasherTests {

    /// The reason this type exists: `Hasher` is seeded per process, so hashes
    /// changed on every launch and deduplication silently stopped working.
    @Test("Hashes are stable for identical content")
    func stableAcrossCalls() {
        let first = ContentHasher.hash(text: "hello", url: nil, imageData: nil)
        let second = ContentHasher.hash(text: "hello", url: nil, imageData: nil)
        #expect(first == second)
        #expect(first.count == 64)
    }

    @Test("Different content hashes differently")
    func differsForDifferentContent() {
        #expect(ContentHasher.hash(text: "a", url: nil, imageData: nil)
                != ContentHasher.hash(text: "b", url: nil, imageData: nil))
    }

    /// Without the separator, ("ab", nil) and ("a", "b") would collide.
    @Test("Fields are separated so they cannot collide")
    func fieldsDoNotCollide() {
        #expect(ContentHasher.hash(text: "ab", url: "", imageData: nil)
                != ContentHasher.hash(text: "a", url: "b", imageData: nil))
    }

    @Test("Record names are derived deterministically")
    func recordNameIsDeterministic() {
        let hash = ContentHasher.hash(text: "sync me", url: nil, imageData: nil)
        #expect(ContentHasher.recordName(for: hash) == ContentHasher.recordName(for: hash))
        #expect(ContentHasher.recordName(for: hash).count <= 48)
    }
}

// MARK: - Type detection

@Suite("Type detection")
struct TypeDetectorTests {
    let detector = TypeDetector()

    @Test("Recognises URLs", arguments: ["https://example.com", "http://a.b/c?d=e"])
    func detectsURLs(_ input: String) {
        #expect(detector.detectType(for: input) == .url)
    }

    @Test("Recognises email addresses")
    func detectsEmail() {
        #expect(detector.detectType(for: "someone@example.com") == .email)
    }

    @Test("Recognises hex colours")
    func detectsColor() {
        #expect(detector.detectType(for: "#1a2b3c") == .color)
    }

    @Test("Falls back to plain text")
    func fallsBackToText() {
        #expect(detector.detectType(for: "just a sentence") == .text)
    }
}

// MARK: - Export

@Suite("Export")
@MainActor
struct ExportManagerTests {

    /// A clip containing a quote, comma or newline must survive a round trip
    /// through a spreadsheet.
    @Test("CSV escapes quotes and separators")
    func csvEscaping() throws {
        let item = ClipboardItem(contentType: .text, contentHash: "h1", text: "say \"hi\", now\nplease")
        let data = try #require(ExportManager.export(items: [item], format: .csv))
        let csv = try #require(String(data: data, encoding: .utf8))
        #expect(csv.contains("\"say \"\"hi\"\", now\nplease\""))
    }

    /// Clip text is arbitrary and goes straight into markup.
    @Test("HTML escapes markup in clip text")
    func htmlEscaping() throws {
        let item = ClipboardItem(contentType: .text, contentHash: "h2", text: "<script>alert(1)</script>")
        let data = try #require(ExportManager.export(items: [item], format: .html))
        let html = try #require(String(data: data, encoding: .utf8))
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test("Sensitive clips are never exported")
    func sensitiveExcluded() throws {
        let secret = ClipboardItem(contentType: .password, contentHash: "h3", text: "hunter2", isSensitive: true)
        let normal = ClipboardItem(contentType: .text, contentHash: "h4", text: "public")
        let data = try #require(ExportManager.export(items: [secret, normal], format: .json))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("hunter2"))
        #expect(json.contains("public"))
    }
}

// MARK: - Model

@Suite("Clipboard item")
@MainActor
struct ClipboardItemTests {

    @Test("Sensitive clips keep no plaintext")
    func sensitiveIsNotPlaintext() {
        let item = ClipboardItem(contentType: .password, contentHash: "h", text: "s3cret", isSensitive: true)
        #expect(item.text == nil)
        #expect(item.displayBody == "••••••••••••")
    }

    @Test("Marking an existing clip sensitive removes the plaintext")
    func markingSensitiveClearsPlaintext() {
        let item = ClipboardItem(contentType: .text, contentHash: "h", text: "token abc")
        #expect(item.text == "token abc")
        item.markSensitive()
        #expect(item.text == nil)
        #expect(item.isSensitive)
    }

    @Test("Search corpus excludes sensitive bodies")
    func searchCorpusHidesSecrets() {
        let item = ClipboardItem(contentType: .password, contentHash: "h", text: "s3cret", isSensitive: true)
        #expect(!item.searchCorpus.contains("s3cret"))
    }
}

// MARK: - Shortcuts

@Suite("Shortcuts")
struct ClipShortcutTests {

    @Test("Every action has a distinct default binding")
    func defaultsAreUnique() {
        let defaults = ShortcutAction.allCases.map(\.defaultShortcut)
        #expect(Set(defaults).count == defaults.count)
    }

    @Test("Hot key ids are unique and non-zero")
    func hotKeyIDsAreUnique() {
        let ids = ShortcutAction.allCases.map(\.hotKeyID)
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains(0))
    }

    /// A binding with no command/option/control modifier would swallow ordinary
    /// typing across the whole system.
    @Test("Bindings without a real modifier are rejected")
    func requiresModifier() {
        let bare = ClipShortcut(keyCode: 9, modifiers: 0)
        #expect(!bare.isValidGlobalBinding)
        let allValid = ShortcutAction.allCases.allSatisfy { $0.defaultShortcut.isValidGlobalBinding }
        #expect(allValid)
    }

    @Test("Display strings order modifiers the way macOS does")
    func displayString() {
        let shortcut = ShortcutAction.quickPaste.defaultShortcut
        #expect(shortcut.displayString == "⌥⌘V")
    }
}

// MARK: - Subscription gating

@Suite("Subscription tiers")
struct SubscriptionTierTests {

    /// Access is all or nothing: the trial and a subscription unlock everything,
    /// and without either the app is locked rather than reduced.
    @Test("Access is all or nothing")
    @MainActor
    func accessIsAllOrNothing() {
        let manager = SubscriptionManager.shared
        let unlocked = manager.hasFullAccess
        for feature in PremiumFeature.allCases {
            #expect(manager.checkAccess(for: feature) == unlocked)
        }
        #expect(manager.isLocked == !unlocked)
        #expect(manager.pinboardLimit == -1)
    }

    /// Every advertised feature must have a description; blank marketing copy on
    /// a purchase screen is a review finding.
    @Test("Every premium feature is described")
    func featuresDescribed() {
        for feature in PremiumFeature.allCases {
            #expect(!feature.title.isEmpty)
            #expect(!feature.summary.isEmpty)
            #expect(!feature.icon.isEmpty)
        }
    }
}


// MARK: - Themes

@Suite("Themes")
@MainActor
struct ThemeTests {

    @Test("Every theme defines a complete palette")
    func palettesAreComplete() {
        for theme in AppTheme.allCases {
            #expect(!theme.displayName.isEmpty)
            #expect(!theme.summary.isEmpty)
            _ = theme.palette
        }
    }

    /// A custom theme pins its appearance; that is what keeps system label
    /// colours readable on its surfaces.
    @Test("Custom themes pin an appearance, System follows the Mac")
    func appearancePinning() {
        #expect(AppTheme.system.palette.appearance == nil)
        for theme in AppTheme.allCases where theme.isCustom {
            #expect(theme.palette.appearance != nil)
            #expect(theme.palette.usesSystemMaterials == false)
        }
    }

    @Test("System, Light and Dark defer to AppKit's own colours")
    func systemThemesUseMaterials() {
        for theme in AppTheme.allCases where !theme.isCustom {
            #expect(theme.palette.usesSystemMaterials)
        }
    }
}

// MARK: - Sync bookkeeping

@Suite("Deletion log", .serialized)
struct DeletionLogTests {

    private func reset() {
        UserDefaults.standard.removeObject(forKey: "sync_deleted_hashes")
    }

    @Test("A deleted clip is remembered so iCloud does not hand it back")
    func recordsDeletion() {
        reset()
        DeletionLog.record("abc")
        #expect(DeletionLog.contains("abc"))
        #expect(DeletionLog.pending().contains("abc"))
        reset()
    }

    /// Copying something again is an explicit act and must override an earlier
    /// deletion, otherwise the clip could never be recorded a second time.
    @Test("Copying the same content again clears its deletion")
    func forgetOnRecapture() {
        reset()
        DeletionLog.record("abc")
        DeletionLog.forget("abc")
        #expect(!DeletionLog.contains("abc"))
        reset()
    }

    @Test("Unrelated hashes are unaffected")
    func isolation() {
        reset()
        DeletionLog.record("one")
        DeletionLog.forget("two")
        #expect(DeletionLog.contains("one"))
        reset()
    }
}


// MARK: - Secret detection

@Suite("Secret detection")
struct SecretDetectionTests {
    let detector = TypeDetector()

    /// The old rule flagged any mixed-case string with a digit and a symbol, so
    /// ordinary content was dropped before it reached the history.
    @Test("Ordinary content is not mistaken for a password", arguments: [
        "Hello, world! 42",
        "https://example.com/path?a=1&b=2",
        "~/Projects/app/Sources/Main.swift",
        "let total = items.count * 2",
        "user@example.com",
        "Invoice #2026-114, due 30 days"
    ])
    func doesNotFlagOrdinaryText(_ input: String) {
        #expect(!detector.isPassword(input))
    }

    @Test("Labelled secrets are caught", arguments: [
        "password: hunter2",
        "API_KEY=abcdef123456",
        "client_secret = s3cr3t-value"
    ])
    func flagsLabelledSecrets(_ input: String) {
        #expect(detector.isPassword(input))
    }

    @Test("Known credential formats are caught", arguments: [
        "sk_live_abcdefghijklmnop123456",
        "ghp_abcdefghijklmnopqrstuvwxyz1234"
    ])
    func flagsKnownFormats(_ input: String) {
        #expect(detector.isPassword(input))
    }

    @Test("A bare high-entropy token is still caught")
    func flagsBareToken() {
        #expect(detector.isPassword("Xk9!mQ2vT7#pLw4z"))
    }

    /// Short tokens are far more likely to be ordinary words than secrets.
    @Test("Short strings are left alone")
    func ignoresShortStrings() {
        #expect(!detector.isPassword("Ab1!"))
    }
}

// MARK: - Retention

@Suite("Retention policy")
struct RetentionPolicyTests {

    @Test("Every preset describes itself")
    func presetsAreDescribed() {
        for policy in RetentionPolicy.presets {
            #expect(!policy.displayName.isEmpty)
            #expect(!policy.explanation.isEmpty)
        }
    }

    /// The free tier keeps a fixed window, so choosing any policy is paid.
    @Test("Every retention choice is a paid one")
    func proRequirement() {
        for policy in RetentionPolicy.presets {
            #expect(policy.requiresPro)
        }
    }

    @Test("Policies round-trip through storage")
    func codableRoundTrip() throws {
        for policy in RetentionPolicy.presets {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(RetentionPolicy.self, from: data)
            #expect(decoded == policy)
        }
    }
}

// MARK: - Sound

@Suite("Feedback sounds")
struct FeedbackSoundTests {

    /// Sound is off after installation; this guards the default rather than the
    /// mechanism.
    @Test("Every sound has a name and None is silent")
    func namesAndSilence() {
        for sound in FeedbackSound.allCases {
            #expect(!sound.displayName.isEmpty)
        }
        #expect(FeedbackSound.none.displayName == "None")
    }
}

// MARK: - Cloud payload

@Suite("Cloud clip")
@MainActor
struct CloudClipTests {

    @Test("Sensitive clips are never turned into a cloud payload")
    func sensitiveNeverLeaves() {
        let secret = ClipboardItem(contentType: .password, contentHash: "h", text: "s3cret", isSensitive: true)
        #expect(CloudClip(secret) == nil)
    }

    @Test("An ordinary clip round-trips through the payload")
    func roundTrip() throws {
        let item = ClipboardItem(contentType: .text, contentHash: "hash-1", text: "hello")
        item.tags = ["a", "b"]
        item.isFavorite = true
        let clip = try #require(CloudClip(item))
        let captured = clip.captured
        #expect(captured.contentHash == "hash-1")
        #expect(captured.text == "hello")
        #expect(captured.tags == ["a", "b"])
        #expect(captured.isSensitive == false)
    }
}


// MARK: - Trial

@Suite("Free trial")
@MainActor
struct TrialTests {

    /// 30 days, because a clipboard manager proves itself the day you need
    /// something from weeks ago — a week is not long enough for that to happen.
    @Test("The trial lasts 30 days")
    func duration() {
        #expect(TrialManager.duration == TimeInterval(30 * 24 * 60 * 60))
    }

    @Test("A fresh install is inside the trial")
    func freshInstallIsActive() {
        let trial = TrialManager.shared
        #expect(trial.isActive)
        #expect(trial.daysRemaining > 0)
        #expect(trial.daysRemaining <= 30)
        #expect(!trial.summary.isEmpty)
    }

    /// The end date is derived, never stored, so it cannot drift from the start.
    @Test("End date follows the start date")
    func endDateDerived() {
        let trial = TrialManager.shared
        #expect(abs(trial.endDate.timeIntervalSince(trial.startDate) - TrialManager.duration) < 1)
    }
}

// MARK: - Image dedupe

@Suite("Image hashing")
struct ImageHashTests {

    private func picture() -> NSImage {
        let size = NSSize(width: 60, height: 40)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill(); NSRect(origin: .zero, size: size).fill()
        NSColor.white.setFill(); NSRect(x: 5, y: 5, width: 20, height: 15).fill()
        image.unlockFocus()
        return image
    }

    @Test("The same picture hashes the same whether it arrived as PNG or TIFF")
    func formatDoesNotChangeTheHash() throws {
        let image = picture()
        let tiff = try #require(image.tiffRepresentation)
        let fromTIFF = try #require(NSImage(data: tiff))
        let a = try #require(ImageStore.png(from: image, maxSize: nil))
        let b = try #require(ImageStore.png(from: fromTIFF, maxSize: nil))
        #expect(ContentHasher.hash(text: nil, url: nil, imageData: a)
                == ContentHasher.hash(text: nil, url: nil, imageData: b))
    }

    @Test("Encoding the same picture twice gives the same bytes")
    func encodingIsStable() throws {
        let image = picture()
        let a = try #require(ImageStore.png(from: image, maxSize: nil))
        let b = try #require(ImageStore.png(from: image, maxSize: nil))
        #expect(a == b)
    }

    @Test("Different pictures still hash differently")
    func differentPicturesDiffer() throws {
        let one = picture()
        let two = NSImage(size: NSSize(width: 60, height: 40))
        two.lockFocus(); NSColor.systemRed.setFill(); NSRect(x: 0, y: 0, width: 60, height: 40).fill(); two.unlockFocus()
        let a = try #require(ImageStore.png(from: one, maxSize: nil))
        let b = try #require(ImageStore.png(from: two, maxSize: nil))
        #expect(ContentHasher.hash(text: nil, url: nil, imageData: a)
                != ContentHasher.hash(text: nil, url: nil, imageData: b))
    }
}
