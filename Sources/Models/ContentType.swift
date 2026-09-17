import Foundation
import SwiftUI

enum ContentType: String, Codable, CaseIterable {
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

    var gradient: (Color, Color) {
        switch self {
        case .text: return (.blue, .cyan)
        case .richText: return (.purple, .pink)
        case .url: return (.indigo, .blue)
        case .email: return (.orange, .yellow)
        case .phoneNumber: return (.green, .mint)
        case .image: return (.pink, .red)
        case .code: return (.green, .teal)
        case .color: return (.purple, .indigo)
        case .password: return (.gray, .secondary)
        case .unknown: return (.secondary, .gray)
        }
    }
}
