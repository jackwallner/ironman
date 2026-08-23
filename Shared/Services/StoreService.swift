import Foundation
import os
import StoreKit
@preconcurrency import RevenueCat

enum IronSplitsProduct {
    static let lifetime = "com.jackwallner.ironman.pro"
    /// Kept for receipt recognition so customers from the earlier subscription
    /// model can still restore access. They are not offered to new customers.
    static let yearly = "com.jackwallner.ironman.pro.yearly"
    static let monthly = "com.jackwallner.ironman.pro.monthly"
    static let legacySubscriptions: Set<String> = [yearly, monthly]
    static let all: [String] = [lifetime]
}

enum RevenueCatConfig {
    #if DEBUG
    static let apiKey = IronSplitsSecrets.revenueCatDebugKey
    #else
    static let apiKey = IronSplitsSecrets.revenueCatKey
    #endif
    static let proEntitlement = "pro"
    static let fallbackEntitlement = "Iron Splits+"
    /// Entitlement created by the first RevenueCat setup before the app's
    /// settled public entitlement names were documented. Keep it readable so
    /// those customers can still restore access.
    static let legacyEntitlement = "Ironman App Pro"
}

enum IronSplitsLegal {
    /// Apple's standard EULA, required on the paywall unless a custom one is hosted.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://jackwallner.github.io/ironman/privacy-policy.html")!
}

/// Session-scoped cap so the same contextual paywall can't be re-presented
/// endlessly as a user pokes at locked features. Resets on app relaunch.
@MainActor
final class PaywallGate: ObservableObject {
    static let shared = PaywallGate()
    private var presentedCount: [PaywallTrigger: Int] = [:]
    private let maxPerTrigger = 2

    /// Returns true if the paywall for this trigger may still be shown.
    /// User-explicit entry points (Settings, toolbar) should bypass this.
    func shouldPresent(_ trigger: PaywallTrigger) -> Bool {
        presentedCount[trigger, default: 0] < maxPerTrigger
    }

    func markPresented(_ trigger: PaywallTrigger) {
        presentedCount[trigger, default: 0] += 1
    }
}

enum PurchaseState {
    case purchased
    case cancelled
    case pending
}

/// Result of a one-tap CTA that transacts the lifetime Race Book unlock.
///
/// `.needsPlanPicker` is the only case that may open `PaywallView`: it means
/// the offering never loaded, so there is nothing to buy and the plan picker's
/// retry/empty state is the honest answer. Every other case is handled inline.
enum DirectPurchaseOutcome: Equatable {
    case unlocked
    case pending
    case cancelled
    case failed(String)
    case needsPlanPicker
}

enum StoreServiceError: LocalizedError {
    case purchasesUnavailableInSimulator

    var errorDescription: String? {
        switch self {
        case .purchasesUnavailableInSimulator:
            return "Purchases are unavailable in simulator builds."
        }
    }
}

enum RCProductKind: Int {
    case lifetime = 0
    case yearly = 1
    case monthly = 2
    case other = 3
}

extension RCProductKind {
    init(package: Package) {
        switch package.packageType {
        case .lifetime:
            self = .lifetime
        case .annual:
            self = .yearly
        case .monthly:
            self = .monthly
        default:
            let identifiers = [package.identifier, package.storeProduct.productIdentifier].map { $0.lowercased() }
            if identifiers.contains(where: { $0.contains(IronSplitsProduct.lifetime.lowercased()) }) {
                self = .lifetime
            } else if identifiers.contains(where: { $0.contains(IronSplitsProduct.yearly.lowercased()) || $0.contains("annual") }) {
                self = .yearly
            } else if identifiers.contains(where: { $0.contains(IronSplitsProduct.monthly.lowercased()) }) {
                self = .monthly
            } else {
                self = .other
            }
        }
    }
}

extension Package {
    var productKind: RCProductKind {
        RCProductKind(package: self)
    }

    var displayName: String {
        switch productKind {
        case .lifetime: return "Race Book"
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .other: return storeProduct.localizedTitle
        }
    }

