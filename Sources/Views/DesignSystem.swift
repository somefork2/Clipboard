import SwiftUI

/// Shared visual language.
///
/// The previous UI hard-coded ~200 point sizes and painted blue→purple gradients
/// on almost every surface, which reads as a phone game rather than a Mac
/// utility. Everything here is semantic: system text styles (so Dynamic Type and
/// accessibility settings work), system materials, and a single accent colour.
enum Theme {
    // MARK: Metrics

    enum Metric {
        static let rowHeight: CGFloat = 52
        static let compactRowHeight: CGFloat = 40
        static let corner: CGFloat = 6
        static let iconSize: CGFloat = 26
        static let gutter: CGFloat = 12
        static let sectionSpacing: CGFloat = 20
    }

    // MARK: Colours

    /// One accent, chosen by the user, applied through `.tint`.
    @MainActor
    static var accent: Color { ThemeManager.shared.accentColor }

    static let separator = Color(nsColor: .separatorColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let selection = Color(nsColor: .selectedContentBackgroundColor)
}

/// Monochrome type badge. Content type is conveyed by symbol and label, not by
/// a colour that carries no meaning.
struct TypeBadge: View {
    let type: ContentType
    var size: CGFloat = Theme.Metric.iconSize

    var body: some View {
        Image(systemName: type.systemImage)
            .font(.system(size: size * 0.5))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(Theme.secondaryBackground, in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
    }
}

/// Keycap rendering used in hints and the shortcuts table.
struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Theme.secondaryBackground, in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.separator, lineWidth: 0.5)
            )
    }
}

struct ShortcutHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            KeyCap(text: keys)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Empty states, consistent everywhere.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.link)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    /// Named accent colours offered in Settings.
    static func named(_ name: String) -> Color {
        switch name {
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        case "graphite": return .gray
        default: return .blue
        }
    }
}
