import Foundation
import Observation

/// Counts clips that were deliberately not recorded.
///
/// Dropping a copy silently is indistinguishable from the app being broken —
/// the user copies something and nothing appears. The count gives the interface
/// something honest to say.
@MainActor
@Observable
final class PrivacyLog {
    static let shared = PrivacyLog()

    private(set) var skippedTotal: Int
    /// Set when something was skipped recently, for a transient notice.
    private(set) var lastSkip: Date?

    private init() {
        skippedTotal = UserDefaults.standard.integer(forKey: "privacy_skipped_total")
    }

    func recordSkip() {
        skippedTotal += 1
        lastSkip = Date()
        UserDefaults.standard.set(skippedTotal, forKey: "privacy_skipped_total")
    }

    /// True for a short while after a skip, so a banner can appear and go.
    var hasRecentSkip: Bool {
        guard let lastSkip else { return false }
        return Date().timeIntervalSince(lastSkip) < 6
    }

    func clearNotice() { lastSkip = nil }
}
