import Foundation

/// Third-party keys, in one place.
///
/// `revenueCatKey` is intentionally empty until the App Store Connect record
/// and the RevenueCat project for this app exist. An empty key means
/// `configureIfNeeded()` never calls `Purchases.configure`, so the app runs and
/// every Pro surface stays locked rather than crashing or, worse, billing
/// against another app's project.
enum TriLockerSecrets {
    /// Production RevenueCat public SDK key (`appl_…`). Device / TestFlight /
    /// App Store builds only.
    static let revenueCatKey = ""

    /// Debug key. Must be a RevenueCat Test Store key (`test_…`) or empty:
    /// `StoreService.configureIfNeeded()` refuses to configure on a simulator
    /// with anything else, which is what keeps agent and simulator runs from
    /// creating fake customers in the production RevenueCat charts.
    static let revenueCatDebugKey = ""

    static var isRevenueCatConfigured: Bool { !RevenueCatConfig.apiKey.isEmpty }
}
