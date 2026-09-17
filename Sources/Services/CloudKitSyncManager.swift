import CloudKit
import SwiftData
import Foundation

actor CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    private let container: CKContainer?
    private let database: CKDatabase?
    private let recordType = "ClipboardItemRecord"

    init() {
        // Only initialize CloudKit if container identifier is configured
        if Bundle.main.object(forInfoDictionaryKey: "CKContainerIdentifier") != nil {
            self.container = CKContainer.default()
            self.database = container?.privateCloudDatabase
        } else {
            self.container = nil
            self.database = nil
        }
    }

    // MARK: - Проверка доступности

    func checkAccountStatus() async -> Bool {
        guard let container else { return false }
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    func saveItem(_ item: ClipboardItem) async throws {
        guard let database else { return }
        let record = CKRecord(recordType: recordType)
        record["text"] = item.text as NSString? ?? "" as NSString
        record["contentType"] = item.contentType as NSString
        record["url"] = item.url as NSString? ?? "" as NSString
        record["sourceApp"] = item.sourceApp as NSString? ?? "" as NSString
        record["category"] = item.category as NSString
        record["tags"] = item.tags.joined(separator: ",") as NSString
        record["isFavorite"] = item.isFavorite as NSNumber
        record["createdAt"] = item.createdAt as NSDate
        record["contentHash"] = item.contentHash as NSString

        if let imageData = item.imageData {
            record["imageData"] = imageData as NSData
        }

        try await database.save(record)
    }

    // MARK: - Загрузка

    func fetchAllItems() async throws -> [ClipboardItem] {
        guard let database else { return [] }
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (matchResults, _) = try await database.records(matching: query)
        var items: [ClipboardItem] = []

        for (recordID, result) in matchResults {
            switch result {
            case .success(let record):
                if let item = parseRecord(record) {
                    items.append(item)
                }
            case .failure(let error):
                print("Failed to fetch record \(recordID): \(error)")
            }
        }

        return items
    }

    // MARK: - Удаление

    func deleteItem(withID id: UUID) async throws {
        guard let database else { return }
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await database.deleteRecord(withID: recordID)
    }

    // MARK: - Синхронизация

    func sync(localItems: [ClipboardItem]) async throws {
        // 1. Загружаем с сервера
        let remoteItems = try await fetchAllItems()
        let remoteHashes = Set(remoteItems.map { $0.contentHash })
        let localHashes = Set(localItems.map { $0.contentHash })

        // 2. Отправляем новые локальные элементы
        for item in localItems where !remoteHashes.contains(item.contentHash) {
            try await saveItem(item)
        }

        // 3. Получаем новые удалённые с сервера
        let newRemoteHashes = remoteHashes.subtracting(localHashes)
        let newRemoteItems = remoteItems.filter { newRemoteHashes.contains($0.contentHash) }

        // Возвращаем новые элементы для вставки в локальную БД
        // (вызывающий код должен сохранить их)
        _ = newRemoteItems
    }

    // MARK: - Парсинг

    private func parseRecord(_ record: CKRecord) -> ClipboardItem? {
        guard let contentType = record["contentType"] as? String,
              let contentHash = record["contentHash"] as? String,
              let type = ContentType(rawValue: contentType) else {
            return nil
        }

        let item = ClipboardItem(
            contentType: type,
            contentHash: contentHash,
            text: record["text"] as? String,
            imageData: record["imageData"] as? Data,
            url: record["url"] as? String,
            sourceApp: record["sourceApp"] as? String
        )

        item.category = record["category"] as? String ?? "uncategorized"
        item.tags = (record["tags"] as? String)?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        item.isFavorite = record["isFavorite"] as? Bool ?? false

        if let createdAt = record["createdAt"] as? Date {
            item.createdAt = createdAt
        }

        return item
    }
}