    var priceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else { return storeProduct.localizedPriceString }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.value == 1 {
            return "\(storeProduct.localizedPriceString) / \(unit)"
        } else {
            return "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
        }
    }

    /// Localized per-month price for any recurring package. Lifetime and
    /// non-recurring products return nil. Kept for recognizing legacy
    /// subscription receipts, which are not offered to new customers.
    var monthlyEquivalentLabel: String? {
        guard let period = storeProduct.subscriptionPeriod else { return nil }
        let monthsDecimal: Decimal
        switch period.unit {
        case .day:   monthsDecimal = Decimal(period.value) / Decimal(30)
        case .week:  monthsDecimal = Decimal(period.value) * Decimal(7) / Decimal(30)
        case .month: monthsDecimal = Decimal(period.value)
        case .year:  monthsDecimal = Decimal(period.value) * Decimal(12)
        @unknown default: return nil
        }
        // Only show /mo breakdown for periods that aren't already monthly,
        // showing "$4.99/mo" under a "$4.99/month" price is noise.
        guard monthsDecimal > 1 else { return nil }
        let perMonth = storeProduct.price / monthsDecimal
        let formatter = storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter(currencyCode: storeProduct.currencyCode)
        return formatter.string(from: perMonth as NSDecimalNumber)
    }

    /// Compact "/mo" label suitable for a strike-through anchor on the yearly
    /// card. Returns the package's localized monthly price (per-month for an
    /// annual product, the price itself for a true monthly product).
    var monthlyEquivalentAnchorLabel: String? {
        switch productKind {
        case .monthly:
            return "\(storeProduct.localizedPriceString)/mo"
        case .yearly, .lifetime, .other:
            guard let perMonth = monthlyEquivalentLabel else { return nil }
            return "\(perMonth)/mo"
        }
    }

    private static func defaultCurrencyFormatter(currencyCode: String?) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        if let code = currencyCode { f.currencyCode = code }
        return f
    }

    var introOfferLabel: String? {
        #if DEBUG && targetEnvironment(simulator)
        if RevenueCatConfig.apiKey.hasPrefix("test_"), productKind == .monthly || productKind == .yearly {
            return "7-day free trial"
        }
        #endif
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.unit == .week {
            return "\(period.value * 7)-day free trial"
        } else {
            return "\(period.value)-\(unit.dropLast(period.value == 1 ? 0 : 1)) free trial"
        }
    }
}

extension CustomerInfo {
    var hasProEntitlement: Bool {
        let active = entitlements.active
        if active[RevenueCatConfig.proEntitlement]?.isActive == true
            || active[RevenueCatConfig.fallbackEntitlement]?.isActive == true
            || active[RevenueCatConfig.legacyEntitlement]?.isActive == true {
            return true
        }
        // Belt-and-suspenders: if the entitlement mapping on the dashboard is
        // missing or mis-named, fall back to product ownership. Lifetime is a
        // non-consumable; recurring products show up under activeSubscriptions.
        if nonSubscriptions.contains(where: { $0.productIdentifier == IronSplitsProduct.lifetime }) {
            return true
        }
        if !activeSubscriptions.intersection(IronSplitsProduct.legacySubscriptions).isEmpty {
            return true
        }
        return false
    }
}

extension Offering {
    /// Keep the one-time Race Book unlock first. Legacy recurring products are
    /// still recognizable for existing customers, but are never offered.
    var sortedPackages: [Package] {
        let displayOrder: [RCProductKind] = [.lifetime, .other, .yearly, .monthly]
        return availablePackages.sorted {
            let lhs = displayOrder.firstIndex(of: $0.productKind) ?? displayOrder.count
            let rhs = displayOrder.firstIndex(of: $1.productKind) ?? displayOrder.count
            if lhs != rhs { return lhs < rhs }
            return $0.storeProduct.productIdentifier < $1.storeProduct.productIdentifier
        }
    }
}

extension Offerings {
    var paywallOffering: Offering? {
        offering(identifier: "default") ?? current
    }
}

@MainActor
final class StoreService: NSObject, ObservableObject {
    static let shared = StoreService()

