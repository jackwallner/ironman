import Foundation

/// One row of a split leaderboard: a race, the time it produced on one leg, and
/// how far off the athlete's best that is.
struct SplitStanding: Identifiable, Hashable, Sendable {
    let result: RaceResult
    let discipline: Discipline
    let seconds: Int
    let rank: Int
    let gapToBest: Int

    var id: String { result.id + discipline.rawValue }
    var isPersonalBest: Bool { rank == 1 }
}

/// A best time, and the race that produced it.
struct PersonalBest: Identifiable, Hashable, Sendable {
    let discipline: Discipline
    let seconds: Int
    let result: RaceResult

    var id: String { discipline.rawValue + result.id }
}

/// Where one time sits inside the field that raced it.
struct FieldPlacement: Sendable, Hashable {
    let discipline: Discipline
    /// 0-100, higher is better. 90 means "faster than 90% of finishers".
    let percentile: Int
    let rank: Int
    let fieldSize: Int
}

/// Every derived number the app shows, computed from a set of results.
///
/// Ranking is deliberately scoped to one `RaceKind` at a time. A 70.3 bike
/// split will always beat a full-distance one, so a single "best bike" list
/// across both is a list of every half the athlete has ever done — true, and
/// completely useless to someone who wants to know if they are getting faster.
enum RaceAnalytics {
    /// Results eligible for comparison: finished, and of the requested kind.
    static func comparable(_ results: [RaceResult], kind: RaceKind?) -> [RaceResult] {
        results.filter { $0.isComplete && (kind == nil || $0.kind == kind) }
    }

    /// The kinds present in a set, in the order the app should offer them:
    /// most-raced first, so an athlete who has done fourteen 70.3s and one full
    /// doesn't land on the full every time they open the app.
    static func availableKinds(_ results: [RaceResult]) -> [RaceKind] {
        var counts: [RaceKind: Int] = [:]
        for result in results where result.isComplete {
            counts[result.kind, default: 0] += 1
        }
        return counts.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key.rawValue < $1.key.rawValue
        }.map(\.key)
    }

    /// Every race that has a time for this leg, fastest first.
    static func standings(_ results: [RaceResult],
                          discipline: Discipline,
                          kind: RaceKind?) -> [SplitStanding] {
        let timed = comparable(results, kind: kind).compactMap { result -> (RaceResult, Int)? in
            guard let seconds = result.seconds(for: discipline), seconds > 0 else { return nil }
            return (result, seconds)
        }.sorted { $0.1 < $1.1 }

        guard let best = timed.first?.1 else { return [] }
        return timed.enumerated().map { index, entry in
            SplitStanding(result: entry.0,
                          discipline: discipline,
                          seconds: entry.1,
                          rank: index + 1,
                          gapToBest: entry.1 - best)
        }
    }

    static func personalBest(_ results: [RaceResult],
                             discipline: Discipline,
                             kind: RaceKind?) -> PersonalBest? {
        guard let top = standings(results, discipline: discipline, kind: kind).first else { return nil }
        return PersonalBest(discipline: discipline, seconds: top.seconds, result: top.result)
    }

    static func personalBests(_ results: [RaceResult], kind: RaceKind?) -> [PersonalBest] {
        Discipline.rankable.compactMap { personalBest(results, discipline: $0, kind: kind) }
    }

    /// Whether a given race holds the best time on a leg.
    static func isPersonalBest(_ result: RaceResult,
                               discipline: Discipline,
                               within results: [RaceResult]) -> Bool {
        guard result.isComplete, let seconds = result.seconds(for: discipline), seconds > 0 else { return false }
        let best = standings(results, discipline: discipline, kind: result.kind).first
        return best?.result.id == result.id
    }

    /// Rank and percentile against everyone who finished the same event.
    ///
    /// The feed already carries an overall rank for swim, bike, run, and
    /// finish, but not the field size, and a rank with no denominator says
    /// nothing — 200th is a bad day in a field of 300 and an excellent one in a
    /// field of 3000. Transitions have no upstream rank at all, so those get
    /// counted from the field directly.
    static func placement(of result: RaceResult,
                          discipline: Discipline,
                          inField field: [RaceResult]) -> FieldPlacement? {
        let finishers = field.filter { $0.isComplete && ($0.seconds(for: discipline) ?? 0) > 0 }
        guard finishers.count > 1, let mine = result.seconds(for: discipline), mine > 0 else { return nil }
        let faster = finishers.filter { ($0.seconds(for: discipline) ?? .max) < mine }.count
        let rank = faster + 1
        let percentile = Int(((Double(finishers.count - rank) / Double(finishers.count - 1)) * 100).rounded())
        return FieldPlacement(discipline: discipline,
                              percentile: max(0, min(100, percentile)),
                              rank: rank,
                              fieldSize: finishers.count)
    }

    /// How the legs divide a finish time, as fractions that sum to 1.
    ///
    /// Uses the sum of the legs rather than the finish time as the denominator.
    /// They disagree by a few seconds on plenty of rows (timing mats round
    /// independently), and a bar chart that doesn't fill its track looks like a
    /// bug rather than like rounding.
    static func legShares(_ result: RaceResult) -> [(discipline: Discipline, share: Double, seconds: Int)] {
        let legs: [Discipline] = [.swim, .t1, .bike, .t2, .run]
        let pairs = legs.compactMap { leg -> (Discipline, Int)? in
            guard let seconds = result.seconds(for: leg), seconds > 0 else { return nil }
            return (leg, seconds)
        }
        let total = pairs.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }
        return pairs.map { (discipline: $0.0, share: Double($0.1) / Double(total), seconds: $0.1) }
    }

    /// Career totals for the resume and the header.
    struct CareerSummary: Sendable, Hashable {
        var starts: Int
        var finishes: Int
        var didNotFinish: Int
        var fullDistance: Int
        var halfDistance: Int
        var years: ClosedRange<Int>?
        var totalRacingSeconds: Int
        var podiums: Int

        var finishRate: Double {
            starts > 0 ? Double(finishes) / Double(starts) : 0
        }
    }

    static func summary(_ results: [RaceResult]) -> CareerSummary {
        let started = results.filter { !$0.didNotStart }
        let finished = started.filter(\.isComplete)
        let years = started.map(\.year).filter { $0 > 0 }
        return CareerSummary(
            starts: started.count,
            finishes: finished.count,
            didNotFinish: started.filter { $0.didNotFinish || $0.disqualified }.count,
            fullDistance: finished.filter { $0.kind == .fullDistance }.count,
            halfDistance: finished.filter { $0.kind == .halfDistance }.count,
            years: years.isEmpty ? nil : (years.min()! ... years.max()!),
            totalRacingSeconds: finished.reduce(0) { $0 + ($1.finish ?? 0) },
            podiums: finished.filter { ($0.finishRankGroup ?? .max) <= 3 }.count
        )
    }

    /// Finishes of one kind in chronological order, for the trend chart.
    static func trend(_ results: [RaceResult],
                      discipline: Discipline,
                      kind: RaceKind?) -> [(result: RaceResult, seconds: Int)] {
        comparable(results, kind: kind)
            .compactMap { result -> (RaceResult, Int)? in
                guard let seconds = result.seconds(for: discipline), seconds > 0 else { return nil }
                return (result, seconds)
            }
            .sorted { lhs, rhs in
                switch (lhs.0.eventDate, rhs.0.eventDate) {
                case let (l?, r?) where l != r: return l < r
                default: return lhs.0.year < rhs.0.year
                }
            }
            .map { (result: $0.0, seconds: $0.1) }
    }
}
