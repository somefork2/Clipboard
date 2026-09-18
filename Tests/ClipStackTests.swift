import Testing
import Foundation
@testable import ClipStack

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

    @Test("Free tier is capped, Pro is not")
    func limits() {
        #expect(SubscriptionTier.free.maxItems == 100)
        #expect(SubscriptionTier.pro.maxItems == -1)
        #expect(SubscriptionTier.free.maxPinboards == 1)
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
