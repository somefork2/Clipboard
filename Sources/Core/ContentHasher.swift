import CryptoKit
import Foundation

/// Stable content hashing.
///
/// `Hasher` is seeded randomly per process, so hashes computed in one launch
/// never match the next one. Deduplication and CloudKit reconciliation both
/// depend on stability across launches, so we use SHA-256.
enum ContentHasher {
    static func hash(text: String?, url: String?, imageData: Data?) -> String {
        var hasher = SHA256()
        hasher.update(data: Data((text ?? "").utf8))
        hasher.update(data: Data("\u{0}".utf8))
        hasher.update(data: Data((url ?? "").utf8))
        hasher.update(data: Data("\u{0}".utf8))
        if let imageData {
            hasher.update(data: imageData)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func hash(for item: ClipboardItem) -> String {
        hash(text: item.text, url: item.url, imageData: item.imageData)
    }

    /// Deterministic UUID derived from a content hash, so the same clip maps to
    /// the same CloudKit record name on every device.
    static func recordName(for contentHash: String) -> String {
        String(contentHash.prefix(48))
    }
}
