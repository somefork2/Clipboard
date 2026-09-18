import CloudKit
import Foundation

/// A clip flattened into something that can cross actor boundaries.
struct CloudClip: Sendable {
    var contentHash: String
    var contentType: String
    var text: String?
    var url: String?
    var urlTitle: String?
    var sourceApp: String?
    var category: String
    var tags: [String]
    var isFavorite: Bool
    var createdAt: Date

    init?(_ item: ClipboardItem) {
        // Sensitive clips stay on the device that captured them.
        guard !item.isSensitive else { return nil }
        contentHash = item.contentHash
        contentType = item.contentType
        text = item.body
        url = item.url
        urlTitle = item.urlTitle
        sourceApp = item.sourceApp
        category = item.category
        tags = item.tags
        isFavorite = item.isFavorite
        createdAt = item.createdAt
    }

    init(record: CKRecord) throws {
        guard let hash = record["contentHash"] as? String,
              let type = record["contentType"] as? String else {
            throw SyncError.malformedRecord
        }
        contentHash = hash
        contentType = type
        text = record["text"] as? String
        url = record["url"] as? String
        urlTitle = record["urlTitle"] as? String
        sourceApp = record["sourceApp"] as? String
        category = record["category"] as? String ?? "uncategorized"
        tags = (record["tags"] as? [String]) ?? []
        isFavorite = (record["isFavorite"] as? Int).map { $0 == 1 } ?? false
        createdAt = record["createdAt"] as? Date ?? Date()
    }

    /// Converts back into the shape the store inserts.
    var captured: CapturedClip {
        CapturedClip(
            contentType: ContentType(rawValue: contentType) ?? .text,
            contentHash: contentHash,
            text: text,
            url: url,
            urlTitle: urlTitle,
            imageFileName: nil,
            imageThumbnail: nil,
            extractedText: nil,
            sourceApp: sourceApp,
            sourceAppBundleId: nil,
            isSensitive: false,
            category: category,
            tags: tags,
            detectedLanguage: nil,
            sentiment: 0,
            confidence: 0.5,
            entities: []
        )
    }
}

enum SyncError: Error {
    case unavailable
    case malformedRecord
}

enum SyncResult: Sendable {
    case success([CapturedClip])
    case failure(String)
}

/// Optional history sync through the user's private CloudKit database.
///
/// Records are keyed by content hash, so the same clip resolves to the same
/// record name on every device — that is what makes updates and deletions work
/// at all (the previous version saved with a random record ID and then tried to
/// delete by UUID, so nothing was ever removed).
actor CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    private let recordType = "ClipboardItemRecord"
    private var container: CKContainer?
    private var database: CKDatabase?

    private init() {}

    /// Resolves the container lazily. Touching CloudKit without the iCloud
    /// entitlement traps at runtime, so we only do it once, on demand, and keep
    /// `nil` when the build is not configured for sync.
    private func resolveDatabase() -> CKDatabase? {
        if let database { return database }
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let container = CKContainer(identifier: "iCloud.\(bundleID)")
        self.container = container
        let database = container.privateCloudDatabase
        self.database = database
        return database
    }

    func checkAccountStatus() async -> Bool {
        _ = resolveDatabase()
        guard let container else { return false }

        do {
            return try await container.accountStatus() == .available
        } catch {
            return false
        }
    }

    // MARK: - Sync

    /// Two-way reconciliation: push local clips the server lacks, and return the
    /// server's clips the local store lacks so the caller can insert them.
    func sync(localItems: [CloudClip?], deletedHashes: [String] = []) async -> SyncResult {
        let local = localItems.compactMap { $0 }
        guard let database = resolveDatabase() else {
            return .failure("iCloud sync is not configured for this build.")
        }
        guard await checkAccountStatus() else {
            return .failure("Sign in to iCloud in System Settings to use sync.")
        }

        do {
            let remote = try await fetchAll(from: database)
            let remoteHashes = Set(remote.map(\.contentHash))
            let localHashes = Set(local.map(\.contentHash))

            // Replay local deletions before anything else, so a clip removed
            // here is not pushed straight back by the device that still has it.
            let deletions = Set(deletedHashes)
            if !deletions.isEmpty {
                try await delete(Array(deletions.intersection(remoteHashes)), from: database)
            }

            let toPush = local.filter {
                !remoteHashes.contains($0.contentHash) && !deletions.contains($0.contentHash)
            }
            if !toPush.isEmpty {
                try await push(toPush, to: database)
            }

            let incoming = remote
                .filter { !localHashes.contains($0.contentHash) && !deletions.contains($0.contentHash) }
                .map(\.captured)

            return .success(incoming)
        } catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
            return .failure("No network connection. Sync will resume when you are back online.")
        } catch {
            return .failure("Sync failed: \(error.localizedDescription)")
        }
    }

    private func fetchAll(from database: CKDatabase) async throws -> [CloudClip] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        var clips: [CloudClip] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let current = cursor {
                page = try await database.records(continuingMatchFrom: current)
            } else {
                page = try await database.records(matching: query)
            }
            for (_, result) in page.matchResults {
                if case .success(let record) = result, let clip = try? CloudClip(record: record) {
                    clips.append(clip)
                }
            }
            cursor = page.queryCursor
        } while cursor != nil

        return clips
    }

    private func push(_ clips: [CloudClip], to database: CKDatabase) async throws {
        let records = clips.map { clip -> CKRecord in
            // Deterministic record name keyed by content, so the same clip from
            // another Mac maps onto the same record instead of duplicating.
            let id = CKRecord.ID(recordName: ContentHasher.recordName(for: clip.contentHash))
            let record = CKRecord(recordType: recordType, recordID: id)
            record["contentHash"] = clip.contentHash as CKRecordValue
            record["contentType"] = clip.contentType as CKRecordValue
            record["text"] = (clip.text ?? "") as CKRecordValue
            record["url"] = (clip.url ?? "") as CKRecordValue
            record["urlTitle"] = (clip.urlTitle ?? "") as CKRecordValue
            record["sourceApp"] = (clip.sourceApp ?? "") as CKRecordValue
            record["category"] = clip.category as CKRecordValue
            record["tags"] = clip.tags as CKRecordValue
            record["isFavorite"] = (clip.isFavorite ? 1 : 0) as CKRecordValue
            record["createdAt"] = clip.createdAt as CKRecordValue
            return record
        }

        // Batch in chunks; CloudKit rejects oversized modify operations.
        for chunk in stride(from: 0, to: records.count, by: 200).map({ Array(records[$0..<min($0 + 200, records.count)]) }) {
            _ = try await database.modifyRecords(saving: chunk, deleting: [], savePolicy: .changedKeys)
        }
    }

    func delete(contentHash: String) async throws {
        guard let database = resolveDatabase() else { throw SyncError.unavailable }
        try await delete([contentHash], from: database)
    }

    private func delete(_ contentHashes: [String], from database: CKDatabase) async throws {
        guard !contentHashes.isEmpty else { return }
        let ids = contentHashes.map { CKRecord.ID(recordName: ContentHasher.recordName(for: $0)) }
        for chunk in stride(from: 0, to: ids.count, by: 200).map({ Array(ids[$0..<min($0 + 200, ids.count)]) }) {
            _ = try await database.modifyRecords(saving: [], deleting: chunk)
        }
    }
}
