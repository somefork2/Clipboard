import AppKit
import Foundation
import Observation
import StoreKit

enum SubscriptionTier: String, CaseIterable {
    case free, pro

    /// `-1` means unlimited.
    var maxItems: Int { self == .free ? 100 : -1 }
    var maxPinboards: Int { self == .free ? 1 : -1 }
}

enum PremiumFeature: String, CaseIterable, Identifiable {
    case unlimitedHistory
    case unlimitedPinboards
    case pasteStack
    case smartCategorize
    case exportImport
    case cloudSync
    case customShortcuts
    case statistics
    case autoCleanup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedHistory: return "Unlimited History"
        case .unlimitedPinboards: return "Unlimited Pinboards"
        case .pasteStack: return "Paste Stack"
        case .smartCategorize: return "Smart Categorisation"
        case .exportImport: return "Export"
        case .cloudSync: return "iCloud Sync"
        case .customShortcuts: return "Custom Shortcuts"
        case .statistics: return "Statistics"
        case .autoCleanup: return "Auto Cleanup"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedHistory: return "clock.arrow.circlepath"
        case .unlimitedPinboards: return "pin"
        case .pasteStack: return "square.stack"
        case .smartCategorize: return "tag"
        case .exportImport: return "square.and.arrow.up"
        case .cloudSync: return "icloud"
        case .customShortcuts: return "command"
        case .statistics: return "chart.bar"
        case .autoCleanup: return "trash"
        }
    }

    /// Plain, checkable claims — every one of these is implemented.
    var summary: String {
        switch self {
        case .unlimitedHistory: return "Keep more than the free tier's 100 most recent clips."
        case .unlimitedPinboards: return "Organise clips into as many boards as you need."
        case .pasteStack: return "Queue several clips and paste them one after another."
        case .smartCategorize: return "On-device analysis tags clips by type, language and entities."
        case .exportImport: return "Save your history as JSON, CSV, Markdown or HTML."
        case .cloudSync: return "Sync history across your Macs through your private iCloud database."
        case .customShortcuts: return "Rebind every global shortcut to whatever you prefer."
        case .statistics: return "See what you copy most and from which apps."
        case .autoCleanup: return "Automatically remove clips older than a chosen age."
        }
    }
}

/// StoreKit 2 subscription handling.
///
/// Entitlement is derived from `Transaction.currentEntitlement` on every launch
/// and kept current by the `Transaction.updates` listener, so expiry, refunds
/// and family sharing changes all take effect without a relaunch.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    static let monthlyID = "com.copywell.pro.monthly"
    static let annualID = "com.copywell.pro.annual"
    static let productIDs = [monthlyID, annualID]

    private(set) var products: [Product] = []
    private(set) var currentTier: SubscriptionTier = .free
    private(set) var activeProductID: String?
    private(set) var expirationDate: Date?
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight = false
    private(set) var lastError: String?

    var showingPaywall = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    private init() {}

    #if DEBUG
    /// Unlocks everything in a development build, so the paid experience can be
    /// looked at before the products exist in App Store Connect.
    ///
    /// Compiled out of release entirely: there is no runtime flag, no hidden
    /// preference and no code path in the shipping app that can reach it.
    var simulatedPro: Bool = UserDefaults.standard.bool(forKey: "debug_simulated_pro") {
        didSet { UserDefaults.standard.set(simulatedPro, forKey: "debug_simulated_pro") }
    }

    var isPro: Bool { simulatedPro || currentTier == .pro }
    #else
    var isPro: Bool { currentTier == .pro }
    #endif

    /// True only when the active subscription is still inside its introductory
    /// free-trial period. Never assumed — StoreKit tells us.
    private(set) var isInTrial = false

    func start() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Products

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            // Keep a stable order: monthly first, annual second.
            products = loaded.sorted { lhs, rhs in
                (lhs.id == Self.monthlyID ? 0 : 1) < (rhs.id == Self.monthlyID ? 0 : 1)
            }
            lastError = nil
        } catch {
            products = []
            lastError = "Could not reach the App Store. Check your connection and try again."
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    /// Localised price string straight from the App Store — never hard-coded.
    func displayPrice(for id: String) -> String {
        product(for: id)?.displayPrice ?? "—"
    }

    /// Introductory offer description, when the product actually has one.
    func introductoryOffer(for id: String) -> String? {
        guard let offer = product(for: id)?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let unit: String
        switch offer.period.unit {
        case .day: unit = offer.period.value == 1 ? "day" : "days"
        case .week: unit = offer.period.value == 1 ? "week" : "weeks"
        case .month: unit = offer.period.value == 1 ? "month" : "months"
        case .year: unit = offer.period.value == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return "\(offer.period.value) \(unit) free"
    }

    /// Savings of the annual plan versus twelve monthly payments, computed from
    /// live App Store prices rather than a hard-coded badge.
    var annualSavingsPercent: Int? {
        guard let monthly = product(for: Self.monthlyID),
              let annual = product(for: Self.annualID) else { return nil }
        let yearlyAtMonthlyRate = monthly.price * Decimal(12)
        guard yearlyAtMonthlyRate > 0, annual.price < yearlyAtMonthlyRate else { return nil }
        let ratio = (yearlyAtMonthlyRate - annual.price) / yearlyAtMonthlyRate
        let percent = NSDecimalNumber(decimal: ratio * Decimal(100)).doubleValue
        return Int(percent.rounded())
    }

    // MARK: - Purchase

    func purchase(_ productID: String) async {
        guard let product = product(for: productID) else {
            lastError = "That plan is unavailable right now."
            return
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                    showingPaywall = false
                } else {
                    lastError = "This purchase could not be verified."
                }
            case .userCancelled:
                lastError = nil
            case .pending:
                lastError = "Your purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Required by App Review: users must be able to restore purchases.
    func restorePurchases() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            lastError = isPro ? nil : "No active subscription was found for this Apple Account."
        } catch {
            lastError = error.localizedDescription
        }
    }

    func showManageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        var tier: SubscriptionTier = .free
        var productID: String?
        var expiry: Date?
        var trial = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            if let revocation = transaction.revocationDate, revocation <= Date() { continue }
            if let expiration = transaction.expirationDate, expiration <= Date() { continue }

            tier = .pro
            productID = transaction.productID
            expiry = transaction.expirationDate
            if #available(macOS 15.0, *) {
                trial = transaction.offer?.type == .introductory
            }
        }

        currentTier = tier
        activeProductID = productID
        expirationDate = expiry
        isInTrial = trial
    }

    // MARK: - Gating

    func checkAccess(for feature: PremiumFeature) -> Bool { isPro }

    #if DEBUG
    var statusDescription: String {
        if simulatedPro { return "Pro (simulated for development)" }
        if isInTrial { return "Pro — free trial" }
        return isPro ? "Pro" : "Free"
    }
    #else
    var statusDescription: String {
        if isInTrial { return "Pro — free trial" }
        return isPro ? "Pro" : "Free"
    }
    #endif

    /// Returns true when the feature may be used; otherwise surfaces the paywall.
    @discardableResult
    func requestAccess(for feature: PremiumFeature) -> Bool {
        if checkAccess(for: feature) { return true }
        showingPaywall = true
        return false
    }

    var historyLimit: Int { currentTier.maxItems }
    var pinboardLimit: Int { currentTier.maxPinboards }
}

