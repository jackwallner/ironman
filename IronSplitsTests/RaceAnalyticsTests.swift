import XCTest
@testable import IM_Iron_Splits

final class RaceAnalyticsTests: XCTestCase {

    // MARK: - Fixtures

    private func result(id: String,
                        name: String = "IRONMAN Wisconsin",
                        year: Int = 2025,
                        swim: Int? = 3600,
                        t1: Int? = 300,
                        bike: Int? = 18000,
                        t2: Int? = 180,
                        run: Int? = 14400,
                        finish: Int? = 36480,
                        bikeKm: Double? = 180.81,
                        runKm: Double? = 42.3579,
                        swimKm: Double? = 3.8624,
                        finisher: Bool = true,
                        dnf: Bool = false,
                        groupRank: Int? = 5) -> RaceResult {
        RaceResult(
            id: id,
            eventID: "event-" + id,
            eventName: "\(year) \(name)",
            eventDate: DateComponents(calendar: .current, year: year, month: 9, day: 7).date,
            externalEventName: nil,
            athleteID: "athlete",
            athleteName: "Test Athlete",
            bib: 1147,
            ageGroup: "M50-54",
            countryISO2: "US",
            swim: swim, t1: t1, bike: bike, t2: t2, run: run, finish: finish,
            swimDistanceKm: swimKm, bikeDistanceKm: bikeKm, runDistanceKm: runKm,
            swimRankOverall: 96, bikeRankOverall: 40, runRankOverall: 55,
            finishRankOverall: 48, finishRankGender: 40, finishRankGroup: groupRank,
            swimRankGroup: 9, bikeRankGroup: 3, runRankGroup: 4,
            isFinisher: finisher, didNotFinish: dnf, didNotStart: false, disqualified: false
        )
    }

    // MARK: - Race kind

    func testFullDistanceDetectedFromBikeDistance() {
        XCTAssertEqual(result(id: "a").kind, .fullDistance)
    }

    func testHalfDistanceDetectedFromBikeDistance() {
        let half = result(id: "b", bikeKm: 90.1, runKm: 21.1, swimKm: 1.93)
        XCTAssertEqual(half.kind, .halfDistance)
    }

    func testKindFallsBackToNameWhenDistancesAreMissing() {
        let noDistances = result(id: "c", bikeKm: nil, runKm: nil, swimKm: nil,
                                 finisher: true)
        XCTAssertEqual(noDistances.kind, .fullDistance, "An IRONMAN-named row with no distances should still classify")

        let halfByName = RaceKind(bikeDistanceKm: nil, runDistanceKm: nil,
                                  externalEventName: "IM703-OHIO-2023",
                                  eventName: "2023 IRONMAN 70.3 Ohio")
        XCTAssertEqual(halfByName, .halfDistance)
    }

    // MARK: - Standings

    func testStandingsRankFastestFirstAndMarkPersonalBest() {
        let fast = result(id: "fast", year: 2024, bike: 17000)
        let slow = result(id: "slow", year: 2025, bike: 19000)
        let standings = RaceAnalytics.standings([slow, fast], discipline: .bike, kind: .fullDistance)

        XCTAssertEqual(standings.map(\.result.id), ["fast", "slow"])
        XCTAssertTrue(standings[0].isPersonalBest)
        XCTAssertFalse(standings[1].isPersonalBest)
        XCTAssertEqual(standings[0].gapToBest, 0)
        XCTAssertEqual(standings[1].gapToBest, 2000)
    }

    func testStandingsExcludeDidNotFinish() {
        // A DNF carries a fast partial bike split and no run. Left in, it wins
        // the bike leaderboard outright, which is the bug this guards.
        let dnf = result(id: "dnf", bike: 9000, run: nil, finish: nil, finisher: false, dnf: true)
        let good = result(id: "good", bike: 18000)
        let standings = RaceAnalytics.standings([dnf, good], discipline: .bike, kind: .fullDistance)

        XCTAssertEqual(standings.map(\.result.id), ["good"])
    }

    func testStandingsAreScopedToOneRaceKind() {
        let full = result(id: "full", bike: 18000)
        let half = result(id: "half", bike: 9000, bikeKm: 90.1, runKm: 21.1, swimKm: 1.93)
        let fullBoard = RaceAnalytics.standings([full, half], discipline: .bike, kind: .fullDistance)

        XCTAssertEqual(fullBoard.map(\.result.id), ["full"],
                       "A half's bike split must not appear on the full-distance board")
    }

    // MARK: - Transitions

