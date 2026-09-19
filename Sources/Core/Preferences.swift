import Foundation
import SwiftUI

/// How large the interface text is drawn.
///
/// The app uses semantic text styles throughout, so one Dynamic Type setting
/// scales every label, and the row metrics follow it — otherwise larger text
/// would simply be clipped by fixed-height rows.
enum TextSizePreference: String, CaseIterable, Identifiable, Codable {
    case small
    case standard
    case large
    case larger
    case largest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return String(localized: "Small")
        case .standard: return String(localized: "Standard")
        case .large: return String(localized: "Large")
        case .larger: return String(localized: "Larger")
        case .largest: return String(localized: "Largest")
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .standard: return .medium
        case .large: return .large
        case .larger: return .xLarge
        case .largest: return .accessibility1
        }
    }

    /// Multiplier applied to fixed metrics such as row height and icon size.
    var metricScale: CGFloat {
        switch self {
        case .small: return 0.92
        case .standard: return 1.0
        case .large: return 1.12
        case .larger: return 1.26
        case .largest: return 1.5
        }
    }
}

/// How long history is kept.
///
/// Two different questions people ask — "how many clips" and "how old" — so the
/// setting asks which one matters to them rather than silently applying both.
/// Favourites and anything filed on a pinboard are never dropped.
enum RetentionPolicy: Codable, Hashable, Identifiable {
    case count(Int)
    case days(Int)
    case forever

    var id: String {
        switch self {
        case .count(let n): return "count-\(n)"
        case .days(let n): return "days-\(n)"
        case .forever: return "forever"
        }
    }

    static let presets: [RetentionPolicy] = [
        .count(100), .count(500), .count(1_000), .count(5_000),
        .days(1), .days(7), .days(30), .days(90),
        .forever
    ]

    var displayName: String {
        switch self {
        case .count(let n):
            return "Last \(n.formatted()) clips"
        case .days(let n):
            return n == 1 ? String(localized: "Last 24 hours") : String(localized: "Last \(n) days")
        case .forever:
            return String(localized: "Keep everything")
        }
    }

    var explanation: String {
        switch self {
        case .count(let n):
            return "Once there are more than \(n.formatted()) clips, the oldest are removed."
        case .days(let n):
            return n == 1
                ? String(localized: "Clips older than a day are removed.")
                : "Clips older than \(n) days are removed."
        case .forever:
            return String(localized: "Nothing is removed automatically. The database grows until you clear it.")
        }
    }

    /// The free tier keeps a fixed window of recent history, so choosing any
    /// policy at all is a paid choice.
    var requiresPro: Bool { true }

    // MARK: Persistence

    private static let key = "retention_policy"

    static func load() -> RetentionPolicy {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(RetentionPolicy.self, from: data) else {
            return .count(1_000)
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
