import AppKit
import Observation
import SwiftUI

/// A theme's colour tokens.
///
/// Each custom theme pins the system appearance it is built for, so system label
/// colours, controls and focus rings keep their correct contrast; only the
/// surfaces and the accent are ours. That is what keeps these themes readable
/// rather than a set of coloured backgrounds with unreadable text on top.
struct ThemePalette {
    /// `nil` follows the system setting.
    let appearance: NSAppearance.Name?
    /// Window and list background.
    let background: Color
    /// Rows, badges, wells.
    let surface: Color
    /// Floating surfaces: the palette panel and the menu bar popover.
    let elevated: Color
    let separator: Color
    /// The accent used when the user has not chosen one.
    let accent: Color
    /// Whether the app draws its own surfaces or defers to system materials.
    let usesSystemMaterials: Bool
}

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: AppTheme = .system {
        didSet {
            persist()
            Task { @MainActor in self.applyStoredTheme() }
        }
    }

    /// `nil` means "whatever the theme suggests".
    var accentColorName: String? {
        didSet { persist() }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: raw) {
            currentTheme = theme
        }
        accentColorName = UserDefaults.standard.string(forKey: "accent_color")
    }

    var palette: ThemePalette { currentTheme.palette }

    var accentColor: Color {
        if let accentColorName { return .named(accentColorName) }
        return palette.accent
    }

    @MainActor
    func applyStoredTheme() {
        let palette = self.palette

        // Deliberately not `NSApp.appearance`: that also covers the menu bar
        // item, which lives in the system's own menu bar. Forcing it to light
        // while the menu bar is dark drew a pale chip behind our icon while
        // every other icon sat flat. The appearance is applied per window.
        NSApp.appearance = nil

        let appearance = palette.appearance.map { NSAppearance(named: $0) } ?? nil
        for window in NSApp.windows where !Self.isSystemOwned(window) {
            window.appearance = appearance
            // The title bar is drawn by AppKit, so a themed window has to be
            // told which colour to use or the toolbar floats on another shade.
            window.backgroundColor = palette.usesSystemMaterials ? nil : NSColor(palette.background)
        }
    }

    /// The status item's button is hosted in a window the system owns; theming
    /// it is both wrong and visible.
    private static func isSystemOwned(_ window: NSWindow) -> Bool {
        window.level == .statusBar || window.className.contains("NSStatusBar")
    }

    private func persist() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        if let accentColorName {
            UserDefaults.standard.set(accentColorName, forKey: "accent_color")
        } else {
            UserDefaults.standard.removeObject(forKey: "accent_color")
        }
    }

    static let accentOptions = ["blue", "purple", "indigo", "teal", "green", "orange", "red", "pink", "graphite"]
}

enum AppTheme: String, CaseIterable, Identifiable {
    /// Follows the macOS appearance setting.
    case system
    case light
    case dark
    /// Warm off-white, for long reading sessions.
    case paper
    /// Neutral grey; no colour cast at all.
    case graphite
    /// Cool blue-grey.
    case slate
    /// Near-black with a muted brass accent.
    case ink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .paper: return "Paper"
        case .graphite: return "Graphite"
        case .slate: return "Slate"
        case .ink: return "Ink"
        }
    }

    var summary: String {
        switch self {
        case .system: return "Follows your macOS appearance setting."
        case .light: return "Always light."
        case .dark: return "Always dark."
        case .paper: return "Warm off-white, easier on the eyes in daylight."
        case .graphite: return "Neutral dark grey with no colour cast."
        case .slate: return "Cool blue-grey dark."
        case .ink: return "Near-black with a muted brass accent."
        }
    }

    var isCustom: Bool {
        switch self {
        case .system, .light, .dark: return false
        default: return true
        }
    }

    var palette: ThemePalette {
        switch self {
        case .system:
            return .systemPalette(appearance: nil)
        case .light:
            return .systemPalette(appearance: .aqua)
        case .dark:
            return .systemPalette(appearance: .darkAqua)
        case .paper:
            return ThemePalette(
                appearance: .aqua,
                background: Color(hex: "F4F1EA"),
                surface: Color(hex: "FBF9F4"),
                elevated: Color(hex: "FDFCF8"),
                separator: Color(hex: "DED7C8"),
                accent: Color(hex: "3D5A80"),
                usesSystemMaterials: false
            )
        case .graphite:
            return ThemePalette(
                appearance: .darkAqua,
                background: Color(hex: "1B1B1D"),
                surface: Color(hex: "242426"),
                elevated: Color(hex: "2B2B2E"),
                separator: Color(hex: "3A3A3D"),
                accent: Color(hex: "9AA0A6"),
                usesSystemMaterials: false
            )
        case .slate:
            return ThemePalette(
                appearance: .darkAqua,
                background: Color(hex: "191E25"),
                surface: Color(hex: "212832"),
                elevated: Color(hex: "27303B"),
                separator: Color(hex: "343E4B"),
                accent: Color(hex: "6E93C8"),
                usesSystemMaterials: false
            )
        case .ink:
            return ThemePalette(
                appearance: .darkAqua,
                background: Color(hex: "0D0D0F"),
                surface: Color(hex: "161618"),
                elevated: Color(hex: "1C1C1F"),
                separator: Color(hex: "2A2A2E"),
                accent: Color(hex: "B99A63"),
                usesSystemMaterials: false
            )
        }
    }
}

private extension ThemePalette {
    /// Defers entirely to AppKit's own colours, which already adapt to light and
    /// dark and to the user's accent and contrast settings.
    static func systemPalette(appearance: NSAppearance.Name?) -> ThemePalette {
        ThemePalette(
            appearance: appearance,
            background: Color(nsColor: .windowBackgroundColor),
            surface: Color(nsColor: .controlBackgroundColor),
            elevated: Color(nsColor: .controlBackgroundColor),
            separator: Color(nsColor: .separatorColor),
            accent: Color(nsColor: .controlAccentColor),
            usesSystemMaterials: true
        )
    }
}