    func testTransitionsSumBothLegs() {
        XCTAssertEqual(result(id: "t").seconds(for: .transitions), 480)
    }

    func testTransitionsFallBackWhenOnlyOneLegIsRecorded() {
        let onlyT1 = result(id: "t1", t2: nil)
        XCTAssertEqual(onlyT1.seconds(for: .transitions), 300)
    }

    // MARK: - Zero handling

    func testZeroSplitsBecomeNil() {
        // The feed writes 0 rather than null for a leg that never happened.
        let row = ODataResultRow.zeroSplitFixture()
        XCTAssertNil(row.result.run)
        XCTAssertNil(row.result.finish)
    }

    // MARK: - Placement

    func testPlacementPercentileAndFieldSize() {
        let field = (0..<10).map { index in
            result(id: "f\(index)", bike: 17000 + index * 100)
        }
        let mine = field[0]
        let placement = RaceAnalytics.placement(of: mine, discipline: .bike, inField: field)

        XCTAssertEqual(placement?.rank, 1)
        XCTAssertEqual(placement?.fieldSize, 10)
        XCTAssertEqual(placement?.percentile, 100)

        let last = RaceAnalytics.placement(of: field[9], discipline: .bike, inField: field)
        XCTAssertEqual(last?.rank, 10)
        XCTAssertEqual(last?.percentile, 0)
    }

    func testPlacementIsNilForAFieldOfOne() {
        let solo = result(id: "solo")
        XCTAssertNil(RaceAnalytics.placement(of: solo, discipline: .bike, inField: [solo]))
    }

    // MARK: - Leg shares

    func testLegSharesSumToOne() {
        let shares = RaceAnalytics.legShares(result(id: "s"))
        XCTAssertEqual(shares.count, 5)
        XCTAssertEqual(shares.reduce(0) { $0 + $1.share }, 1.0, accuracy: 0.0001)
    }

    // MARK: - Summary

    func testSummaryCountsFinishesAndPodiums() {
        let podium = result(id: "p", groupRank: 2)
        let midpack = result(id: "m", groupRank: 40)
        let dnf = result(id: "d", finisher: false, dnf: true)
        let summary = RaceAnalytics.summary([podium, midpack, dnf])

        XCTAssertEqual(summary.starts, 3)
        XCTAssertEqual(summary.finishes, 2)
        XCTAssertEqual(summary.didNotFinish, 1)
        XCTAssertEqual(summary.podiums, 1)
    }

    // MARK: - Available kinds

    func testAvailableKindsAreOrderedByHowOftenRaced() {
        let halves = (0..<3).map { result(id: "h\($0)", bikeKm: 90.1, runKm: 21.1, swimKm: 1.93) }
        let full = result(id: "f")
        XCTAssertEqual(RaceAnalytics.availableKinds(halves + [full]), [.halfDistance, .fullDistance])
    }

    /// Pattie Wallner's only half wore PB FINISH, PB SWIM, PB BIKE, PB RUN and
    /// PB TRANSITIONS at once, because a field of one wins everything.
    func testFirstRaceAtADistanceIsNotAPersonalBest() {
        let debut = half(id: "half-1", finish: 27151)
        for leg in Discipline.rankable {
            XCTAssertFalse(RaceAnalytics.isPersonalBest(debut, discipline: leg, within: [debut]),
                           "A debut at a distance has nothing to be better than (\(leg))")
        }
    }

    func testSecondRaceAtADistanceCanBeAPersonalBest() {
        let slower = half(id: "half-1", finish: 28000)
        let faster = half(id: "half-2", finish: 27151)
        let both = [slower, faster]
        XCTAssertTrue(RaceAnalytics.isPersonalBest(faster, discipline: .finish, within: both))
        XCTAssertFalse(RaceAnalytics.isPersonalBest(slower, discipline: .finish, within: both))
    }

    func testPersonalBestNeverComparesDifferentRaceKinds() {
        let slowerHalf = half(id: "half-slow", finish: 28000)
        let fasterHalf = half(id: "half-fast", finish: 27151)
        let slowerFull = result(id: "full-slow", finish: 38000)
        let fasterFull = result(id: "full-fast", finish: 37000)
        let career = [slowerHalf, fasterHalf, slowerFull, fasterFull]

        XCTAssertTrue(RaceAnalytics.isPersonalBest(fasterHalf, discipline: .finish, within: career))
        XCTAssertFalse(RaceAnalytics.isPersonalBest(slowerHalf, discipline: .finish, within: career))
        XCTAssertTrue(RaceAnalytics.isPersonalBest(fasterFull, discipline: .finish, within: career))
        XCTAssertFalse(RaceAnalytics.isPersonalBest(slowerFull, discipline: .finish, within: career))
    }

