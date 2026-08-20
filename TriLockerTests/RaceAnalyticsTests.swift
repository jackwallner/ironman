import XCTest
@testable import Tri_Locker

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
}