    @Published private(set) var products: [Package] = []
    /// What the paywall draws. Derived from `products` in production; on a
    /// simulator it can also come from the bundled catalog. See `PlanOption`.
    @Published private(set) var planOptions: [PlanOption] = []
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var customerInfo: CustomerInfo?
    /// Whether this athlete has the lifetime Race Book unlock. Legacy
    /// Iron Splits+ subscriptions also resolve true so existing customers keep
    /// the access they bought.
    ///
    /// `IRONSPLITS_FORCE_PRO=1` on the scheme is the Debug-only override that
    /// predates the switch, kept so the gated build can still be exercised in
    /// the simulator once the switch goes back off.
    #if DEBUG
    @Published private(set) var isPro: Bool = ProGate.everythingUnlocked
        || ProcessInfo.processInfo.environment["IRONSPLITS_FORCE_PRO"] == "1"
    #else
    @Published private(set) var isPro: Bool = ProGate.everythingUnlocked
    #endif
    @Published private(set) var purchaseInFlight: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastError: String?

    /// Per-product intro-offer eligibility. Populated with `fetchProducts` so
    /// trial copy only appears for users StoreKit will actually grant a trial.
    @Published private(set) var introEligibility: [String: Bool] = [:]

    private var paywallImpressionsThisSession: Set<String> = []

    var proPrice: String? {
        products.first(where: { $0.productKind == .lifetime })?.storeProduct.localizedPriceString
    }

    /// CTA label for a Race Book entry point.
    var paywallBlurCTA: String {
        "Unlock Race Book"
    }

    /// Short, stable copy for settings and contextual entry points.
    nonisolated static func upgradeCTALabel(trialAvailable: Bool) -> String {
        "Unlock Race Book"
    }

    var upgradeCTALabel: String {
        Self.upgradeCTALabel(trialAvailable: false)
    }

    func directCTALabel(for trigger: PaywallTrigger) -> String {
        guard let price = proPrice else { return "Unlock Race Book" }
        return "Unlock Race Book for \(price)"
    }

    /// One-line secondary caption shown under the CTA when a trial is offered,
    /// so the price after the trial isn't hidden.
    var paywallBlurSubtext: String? {
        "One-time purchase. No subscription."
    }

    /// The only package offered to new customers.
    var lifetimePackage: Package? {
        products.first { $0.productKind == .lifetime }
    }