    /// A full-distance career alongside it must not be dragged in: ranking is
    /// always scoped to one kind, so the fulls are a separate leaderboard.
    func testADebutHalfIsUnaffectedByAFullDistanceCareer() {
        let debut = half(id: "half-1", finish: 27151)
        let fulls = (1...3).map { result(id: "full-\($0)", year: 2020 + $0) }
        XCTAssertFalse(RaceAnalytics.isPersonalBest(debut, discipline: .finish, within: fulls + [debut]))
    }

    private func half(id: String, finish: Int) -> RaceResult {
        result(id: id, name: "IRONMAN 70.3 Northern California", year: 2026,
               swim: 2400, t1: 300, bike: 12000, t2: 180, run: 12271, finish: finish,
               bikeKm: 90.1, runKm: 21.0975, swimKm: 1.9312)
    }

    // MARK: - Shortened races

    /// 2012 IRONMAN New Zealand was called off in 140km/h winds and re-staged
    /// the next day over half distance. Every row still carries 3.8/180/42.2,
    /// so Pattie Wallner's real 7:20:54 half read as a full-distance personal
    /// best an hour inside the world record.
    func testAShortenedRaceIsNotAFullJustBecauseTheRowSaysSo() {
        let kind = RaceKind(bikeDistanceKm: 180.0, runDistanceKm: 42.2,
                            bikeSeconds: 13_721,
                            externalEventName: nil,
                            eventName: "2012 IRONMAN New Zealand: Triathlon")
        XCTAssertEqual(kind, .halfDistance, "180km in 3:48:41 is 47km/h, so it was not 180km")
    }

    /// The guard must not touch a legitimately fast full-distance ride: the
    /// bike world best over the distance is a little over 44km/h.
    func testAWorldClassFullDistanceRideIsStillAFull() {
        let kind = RaceKind(bikeDistanceKm: 180.0, runDistanceKm: 42.2,
                            bikeSeconds: 14_640,  // 4:04:00, about 44.3km/h
                            externalEventName: nil,
                            eventName: "2016 IRONMAN Texas")
        XCTAssertEqual(kind, .fullDistance)
    }

    func testAnOrdinaryAgeGroupFullIsUnaffected() {
        let kind = RaceKind(bikeDistanceKm: 180.0, runDistanceKm: 42.2,
                            bikeSeconds: 25_200,  // 7:00:00
                            externalEventName: nil,
                            eventName: "2025 IRONMAN Texas")
        XCTAssertEqual(kind, .fullDistance)
    }

    /// With no bike split there is nothing to check the distance against, so
    /// the row is taken at its word rather than guessed at.
    func testNoBikeSplitLeavesTheClaimedDistanceAlone() {
        let kind = RaceKind(bikeDistanceKm: 180.0, runDistanceKm: 42.2,
                            bikeSeconds: nil,
                            externalEventName: nil,
                            eventName: "2012 IRONMAN New Zealand: Triathlon")
        XCTAssertEqual(kind, .fullDistance)
    }

    /// Pattie's 2012 New Zealand half (7:20:54) and her 2026 70.3 (7:32:31)
    /// are the same distance fourteen years apart, which is the whole point:
    /// they belong on one leaderboard.
    func testTheShortenedRaceRanksAgainstHerOtherHalf() {
        let newZealand = result(id: "nz-2012", name: "IRONMAN New Zealand: Triathlon", year: 2012,
                                swim: 2608, t1: 756, bike: 13_721, t2: 512, run: 8857,
                                finish: 26_454, bikeKm: 180.0, runKm: 42.2, swimKm: 3.8)
        let northernCalifornia = result(id: "nc-2026", name: "IRONMAN 70.3 Northern California",
                                        year: 2026, swim: 2400, t1: 300, bike: 12_000, t2: 180,
                                        run: 12_271, finish: 27_151,
                                        bikeKm: 90.1, runKm: 21.0975, swimKm: 1.9312)
        XCTAssertEqual(newZealand.kind, .halfDistance)
        XCTAssertEqual(northernCalifornia.kind, .halfDistance)
        let standings = RaceAnalytics.standings([newZealand, northernCalifornia],
                                                discipline: .finish, kind: .halfDistance)
        XCTAssertEqual(standings.count, 2, "Both halves belong on one leaderboard")
        XCTAssertEqual(standings.first?.result.id, "nz-2012", "7:20:54 beats 7:32:31")
    }
}
