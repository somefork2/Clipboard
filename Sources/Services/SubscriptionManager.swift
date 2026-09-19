import AppKit
import Foundation
import Observation
import StoreKit

enum SubscriptionTier: String, CaseIterable {
    case free, pro

    /// How far back the free tier keeps history.
    ///
    /// Replaces the old cap of 100 clips, which ran out in a couple of days and
    /// stopped the app being useful exactly when the habit was still forming. An
    /// age limit degrades instead of blocking: recent clips always work, and the
    /// day someone needs something older is the day a subscription makes sense.
    var historyWindow: TimeInterval? { self == .free ? 48 * 60 * 60 : nil }

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
        case .unlimitedHistory: return String(localized: "Unlimited History")
        case .unlimitedPinboards: return String(localized: "Unlimited Pinboards")
        case .pasteStack: return String(localized: "Paste Stack")
        case .smartCategorize: return String(localized: "Smart Categorisation")
        case .exportImport: return String(localized: "Export")
        case .cloudSync: return String(localized: "iCloud Sync")
        case .customShortcuts: return String(localized: "Custom Shortcuts")
        case .statistics: return String(localized: "Statistics")
        case .autoCleanup: return String(localized: "Auto Cleanup")
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
        case .unlimitedHistory: return String(localized: "Keep everything, instead of only the last 48 hours.")
        case .unlimitedPinboards: return String(localized: "Organise clips into as many boards as you need.")
        case .pasteStack: return String(localized: "Queue several clips and paste them one after another.")
        case .smartCategorize: return String(localized: "On-device analysis tags clips by type, language and entities.")
        case .exportImport: return String(localized: "Save your history as JSON, CSV, Markdown or HTML.")
        case .cloudSync: return String(localized: "Sync history across your Macs through your private iCloud database.")
        case .customShortcuts: return String(localized: "Rebind every global shortcut to whatever you prefer.")
        case .statistics: return String(localized: "See what you copy most and from which apps.")
        case .autoCleanup: return String(localized: "Automatically remove clips older than a chosen age.")
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

    /// True while the 30-day trial is running.
    var isInFreeTrial: Bool { TrialManager.shared.isActive }

    /// Everything is unlocked while the trial runs, without anyone having to
    /// subscribe first.
    var hasFullAccess: Bool { isPro || isInFreeTrial }

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
            lastError = String(localized: "Could not reach the App Store. Check your connection and try again.")
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

    /// What came back from a purchase attempt.
    ///
    /// Returned rather than only left in `lastError` so callers — and tests —
    /// can tell "the customer changed their mind" apart from "the purchase
    /// broke", which look identical when the only signal is an empty error.
    enum PurchaseOutcome: Equatable {
        case purchased
        case cancelled
        case pending
        case unverified
        case unavailable
        case failed(String)
    }

    @discardableResult
    func purchase(_ productID: String) async -> PurchaseOutcome {
        guard let product = product(for: productID) else {
            lastError = String(localized: "That plan is unavailable right now.")
            return .unavailable
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement(justPurchased: transaction)
                    showingPaywall = false
                    lastError = nil
                    return .purchased
                }
                lastError = String(localized: "This purchase could not be verified.")
                return .unverified
            case .userCancelled:
                lastError = nil
                return .cancelled
            case .pending:
                lastError = String(localized: "Your purchase is pending approval.")
                return .pending
            @unknown default:
                return .failed("Unknown purchase result.")
            }
        } catch {
            lastError = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    /// Required by App Review: users must be able to restore purchases.
    func restorePurchases() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            lastError = isPro ? nil : String(localized: "No active subscription was found for this Apple Account.")
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

    /// Re-reads what the customer is entitled to, straight from StoreKit.
    ///
    /// `justPurchased` is not a convenience. `Transaction.currentEntitlements`
    /// does not reliably include a transaction that was finished a moment ago,
    /// so refreshing immediately after a successful purchase could leave the app
    /// on the free tier until the next launch — money taken, nothing unlocked.
    /// The verified transaction handed to us by `purchase()` is authoritative,
    /// so it is folded in alongside whatever the store reports.
    func refreshEntitlement(justPurchased: StoreKit.Transaction? = nil) async {
        var tier: SubscriptionTier = .free
        var productID: String?
        var expiry: Date?
        var trial = false

        func consider(_ transaction: StoreKit.Transaction) {
            guard Self.productIDs.contains(transaction.productID) else { return }
            if let revocation = transaction.revocationDate, revocation <= Date() { return }
            if let expiration = transaction.expirationDate, expiration <= Date() { return }

            // Keep the entitlement that runs longest, so an upgrade mid-term is
            // never shortened by an older overlapping one.
            if let current = expiry, let candidate = transaction.expirationDate, candidate <= current {
                return
            }

            tier = .pro
            productID = transaction.productID
            expiry = transaction.expirationDate
            if #available(macOS 15.0, *) {
                trial = transaction.offer?.type == .introductory
            }
        }

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            consider(transaction)
        }
        if let justPurchased { consider(justPurchased) }

        currentTier = tier
        activeProductID = productID
        expirationDate = expiry
        isInTrial = trial
    }

    // MARK: - Gating

    func checkAccess(for feature: PremiumFeature) -> Bool { hasFullAccess }

    var statusDescription: String {
        #if DEBUG
        if simulatedPro { return "Pro (simulated for development)" }
        #endif
        if isInTrial { return String(localized: "Pro — subscription trial") }
        if isPro { return String(localized: "Pro") }
        if isInFreeTrial { return "Trial — \(TrialManager.shared.daysRemaining) days left" }
        return String(localized: "Free")
    }

    /// Returns true when the feature may be used; otherwise surfaces the paywall.
    @discardableResult
    func requestAccess(for feature: PremiumFeature) -> Bool {
        if checkAccess(for: feature) { return true }
        showingPaywall = true
        return false
    }

    /// `nil` means unlimited.
    var historyWindow: TimeInterval? {
        hasFullAccess ? nil : SubscriptionTier.free.historyWindow
    }

    var pinboardLimit: Int { hasFullAccess ? -1 : SubscriptionTier.free.maxPinboards }
}

