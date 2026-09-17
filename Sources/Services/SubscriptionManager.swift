import Foundation

enum SubscriptionTier: String, CaseIterable {
    case free, pro

    var maxItems: Int { switch self { case .free: return 100; case .pro: return -1 } }
    var maxPinboards: Int { switch self { case .free: return 1; case .pro: return -1 } }
}

enum PremiumFeature: String, CaseIterable, Identifiable {
    case clipboardHistory, basicSearch, onePinboard, unlimitedPinboards
    case pasteStack, aiCategorize, aiSearch, exportImport
    case customThemes, statistics, keyboardShortcuts, autoCleanup

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .clipboardHistory: return "clock.arrow.circlepath"
        case .basicSearch: return "magnifyingglass"
        case .onePinboard: return "pin"
        case .unlimitedPinboards: return "pin.fill"
        case .pasteStack: return "rectangle.stack"
        case .aiCategorize: return "brain.head.profile"
        case .aiSearch: return "sparkle.magnifyingglass"
        case .exportImport: return "arrow.up.arrow.down"
        case .customThemes: return "paintpalette.fill"
        case .statistics: return "chart.bar.fill"
        case .keyboardShortcuts: return "command"
        case .autoCleanup: return "trash.clock"
        }
    }

    var description: String {
        switch self {
        case .clipboardHistory: return "Save every clip without limits"
        case .basicSearch: return "Find clips by text"
        case .onePinboard: return "1 pinboard for important items"
        case .unlimitedPinboards: return "Create as many pinboards as you want"
        case .pasteStack: return "Queue items for sequential paste"
        case .aiCategorize: return "Auto-tag and categorize your clips"
        case .aiSearch: return "Search with natural language"
        case .exportImport: return "Export history to JSON/CSV/Markdown"
        case .customThemes: return "Dark, Light, or custom color themes"
        case .statistics: return "See your clipboard usage analytics"
        case .keyboardShortcuts: return "Customize all keyboard shortcuts"
        case .autoCleanup: return "Auto-delete old clips by rules"
        }
    }
}

@Observable
final class SubscriptionManager {
    var currentTier: SubscriptionTier = .free
    var showingPaywall = false
    var trialEndDate: Date?

    static let shared = SubscriptionManager()

    var isPro: Bool { currentTier == .pro }
    var isInTrial: Bool { guard let end = trialEndDate else { return false }; return Date() < end }
    var hasAccess: Bool { isPro || isInTrial }

    func checkAccess(for feature: PremiumFeature) -> Bool {
        if hasAccess { return true }
        switch feature {
        case .clipboardHistory, .basicSearch, .onePinboard: return true
        default: return false
        }
    }

    func requestAccess(for feature: PremiumFeature) -> Bool {
        if checkAccess(for: feature) { return true }
        showingPaywall = true
        return false
    }

    func startTrial() {
        trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        currentTier = .pro
    }

    func subscribe() { currentTier = .pro }
}
