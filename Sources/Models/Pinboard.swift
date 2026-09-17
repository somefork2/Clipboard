import Foundation
import SwiftData

@Model
final class Pinboard {
    var id: UUID
    var name: String
    var icon: String
    var color: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade)
    var items: [ClipboardItem]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "pin",
        color: String = "blue"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortOrder = 0
        self.items = []
    }
}
