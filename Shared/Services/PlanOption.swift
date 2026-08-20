import Foundation
@preconcurrency import RevenueCat

/// One purchasable plan, as the paywall needs to draw it.
///
/// The paywall used to read RevenueCat `Package`s directly, which meant it
/// could only ever render where RevenueCat was configured — and the
/// keep-prod-clean rule says that is never a simulator. Every headless capture
/// was therefore the "Couldn't Load Plans" empty state, which exercises none of
/// the hero, plan cards, trial copy, disclosure, or footer that the layout is
/// judged on.
///
/// Splitting display from purchase fixes that. `package` is the only thing a
/// transaction needs, and it is nil exactly when there is nothing to transact:
/// a simulator build showing the configured catalog so the layout can be seen.
struct PlanOption: Identifiable, Hashable {
    let id: String
    let kind: RCProductKind
    let displayName: String
    let priceLabel: String
    /// "7-day free trial", when this user is eligible for one.
    let introOfferLabel: String?
    /// Per-month breakdown for an annual plan, e.g. "$1.25".
    let perMonthLabel: String?
    let package: Package?

    var isPurchasable: Bool { package != nil }

    static func == (lhs: PlanOption, rhs: PlanOption) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(package: Package, introOfferEligible: Bool) {
        self.id = package.storeProduct.productIdentifier
        self.kind = package.productKind
        self.displayName = package.displayName
        self.priceLabel = package.priceLabel
        self.introOfferLabel = introOfferEligible ? package.introOfferLabel : nil
        self.perMonthLabel = package.productKind == .yearly ? package.monthlyEquivalentLabel : nil
        self.package = package
    }

    init(id: String, kind: RCProductKind, displayName: String, priceLabel: String,
         introOfferLabel: String?, perMonthLabel: String?) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.priceLabel = priceLabel
        self.introOfferLabel = introOfferLabel
        self.perMonthLabel = perMonthLabel
        self.package = nil
    }
}

#if DEBUG
/// The `.storekit` catalog, read straight out of the app bundle.
///
/// Last resort for simulator runs. StoreKit Testing only serves products when
/// the app is launched through the Xcode scheme, and `xcodebuild test` does not
/// reliably arrange that for a UI-test-launched app. The same file that
/// configures StoreKit Testing is copied into the bundle, so parsing it gives
/// the paywall the real product names, prices and trial terms to lay out —
/// clearly marked unpurchasable, and compiled out of Release entirely.
enum BundledStoreKitCatalog {
    static func planOptions() -> [PlanOption] {
        guard let url = Bundle.main.url(forResource: "Products", withExtension: "storekit"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var options: [PlanOption] = []

        for group in root["subscriptionGroups"] as? [[String: Any]] ?? [] {
            for subscription in group["subscriptions"] as? [[String: Any]] ?? [] {
                guard let productID = subscription["productID"] as? String,
                      let price = subscription["displayPrice"] as? String else { continue }
                let period = subscription["recurringSubscriptionPeriod"] as? String ?? "P1M"
                let kind: RCProductKind = period.hasSuffix("Y") ? .yearly : .monthly
                let unit = kind == .yearly ? "year" : "month"
                let intro = subscription["introductoryOffer"] as? [String: Any]
                let trial = (intro?["paymentMode"] as? String) == "free"
                    ? trialLabel(intro?["subscriptionPeriod"] as? String)
                    : nil
                options.append(PlanOption(
                    id: productID,
                    kind: kind,
                    displayName: displayName(subscription) ?? (kind == .yearly ? "Yearly" : "Monthly"),
                    priceLabel: "$\(price) / \(unit)",
                    introOfferLabel: trial,
                    perMonthLabel: kind == .yearly ? perMonth(price) : nil
                ))
            }
        }

        for product in root["products"] as? [[String: Any]] ?? [] {
            guard let productID = product["productID"] as? String,
                  let price = product["displayPrice"] as? String else { continue }
            options.append(PlanOption(
                id: productID,
                kind: .lifetime,
                displayName: displayName(product) ?? "Lifetime",
                priceLabel: "$\(price)",
                introOfferLabel: nil,
                perMonthLabel: nil
            ))
        }

        let order: [RCProductKind] = [.yearly, .monthly, .lifetime, .other]
        return options.sorted {
            (order.firstIndex(of: $0.kind) ?? order.count) < (order.firstIndex(of: $1.kind) ?? order.count)
        }
    }

    private static func displayName(_ entry: [String: Any]) -> String? {
        guard let localizations = entry["localizations"] as? [[String: Any]] else { return nil }
        let name = localizations.first?["displayName"] as? String
        // "Tri Locker Pro Yearly" in the card's name slot is redundant next to a
        // paywall already headed "Tri Locker Pro".
        return name?.replacingOccurrences(of: "Tri Locker Pro ", with: "")
    }

    private static func trialLabel(_ period: String?) -> String? {
        guard let period, period.hasPrefix("P") else { return nil }
        let value = Int(period.dropFirst().dropLast()) ?? 1
        switch period.last {
        case "W": return "\(value * 7)-day free trial"
        case "D": return "\(value)-day free trial"
        case "M": return value == 1 ? "1-month free trial" : "\(value)-month free trial"
        default: return nil
        }
    }

    private static func perMonth(_ yearlyPrice: String) -> String? {
        guard let value = Double(yearlyPrice), value > 0 else { return nil }
        return String(format: "$%.2f", value / 12)
    }
}
#endif
