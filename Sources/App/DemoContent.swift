#if DEBUG
import Foundation
import SwiftData

/// Sample history used for App Store screenshots.
///
/// Screenshots must never show a real person's clipboard, so demo mode runs
/// against a separate in-memory store and the clipboard monitor stays off. The
/// content below is invented, and chosen to look like an ordinary working day.
enum DemoContent {
    static var isActive: Bool { CommandLine.arguments.contains("--demo-content") }

    struct Sample {
        let type: ContentType
        let text: String
        let app: String
        let minutesAgo: Int
        var url: String? = nil
        var favourite: Bool = false
        var category: String = "uncategorized"
        var tags: [String] = []
    }

    static let samples: [Sample] = [
        Sample(type: .code,
               text: "let total = items.reduce(0) { $0 + $1.amount }",
               app: "Xcode", minutesAgo: 1, category: "code", tags: ["Swift"]),
        Sample(type: .url,
               text: "https://developer.apple.com/documentation/swiftui/imagerenderer",
               app: "Safari", minutesAgo: 4,
               url: "https://developer.apple.com/documentation/swiftui/imagerenderer",
               category: "links"),
        Sample(type: .email,
               text: "dana.whitfield@northstarlabs.com",
               app: "Mail", minutesAgo: 9, category: "contacts", tags: ["Email"]),
        Sample(type: .text,
               text: "Thanks for the quick turnaround — the revised figures are attached, and I have signed off on the Q3 numbers.",
               app: "Slack", minutesAgo: 14),
        Sample(type: .text,
               text: "Northstar Labs\n144 Bridge Street, Suite 12\nEdinburgh EH1 2QN",
               app: "Notes", minutesAgo: 22, favourite: true, category: "addresses"),
        Sample(type: .color,
               text: "#2F6FED",
               app: "Figma", minutesAgo: 31, category: "code"),
        Sample(type: .text,
               text: "Invoice 2026-0418 · Due 30 September · £4,250.00",
               app: "Numbers", minutesAgo: 47, tags: ["Money", "Date"]),
        Sample(type: .url,
               text: "https://github.com/northstar/ledger/pull/318",
               app: "Safari", minutesAgo: 58,
               url: "https://github.com/northstar/ledger/pull/318",
               category: "links"),
        Sample(type: .code,
               text: "docker compose up --build -d",
               app: "Terminal", minutesAgo: 71, category: "code"),
        Sample(type: .phoneNumber,
               text: "+44 131 496 0912",
               app: "Contacts", minutesAgo: 96, category: "contacts", tags: ["Phone"]),
        Sample(type: .text,
               text: "Kind regards,\nAlex Everett\nHead of Product, Northstar Labs",
               app: "Mail", minutesAgo: 120, favourite: true),
        Sample(type: .text,
               text: "The meeting moved to Thursday at 15:00. Same room.",
               app: "Messages", minutesAgo: 155),
    ]

    /// Fills a fresh context with the sample history and two pinboards.
    @MainActor
    static func seed(into context: ModelContext) {
        let snippets = Pinboard(name: "Snippets", icon: "chevron.left.forwardslash.chevron.right", color: "purple")
        snippets.sortOrder = 0
        let replies = Pinboard(name: "Replies", icon: "text.bubble", color: "teal")
        replies.sortOrder = 1
        context.insert(snippets)
        context.insert(replies)

        for (index, sample) in samples.enumerated() {
            let item = ClipboardItem(
                contentType: sample.type,
                contentHash: ContentHasher.hash(text: sample.text, url: sample.url, imageData: nil),
                text: sample.text,
                url: sample.url,
                sourceApp: sample.app,
                sourceAppBundleId: nil
            )
            let moment = Date().addingTimeInterval(-Double(sample.minutesAgo) * 60)
            item.createdAt = moment
            item.updatedAt = moment
            item.isFavorite = sample.favourite
            item.category = sample.category
            item.tags = sample.tags
            item.useCount = max(0, 9 - index)
            if sample.app == "Xcode" || sample.app == "Terminal" { item.pinboard = snippets }
            if index == 10 { item.pinboard = replies }
            context.insert(item)
        }
        try? context.save()
    }
}
#endif
