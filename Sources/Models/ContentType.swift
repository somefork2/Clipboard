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
        case .text: return "Text"
        case .richText: return "Rich Text"
        case .url: return "Link"
        case .email: return "Email"
        case .phoneNumber: return "Phone"
        case .image: return "Image"
        case .code: return "Code"
        case .color: return "Color"
        case .password: return "Password"
        case .unknown: return "Unknown"
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
