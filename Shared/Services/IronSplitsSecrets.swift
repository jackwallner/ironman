import Foundation

/// Third-party keys, in one place.
///
/// Only *public* SDK keys belong here. This file ships inside the binary, so a
/// RevenueCat secret key (`sk_…`, full REST access to the account) must never
/// be added: those live in `~/.ironsplits_credentials`, outside the repo.
///
/// An empty key means `configureIfNeeded()` never calls `Purchases.configure`,
/// so the app runs and every Pro surface stays locked rather than crashing or,
/// worse, billing against another app's project.
enum IronSplitsSecrets {
    /// Production RevenueCat public SDK key (`appl_…`). Device / TestFlight /
    /// App Store builds only.
    static let revenueCatKey = "appl_RHvkOdzWRHLGUqdVVWNAEcwTucJ"

    /// Debug key. Must be a RevenueCat Test Store key (`test_…`) or empty:
    /// `StoreService.configureIfNeeded()` refuses to configure on a simulator
    /// with anything else, which is what keeps agent and simulator runs from
    /// creating fake customers in the production RevenueCat charts.
    static let revenueCatDebugKey = ""

    static var isRevenueCatConfigured: Bool { !RevenueCatConfig.apiKey.isEmpty }
}
