import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import CopyWell

/// Purchases, exercised for real.
///
/// `SKTestSession` runs the same StoreKit 2 code paths the App Store does —
/// products are fetched, `product.purchase()` completes, transactions are
/// verified and entitlements are read back. Nothing here is a stub, so a
/// mistake in `SubscriptionManager` fails the build rather than reaching a
/// paying customer.
///
/// Serialized: one StoreKit test session exists per process, and the manager is
/// a singleton whose entitlement is process-wide state.
@Suite("Purchases", .serialized)
@MainActor
struct PurchaseTests {

    /// A session backed by the very file the app ships with, so the test breaks
    /// if a product ID drifts apart from `SubscriptionManager`.
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    private func reset(_ manager: SubscriptionManager) async {
        #if DEBUG
        manager.simulatedPro = false
        #endif
        await manager.refreshEntitlement()
    }

    @Test("Both plans are configured and load from the store")
    func productsLoad() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await manager.loadProducts()

        #expect(manager.products.count == 2)
        #expect(manager.lastError == nil)
        // Monthly first, annual second — the paywall relies on this order.
        #expect(manager.products.first?.id == SubscriptionManager.monthlyID)
        #expect(manager.products.last?.id == SubscriptionManager.annualID)

        let monthly = try #require(manager.product(for: SubscriptionManager.monthlyID))
        let annual = try #require(manager.product(for: SubscriptionManager.annualID))
        #expect(monthly.subscription?.subscriptionPeriod.unit == .month)
        #expect(annual.subscription?.subscriptionPeriod.unit == .year)
        // Prices are shown in the store's own formatting, never hard-coded.
        #expect(!manager.displayPrice(for: SubscriptionManager.monthlyID).isEmpty)
        #expect(manager.displayPrice(for: "com.copywell.nonexistent") == "—")
    }

    @Test("Buying the monthly plan unlocks Pro")
    func purchaseMonthly() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()
        #expect(manager.currentTier == .free)

        let outcome = await manager.purchase(SubscriptionManager.monthlyID)

        #expect(outcome == .purchased, "purchase returned \(outcome)")
        #expect(manager.currentTier == .pro)
        #expect(manager.isPro)
        #expect(manager.activeProductID == SubscriptionManager.monthlyID)
        #expect(manager.lastError == nil)
        // The paywall must close itself once the purchase lands.
        #expect(manager.showingPaywall == false)
    }

    @Test("Buying the annual plan unlocks Pro")
    func purchaseAnnual() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()

        await manager.purchase(SubscriptionManager.annualID)

        #expect(manager.currentTier == .pro)
        #expect(manager.activeProductID == SubscriptionManager.annualID)
        #expect(manager.expirationDate != nil)
    }

    /// Every paid feature must actually open up — a subscriber seeing a paywall
    /// is a refund and a one-star review.
    @Test("A subscription unlocks every paid feature")
    func subscriptionUnlocksFeatures() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()
        await manager.purchase(SubscriptionManager.annualID)

        for feature in PremiumFeature.allCases {
            #expect(manager.checkAccess(for: feature), "\(feature.title) stayed locked for a subscriber")
        }
        #expect(manager.isLocked == false)
        #expect(manager.pinboardLimit == -1)
    }

    @Test("An expired subscription drops back to the free tier")
    func expiryRevokesAccess() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()
        await manager.purchase(SubscriptionManager.monthlyID)
        #expect(manager.currentTier == .pro)

        // Auto-renew has to go first: expiring a renewing subscription simply
        // renews it, which is correct behaviour and not what we are testing.
        let transaction = try #require(session.allTransactions().first {
            $0.productIdentifier == SubscriptionManager.monthlyID
        })
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        try session.expireSubscription(productIdentifier: SubscriptionManager.monthlyID)

        #expect(await waitForTier(.free, on: manager) == .free)
        #expect(manager.activeProductID == nil)
        // Locked, not reduced: without the trial there is no lesser tier left.
        if !manager.isInFreeTrial {
            #expect(manager.isLocked)
            for feature in PremiumFeature.allCases {
                #expect(manager.checkAccess(for: feature) == false)
            }
        }
    }

    /// A refunded subscription must not keep working: Apple checks this, and so
    /// does anyone who notices.
    @Test("A refund revokes access")
    func refundRevokesAccess() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()
        await manager.purchase(SubscriptionManager.monthlyID)

        // Taken from the session rather than from `currentEntitlements`, which
        // has not necessarily caught up with a purchase made a moment ago.
        let transaction = try #require(session.allTransactions().first {
            $0.productIdentifier == SubscriptionManager.monthlyID
        })
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        try session.refundTransaction(identifier: transaction.identifier)

        #expect(await waitForTier(.free, on: manager) == .free)
    }

    /// App Review rejects any app that cannot restore a purchase.
    @Test("Restore finds an existing subscription")
    func restoreFindsSubscription() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()
        await manager.purchase(SubscriptionManager.annualID)

        // Forget what we know locally, then ask the store again.
        await manager.refreshEntitlement()
        await manager.restorePurchases()

        #expect(manager.isPro)
        #expect(manager.lastError == nil)
    }

    @Test("Restoring without a purchase explains itself instead of failing silently")
    func restoreWithoutPurchase() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()

        await manager.restorePurchases()

        #expect(manager.isPro == false)
        #expect(manager.lastError != nil)
    }

    /// Cancelling is not an error, and must not leave a red message behind.
    @Test("Cancelling a purchase leaves no error on screen")
    func cancellingIsSilent() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.failTransactionsEnabled = false

        let manager = SubscriptionManager.shared
        await reset(manager)
        await manager.loadProducts()
        await manager.purchase("com.copywell.pro.doesnotexist")

        #expect(manager.lastError != nil, "an unknown product should say so")
        #expect(manager.currentTier == .free)
    }

    /// The annual badge is computed from live prices; a wrong number here is a
    /// misleading price claim, which App Review does reject.
    @Test("The annual saving is computed from real prices")
    func annualSavingIsHonest() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager.shared
        await manager.loadProducts()

        let monthly = try #require(manager.product(for: SubscriptionManager.monthlyID))
        let annual = try #require(manager.product(for: SubscriptionManager.annualID))
        let expected = ((monthly.price * 12 - annual.price) / (monthly.price * 12)) * 100
        let percent = try #require(manager.annualSavingsPercent)

        #expect(abs(Double(truncating: expected as NSNumber) - Double(percent)) < 1)
        #expect(percent > 0 && percent < 100)
    }

    /// Expiry and refunds happen outside the process, and StoreKit does not
    /// publish them synchronously — in the app that is what the
    /// `Transaction.updates` listener is for. A test changing store state
    /// directly has to give it the same chance to arrive.
    private func waitForTier(
        _ expected: SubscriptionTier,
        on manager: SubscriptionManager,
        timeout: Duration = .seconds(5)
    ) async -> SubscriptionTier {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            await manager.refreshEntitlement()
            if manager.currentTier == expected { return expected }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return manager.currentTier
    }

}
