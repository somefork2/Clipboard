import CloudKit
import Foundation
import Testing
@testable import CopyWell

/// Exercises sync against the real private database of whoever is signed in.
///
/// Off by default: it needs a network, an iCloud account, and it writes to that
/// account. Run it deliberately with `COPYWELL_LIVE_CLOUDKIT=1`.
///
/// It exists because a custom-zone sync creates its record type on first save,
/// and a schema that has never been created in Development cannot be deployed to
/// Production — which would leave sync broken for every shipping user while the
/// App Store description promises it.
@Suite("CloudKit, against the live account", .serialized)
struct CloudKitLiveTests {

    private var enabled: Bool { ProcessInfo.processInfo.environment["COPYWELL_LIVE_CLOUDKIT"] == "1" }

    @MainActor
    private func sample(_ marker: String) -> CloudClip? {
        let item = ClipboardItem(
            contentType: .text,
            contentHash: "livecheck-\(marker)",
            text: "CopyWell schema check \(marker)"
        )
        item.url = "https://example.com/\(marker)"
        item.urlTitle = "Schema check"
        item.sourceApp = "CopyWell Tests"
        item.tags = ["schema", "check"]
        item.isFavorite = true
        return CloudClip(item)
    }

    @Test("A clip makes the round trip through iCloud")
    func roundTrip() async throws {
        guard enabled else { return }

        #expect(await CloudKitSyncManager.shared.checkAccountStatus(),
                "No iCloud account is available on this Mac, so nothing can be verified.")

        let marker = String(UUID().uuidString.prefix(8)).lowercased()
        let clip = try #require(await sample(marker))

        let pushed = await CloudKitSyncManager.shared.sync(localItems: [clip])
        if case .failure(let reason) = pushed {
            Issue.record("Push failed: \(reason)")
            return
        }

        // Pulling is what proves the record type and every field really exist:
        // a save can succeed while the field types are wrong for reading back.
        let reread = await CloudKitSyncManager.shared.sync(localItems: [])
        if case .failure(let reason) = reread {
            Issue.record("Pull failed: \(reason)")
        }

        // Leave the account as we found it.
        let cleaned = await CloudKitSyncManager.shared.sync(localItems: [], deletedHashes: [clip.contentHash])
        if case .failure(let reason) = cleaned {
            Issue.record("Cleanup failed, a test record is left behind: \(reason)")
        }
    }
}
