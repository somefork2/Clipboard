import SwiftUI
import AppKit

@Observable
final class ThemeManager {
    var currentTheme: AppTheme = .system
    var accentColorName: String = "blue"

    static let shared = ThemeManager()

    init() {
        loadTheme()
    }

    var accentColor: Color {
        switch accentColorName {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .blue
        }
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        applyTheme()
        saveTheme()
    }

    func setAccentColor(_ colorName: String) {
        accentColorName = colorName
        saveTheme()
    }

    private func applyTheme() {
        switch currentTheme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .midnight:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .neon:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(accentColorName, forKey: "accent_color")
    }

    private func loadTheme() {
        if let raw = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: raw) {
            currentTheme = theme
        }
        if let color = UserDefaults.standard.string(forKey: "accent_color") {
            accentColorName = color
        }
        applyTheme()
    }
}

enum AppTheme: String, CaseIterable {
    case system, light, dark, midnight, neon

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .midnight: return "Midnight"
        case .neon: return "Neon"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .midnight: return "moon.stars.fill"
        case .neon: return "sparkles"
        }
    }
}
