import Foundation

/// What a free athlete gets, in one place.
///
/// The free tier is deliberately the thing the App Store screenshot shows: you
/// type your name, and your last three races appear with real splits. Nothing
/// is teased behind a blur until the athlete has already seen their own data
/// come back, because the pitch only makes sense once they believe the search
/// worked.
enum ProGate {
    /// Races visible without Pro, newest first.
    static let freeRaceLimit = 3

    static func visibleResults(_ results: [RaceResult], isPro: Bool) -> [RaceResult] {
        guard !isPro else { return results }
        return Array(results.prefix(freeRaceLimit))
    }

    static func lockedCount(_ results: [RaceResult], isPro: Bool) -> Int {
        guard !isPro else { return 0 }
        return max(0, results.count - freeRaceLimit)
    }

    static func isLocked(_ result: RaceResult, in results: [RaceResult], isPro: Bool) -> Bool {
        guard !isPro else { return false }
        return !results.prefix(freeRaceLimit).contains { $0.id == result.id }
    }
}
