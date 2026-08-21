import Foundation

/// What an athlete gets, in one place.
///
/// Right now: everything. `everythingUnlocked` is the single switch that opens
/// the whole app, and every gate in the code reads it rather than testing an
/// entitlement of its own. Nothing is deleted, so turning the switch back off
/// restores the free window, the locked rows and the paywall exactly as they
/// were.
///
/// The reason it is one flag and not a scattering of commented-out conditions:
/// a half-removed gate is how an app ends up shipping a lock screen on a
/// feature it also advertises as free.
enum ProGate {

    /// Every feature is available to every athlete.
    static let everythingUnlocked = true

    /// Races visible without Pro, newest first. Ignored while unlocked.
    static let freeRaceLimit = 3

    static func visibleResults(_ results: [RaceResult], isPro: Bool) -> [RaceResult] {
        guard !everythingUnlocked, !isPro else { return results }
        return Array(results.prefix(freeRaceLimit))
    }

    static func lockedCount(_ results: [RaceResult], isPro: Bool) -> Int {
        guard !everythingUnlocked, !isPro else { return 0 }
        return max(0, results.count - freeRaceLimit)
    }

    static func isLocked(_ result: RaceResult, in results: [RaceResult], isPro: Bool) -> Bool {
        guard !everythingUnlocked, !isPro else { return false }
        return !results.prefix(freeRaceLimit).contains { $0.id == result.id }
    }
}
