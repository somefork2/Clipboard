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
        case .text: return "doc.text.fill"
        case .richText: return "doc.richtext.fill"
        case .url: return "link.badge.plus"
        case .email: return "envelope.fill"
        case .phoneNumber: return "phone.circle.fill"
        case .image: return "photo.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette.fill"
        case .password: return "lock.fill"
        case .unknown: return "questionmark.circle.fill"
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