    /// Reports a custom-paywall impression to RevenueCat (required for native UI).
    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        guard configureIfNeeded() else { return }
        #if DEBUG
        if ProcessInfo.processInfo.environment["FORCE_PRO"] == "1" { return }
        #endif
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
    }

    private let logger = Logger(subsystem: "com.jackwallner.ironman", category: "Store")
    private var isConfigured = false

    private override init() {}

    func start() {
        #if DEBUG
        // UI-test / local hook: force Race Book so the paid actions render
        // without a sandbox purchase. Never compiled into Release.
        if ProcessInfo.processInfo.environment["FORCE_PRO"] == "1" {
            isPro = true
            return
        }
        #endif
        guard configureIfNeeded() else {
            #if DEBUG
            Task { await hydrateForSimulator() }
            #endif
            return
        }
        Task { await updateCustomerProductStatus(fetchPolicy: .fetchCurrent) }
        Task { await fetchProducts() }
    }

    func fetchProducts() async {
        guard configureIfNeeded() else {
            #if DEBUG
            await hydrateForSimulator()
            #endif
            return
        }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.paywallOffering
            currentOffering = offering
            products = offering?.sortedPackages.filter { $0.productKind == .lifetime } ?? []
            lastError = nil
            await refreshIntroEligibility()
            rebuildPlanOptions()
        } catch {
            logger.error("Product fetch failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't load the Race Book unlock. Check your connection and try again."
        }
    }

    @discardableResult
    func purchase(_ product: Package) async throws -> PurchaseState {
        guard configureIfNeeded() else {
            throw StoreServiceError.purchasesUnavailableInSimulator
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        let result = try await Purchases.shared.purchase(package: product)
        apply(customerInfo: result.customerInfo)
        if result.userCancelled {
            return .cancelled
        } else if result.customerInfo.hasProEntitlement {
            return .purchased
        } else {
            return .pending
        }
    }

    /// The single conversion path behind every Race Book pitch in the app.
    ///
    /// A CTA that names the lifetime unlock has to be that product: the next
    /// thing the user sees is Apple's confirmation sheet, never a second pitch
    /// asking them to choose a plan.
    func purchaseLifetimeDirect() async -> DirectPurchaseOutcome {
        if lifetimePackage == nil, currentOffering == nil {
            await fetchProducts()
        }
        guard let lifetime = lifetimePackage else { return .needsPlanPicker }
        do {
            switch try await purchase(lifetime) {
            case .purchased:
                return .unlocked
            case .pending:
                return .pending
            case .cancelled:
                return .cancelled
            }
        } catch {
            return .failed(lastError ?? "Couldn't complete the purchase. Please try again.")
        }
    }

    func updateCustomerProductStatus(fetchPolicy: CacheFetchPolicy = .default) async {
        guard configureIfNeeded() else { return }
        do {
            let info = try await Purchases.shared.customerInfo(fetchPolicy: fetchPolicy)
            apply(customerInfo: info)
            lastError = nil
        } catch {
            logger.error("Customer info refresh failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't refresh your Race Book purchase status. Check your connection and try again."
        }
    }

    func restorePurchases() async {
        guard configureIfNeeded() else {
            lastError = StoreServiceError.purchasesUnavailableInSimulator.localizedDescription
            return
        }
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            lastError = isPro ? nil : "No Race Book purchase was found for this Apple ID."
        } catch {
            logger.error("Restore failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    private func refreshIntroEligibility() async {
        let identifiers = products
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
        rebuildPlanOptions()
    }

    private func rebuildPlanOptions() {
        planOptions = products
            .filter { $0.productKind == .lifetime }
            .map { PlanOption(package: $0, introOfferEligible: false) }
    }

    /// The package behind a plan card, or nil for a display-only simulator row.
    func package(for option: PlanOption) -> Package? {
        option.package ?? products.first { $0.storeProduct.productIdentifier == option.id }
    }

    func apply(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        let activeKeys = customerInfo.entitlements.active.keys.sorted().joined(separator: ", ")
        let allKeys = customerInfo.entitlements.all.keys.sorted().joined(separator: ", ")
        logger.info("Applied customerInfo, active: [\(activeKeys, privacy: .public)] all: [\(allKeys, privacy: .public)]")
        let hasRaceBookAccess = customerInfo.hasProEntitlement
        guard !ProGate.everythingUnlocked else { return }
        if isPro != hasRaceBookAccess {
            isPro = hasRaceBookAccess
            logger.info("Race Book access updated to \(hasRaceBookAccess, privacy: .public)")
        }
    }

    #if DEBUG
    /// Give the paywall something real to draw on a simulator.
    ///
    /// Two sources, in order of fidelity: StoreKit Testing when the scheme has
    /// actually activated it, and the bundled `.storekit` catalog otherwise.
    /// The second is display-only: `PlanOption.package` is nil, so the CTA
    /// disables itself rather than pretending a purchase is possible.
    /// Neither touches RevenueCat, so no customer is created in the production
    /// project. Compiled out of Release.
    func hydrateForSimulator() async {
        #if targetEnvironment(simulator)
        guard planOptions.isEmpty else { return }
        if let storeKitProducts = try? await Product.products(for: IronSplitsProduct.all),
           !storeKitProducts.isEmpty {
            products = storeKitProducts.map { product in
                Package(identifier: product.id,
                        packageType: Self.packageType(for: product),
                        storeProduct: StoreProduct(sk2Product: product),
                        offeringIdentifier: "default",
                        webCheckoutUrl: nil)
            }
            introEligibility = Dictionary(uniqueKeysWithValues: products.map { ($0.storeProduct.productIdentifier, true) })
            rebuildPlanOptions()
            return
        }
        planOptions = BundledStoreKitCatalog.planOptions()
        #endif
    }

    private static func packageType(for product: Product) -> PackageType {
        guard let period = product.subscription?.subscriptionPeriod else { return .lifetime }
        switch period.unit {
        case .year: return .annual
        case .month: return period.value == 1 ? .monthly : .twoMonth
        case .week: return .weekly
        case .day: return .custom
        @unknown default: return .custom
        }
    }
    #endif

    @discardableResult
    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }
        #if targetEnvironment(simulator)
        guard RevenueCatConfig.apiKey.hasPrefix("test_") else { return false }
        #endif
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        return true
    }
}

extension StoreService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            StoreService.shared.apply(customerInfo: customerInfo)
        }
    }
}
