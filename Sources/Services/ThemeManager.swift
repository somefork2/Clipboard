import AppKit
import Observation
import SwiftUI

/// Appearance preferences.
///
/// "Midnight" and "Neon" used to exist as separate themes that all resolved to
/// plain dark mode — three names for one behaviour. What is left is the choice
/// macOS actually has, plus an accent colour.
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: AppTheme = .system {
        didSet {
            persist()
            Task { @MainActor in self.applyStoredTheme() }
        }
    }
    var accentColorName: String = "blue" {
        didSet { persist() }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: raw) {
            currentTheme = theme
        }
        if let color = UserDefaults.standard.string(forKey: "accent_color") {
            accentColorName = color
        }
    }

    var accentColor: Color { .named(accentColorName) }

    @MainActor
    func applyStoredTheme() {
        switch currentTheme {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func persist() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(accentColorName, forKey: "accent_color")
    }

    static let accentOptions = ["blue", "purple", "indigo", "teal", "green", "orange", "red", "pink", "graphite"]
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}
