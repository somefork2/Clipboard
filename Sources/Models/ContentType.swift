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
        case .text: return L("Text")
        case .richText: return L("Rich Text")
        case .url: return L("Link")
        case .email: return L("Email")
        case .phoneNumber: return L("Phone")
        case .image: return L("Image")
        case .code: return L("Code")
        case .color: return L("Colour")
        case .password: return L("Password")
        case .unknown: return L("Unknown")
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
