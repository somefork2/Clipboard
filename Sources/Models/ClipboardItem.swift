import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var contentType: String
    var contentHash: String
    var text: String?
    var imageData: Data?
    var imageThumbnail: Data?
    var extractedText: String?  // OCR результат
    var url: String?
    var urlTitle: String?
    var sourceApp: String?
    var sourceAppBundleId: String?
    var isPassword: Bool
    var isFavorite: Bool
    var isDeleted: Bool
    var tags: [String]
    var category: String
    var detectedLanguage: String?
    var sentiment: Double
    var aiConfidence: Double
    var entitiesData: Data?  // JSON encoded [ExtractedEntity]
    var searchText: String?

    @Relationship(inverse: \Pinboard.items)
    var pinboard: Pinboard?

    init(
        id: UUID = UUID(),
        contentType: ContentType,
        contentHash: String,
        text: String? = nil,
        imageData: Data? = nil,
        url: String? = nil,
        sourceApp: String? = nil,
        sourceAppBundleId: String? = nil,
        isPassword: Bool = false
    ) {
        self.id = id
        self.createdAt = Date()
        self.updatedAt = Date()
        self.contentType = contentType.rawValue
        self.contentHash = contentHash
        self.text = text
        self.imageData = imageData
        self.url = url
        self.sourceApp = sourceApp
        self.sourceAppBundleId = sourceAppBundleId
        self.isPassword = isPassword
        self.isFavorite = false
        self.isDeleted = false
        self.tags = []
        self.category = "uncategorized"
        self.sentiment = 0.0
        self.aiConfidence = 0.5
    }

    var type: ContentType {
        get { ContentType(rawValue: contentType) ?? .unknown }
        set { contentType = newValue.rawValue }
    }

    var entities: [ExtractedEntity] {
        get {
            guard let data = entitiesData else { return [] }
            return (try? JSONDecoder().decode([ExtractedEntity].self, from: data)) ?? []
        }
        set {
            entitiesData = try? JSONEncoder().encode(newValue)
        }
    }

    var previewText: String {
        switch type {
        case .text, .richText: return text ?? ""
        case .url: return url ?? urlTitle ?? ""
        case .image: return "[Image]"
        case .code: return text ?? ""
        case .email: return text ?? ""
        case .phoneNumber: return text ?? ""
        case .color: return text ?? ""
        case .password: return "••••••••"
        case .unknown: return text ?? "Unknown"
        }
    }

    var displayTitle: String {
        switch type {
        case .url: return urlTitle ?? URL(string: url ?? "")?.host() ?? "Link"
        case .image: return "Screenshot"
        case .code: return "Code Snippet"
        case .password: return "Password"
        default:
            let preview = String((text ?? "").prefix(50))
            return preview.isEmpty ? "Empty" : preview
        }
    }
}

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
