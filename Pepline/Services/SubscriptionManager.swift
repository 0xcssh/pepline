import Foundation
import RevenueCat
import StoreKit

/// RevenueCat wrapper for Pepline Pro (ported from RepLock). Three products
/// in one App Store subscription group, all unlocking the `pepline_pro`
/// entitlement — prices in scripts/store.json, created by scripts/asc_admin.py:
/// - yearly $44.99 with a 7-day free trial (pre-selected),
/// - monthly $14.99, no trial,
/// - yearly offer $34.99 with a 7-day trial, shown once when the user cancels
///   Apple's payment sheet (ExitOfferView).
///
/// The paywalls never import RevenueCat: prices and titles are exposed as
/// pre-formatted strings.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    enum Plan: String { case yearly, monthly, exitOffer }

    enum PurchaseOutcome { case success, cancelled, failed }

    static let productIDs: [Plan: String] = [
        .yearly: "com.awdia.pepline.pro.yearly",
        .monthly: "com.awdia.pepline.pro.monthly",
        .exitOffer: "com.awdia.pepline.pro.yearly.offer",
    ]

    /// RevenueCat entitlement identifier; must match the dashboard exactly.
    static let entitlementID = "pepline_pro"

    /// RevenueCat PUBLIC SDK key: designed to ship inside the binary.
    private static let revenueCatAPIKey = "appl_dEELKElrptAkKrvAAbPAKwdrnaT"

    /// Plan highlighted on the paywall; yearly is the default.
    @Published var selectedPlan: Plan = .yearly

    @Published private(set) var isPro = false
    @Published private(set) var isLoading = true
    /// True once the first entitlement read has completed: until then the app
    /// shows a blank launch screen instead of flashing the paywall at a
    /// subscriber (RepLock field report).
    @Published private(set) var entitlementChecked = false
    @Published private(set) var willAutoRenew = true
    @Published private(set) var expirationDate: Date?

    @Published private var packages: [Plan: Package] = [:]

    private var customerInfoTask: Task<Void, Never>?
    private var storefrontTask: Task<Void, Never>?

    private init() {
        // Must run before any other Purchases access: `Purchases.shared` traps
        // when the SDK isn't configured.
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey)

        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        // TestFlight quirk (RepLock): products can resolve against the US
        // storefront before the first payment-sheet authentication. Reload
        // prices whenever the storefront becomes known or changes.
        // Must be qualified — RevenueCat ships its own `Storefront`.
        storefrontTask = Task { [weak self] in
            for await _ in StoreKit.Storefront.updates {
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    // MARK: - Display strings (the paywalls' only view of the store)

    func hasProduct(_ plan: Plan) -> Bool { packages[plan] != nil }

    private func product(_ plan: Plan) -> StoreProduct? { packages[plan]?.storeProduct }

    /// Subscription title, required visibly in the purchase flow (App Review
    /// 3.1.2(c), RepLock rejection 2026-07-14). Brand fallback before loading.
    func title(_ plan: Plan) -> String {
        if let name = product(plan)?.localizedTitle, !name.isEmpty { return name }
        return "Pepline Pro"
    }

    /// Billed price ("$44.99"), nil until loaded.
    func price(_ plan: Plan) -> String? { product(plan)?.localizedPriceString }

    /// Yearly price spread over 12 months ("$3.75"), for the small line only.
    func perMonth(_ plan: Plan) -> String? {
        guard let product = product(plan), let formatter = product.priceFormatter else { return nil }
        return formatter.string(from: (product.price / 12) as NSDecimalNumber)
    }

    /// Percent saved by the exit offer against the regular yearly price.
    var exitOfferPercent: Int? {
        guard let regular = product(.yearly), let offer = product(.exitOffer), regular.price > 0 else { return nil }
        let ratio = (offer.price / regular.price) as NSDecimalNumber
        let percent = 100 - Int((ratio.doubleValue * 100).rounded())
        return percent > 0 ? percent : nil
    }

    /// Free-trial length in days, read from the product's introductory offer
    /// (change it in App Store Connect, the paywall follows). Nil = no trial.
    func trialDays(_ plan: Plan) -> Int? {
        guard let intro = product(plan)?.introductoryDiscount, intro.paymentMode == .freeTrial else { return nil }
        let value = intro.subscriptionPeriod.value
        switch intro.subscriptionPeriod.unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        }
    }

    // MARK: - Loading

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Entitlement first: served from RevenueCat's cache, so launch routing
        // resolves without waiting for the offerings fetch.
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
        entitlementChecked = true

        if let offerings = try? await Purchases.shared.offerings() {
            // Match by product ID across ALL offerings, so a dashboard change
            // of the "current" offering cannot empty the paywall.
            let all = offerings.all.values.flatMap(\.availablePackages)
            var found: [Plan: Package] = [:]
            for (plan, id) in Self.productIDs {
                found[plan] = all.first { $0.storeProduct.productIdentifier == id }
            }
            packages = found
        }
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Self.entitlementID]
        isPro = entitlement?.isActive == true
        willAutoRenew = entitlement?.willRenew ?? true
        expirationDate = entitlement?.expirationDate
        entitlementChecked = true
    }

    // MARK: - Purchasing

    func purchase(_ plan: Plan) async -> PurchaseOutcome {
        guard let package = packages[plan] else {
            Analytics.track(.purchaseResult, ["plan": plan.rawValue, "result": "noProduct"])
            return .failed
        }
        Analytics.track(.purchaseStarted, ["plan": plan.rawValue])
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else {
                Analytics.track(.purchaseResult, ["plan": plan.rawValue, "result": "cancelled"])
                return .cancelled
            }
            apply(result.customerInfo)
            Analytics.track(.purchaseResult, ["plan": plan.rawValue, "result": isPro ? "success" : "notEntitled"])
            // The paywall promises a reminder before the trial ends: keep it.
            if isPro, let days = trialDays(plan) {
                NotificationScheduler.shared.scheduleTrialReminder(trialDays: days)
            }
            return isPro ? .success : .failed
        } catch {
            Analytics.track(.purchaseResult, ["plan": plan.rawValue, "result": "failed"])
            // Even a failed attempt authenticates the storefront: re-fetch so
            // prices switch to the user's currency.
            await refresh()
            return .failed
        }
    }

    func restore() async {
        if let info = try? await Purchases.shared.restorePurchases() {
            apply(info)
            Analytics.track(.restoreResult, ["result": isPro ? "success" : "nothing"])
        } else {
            Analytics.track(.restoreResult, ["result": "failed"])
        }
    }

    // MARK: - Sign in with Apple

    /// Ties the subscription to the Apple account, so it follows the user to
    /// another device. The ID is Apple's opaque per-team user identifier.
    func logIn(appUserID: String) async {
        if let result = try? await Purchases.shared.logIn(appUserID) {
            apply(result.customerInfo)
        }
    }

    func logOut() async {
        if let info = try? await Purchases.shared.logOut() {
            apply(info)
        }
    }
}
