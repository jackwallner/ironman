import Foundation

/// The product boundary in one place.
///
/// Race data is the product's foundation, so the complete locker, splits,
/// rankings, field context, notes and basic race details remain free. The one
/// paid boundary is the Race Book artifact: like-for-like comparisons and
/// unlimited PDF/image exports. Keeping the decision here prevents a future
/// screen from quietly putting a lock on the athlete's own data.
enum ProGate {

    /// Temporary switch for TestFlight and App Review builds. Remove the
    /// RACE_BOOK_TEST_UNLOCK build condition before enabling paid access.
    #if RACE_BOOK_TEST_UNLOCK
    static let everythingUnlocked = true
    #else
    static let everythingUnlocked = false
    #endif

    /// Whether the Race Book can be opened for paid actions.
    static func raceBookUnlocked(isPro: Bool) -> Bool {
        everythingUnlocked || isPro
    }

    /// Legacy helpers remain pass-throughs so old cached builds and callers
    /// cannot accidentally turn the free history into a three-race preview.
    static func visibleResults(_ results: [RaceResult], isPro: Bool) -> [RaceResult] {
        results
    }

    static func lockedCount(_ results: [RaceResult], isPro: Bool) -> Int {
        0
    }

    static func isLocked(_ result: RaceResult, in results: [RaceResult], isPro: Bool) -> Bool {
        false
    }
}
