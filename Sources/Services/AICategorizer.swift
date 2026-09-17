import Foundation

struct AICategorizer {
    static func categorize(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("func ") || lowercased.contains("var ") || lowercased.contains("class ") { return "code" }
        if lowercased.contains("http") || lowercased.contains("www.") { return "links" }
        if lowercased.contains("@") && lowercased.contains(".") { return "contacts" }
        if text.count > 200 { return "notes" }
        return "text"
    }

    static func suggestTitle(for text: String, type: ContentType) -> String {
        switch type {
        case .url: return URL(string: text)?.host() ?? "Link"
        case .email: return "Email: \(text)"
        case .phoneNumber: return "Phone: \(text)"
        case .code: return "Code Snippet"
        case .image: return "Screenshot"
        default: let words = text.prefix(30); return String(words) + (text.count > 30 ? "..." : "")
        }
    }

    static func extractTags(from text: String) -> [String] {
        var tags: [String] = []
        let lowercased = text.lowercased()
        if lowercased.contains("todo") || lowercased.contains("задача") { tags.append("todo") }
        if lowercased.contains("meeting") || lowercased.contains("встреча") { tags.append("meeting") }
        if lowercased.contains("password") || lowercased.contains("пароль") { tags.append("sensitive") }
        return tags
    }
}
