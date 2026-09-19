import Foundation

enum ContentType: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case url
    case email
    case phoneNumber
    case image
    case code
    case color
    case password
    case unknown

    var displayName: String {
        switch self {
        case .text: return String(localized: "Text")
        case .richText: return String(localized: "Rich Text")
        case .url: return String(localized: "Link")
        case .email: return String(localized: "Email")
        case .phoneNumber: return String(localized: "Phone")
        case .image: return String(localized: "Image")
        case .code: return String(localized: "Code")
        case .color: return String(localized: "Color")
        case .password: return String(localized: "Password")
        case .unknown: return String(localized: "Unknown")
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .url: return "link"
        case .email: return "envelope"
        case .phoneNumber: return "phone"
        case .image: return "photo"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        case .password: return "lock"
        case .unknown: return "questionmark.circle"
        }
    }
}
