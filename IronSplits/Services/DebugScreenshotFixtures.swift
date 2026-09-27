import Foundation

#if DEBUG
enum DebugScreenshotFixtures {
    private struct Ranks {
        let swimOverall: Int
        let swimGroup: Int
        let bikeOverall: Int
        let bikeGroup: Int
        let runOverall: Int
        let runGroup: Int
        let finishOverall: Int
        let finishGender: Int
        let finishGroup: Int

        static let riverbend2025 = Ranks(
            swimOverall: 8, swimGroup: 8,
            bikeOverall: 15, bikeGroup: 11,
            runOverall: 12, runGroup: 11,
            finishOverall: 13, finishGender: 13, finishGroup: 11
        )
    }

    static let athlete = Athlete(
        id: "screenshot-athlete",
        name: "Alex Runner",
        city: "Vancouver",
        stateOrProvince: "WA",
        gender: "Male",
        latestAgeGroup: "M40-44",
        knownRaceCount: results.count,
        latestRaceName: "Riverbend Triathlon",
        latestRaceYear: 2025
    )

    static let eventID = "screenshot-event-riverbend-2025"

    static let results: [RaceResult] = [
        finish(id: "demo-full-2022", year: 2022, race: "Riverbend Triathlon", month: 9, day: 11,
               swim: 3_850, t1: 340, bike: 20_100, t2: 250, run: 15_100),
        finish(id: "demo-full-2023", year: 2023, race: "Coastline Triathlon", month: 10, day: 1,
               swim: 3_720, t1: 315, bike: 19_300, t2: 225, run: 14_750),
        finish(id: "demo-full-2024", year: 2024, race: "Riverbend Triathlon", month: 9, day: 8,
               swim: 3_650, t1: 300, bike: 18_900, t2: 210, run: 14_400),
        finish(id: "demo-full-2025", year: 2025, race: "Riverbend Triathlon", month: 9, day: 7,
               swim: 3_590, t1: 282, bike: 18_500, t2: 200, run: 14_100,
               eventID: eventID, ranks: .riverbend2025),
        finish(id: "demo-half-2022", year: 2022, race: "Cascade Half Triathlon", month: 6, day: 19,
               swim: 1_780, t1: 180, bike: 9_800, t2: 140, run: 7_400,
               bikeKm: 90.1, runKm: 21.1, swimKm: 1.9),
        finish(id: "demo-half-2024", year: 2024, race: "Cascade Half Triathlon", month: 6, day: 16,
               swim: 1_710, t1: 165, bike: 9_350, t2: 130, run: 7_180,
               bikeKm: 90.1, runKm: 21.1, swimKm: 1.9),
        finish(id: "demo-half-2025", year: 2025, race: "Lakeside Half Triathlon", month: 5, day: 25,
               swim: 1_690, t1: 160, bike: 9_280, t2: 125, run: 7_100,
               bikeKm: 90.1, runKm: 21.1, swimKm: 1.9),
    ]

    static let field: [RaceResult] = {
        let current = results.first { $0.id == "demo-full-2025" }!
        let competitors = (0..<36).map { index in
            finish(id: "demo-field-\(index)",
                   year: 2025,
                   race: "Riverbend Triathlon",
                   month: 9,
                   day: 7,
                   swim: 3_300 + index * 48,
                   t1: 230 + index * 5,
                   bike: 16_200 + index * 170,
                   t2: 175 + index * 4,
                   run: 12_600 + index * 145,
                   eventID: eventID,
                   athleteName: "Demo Finisher \(index + 1)",
                   ageGroup: index < 10 ? "M40-44" : "M35-39",
                   bib: 1_100 + index)
        }
        return [current] + competitors
    }()

    @MainActor static func seedFieldCache() {
        RaceFieldCache.store(field, for: eventID)
    }

    private static func finish(id: String,
                               year: Int,
                               race: String,
                               month: Int,
                               day: Int,
                               swim: Int,
                               t1: Int,
                               bike: Int,
                               t2: Int,
                               run: Int,
                               bikeKm: Double = 180.0,
                               runKm: Double = 42.2,
                               swimKm: Double = 3.8,
                               eventID: String? = nil,
                               athleteName: String = "Alex Runner",
                               ageGroup: String = "M40-44",
                               bib: Int = 1_087,
                               ranks: Ranks? = nil) -> RaceResult {
        let ranks = ranks ?? Ranks(
            swimOverall: 180 + bib % 120,
            swimGroup: 9 + bib % 6,
            bikeOverall: 120 + bib % 90,
            bikeGroup: 4 + bib % 5,
            runOverall: 240 + bib % 140,
            runGroup: 7 + bib % 8,
            finishOverall: 200 + bib % 120,
            finishGender: 150 + bib % 100,
            finishGroup: 6 + bib % 9
        )
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
        let finish = swim + t1 + bike + t2 + run
        return RaceResult(
            id: id,
            eventID: eventID ?? "demo-event-\(id)",
            eventName: "\(year) \(race)",
            eventDate: date,
            externalEventName: nil,
            athleteID: "screenshot-athlete",
            athleteName: athleteName,
            bib: bib,
            ageGroup: ageGroup,
            countryISO2: "US",
            swim: swim,
            t1: t1,
            bike: bike,
            t2: t2,
            run: run,
            finish: finish,
            swimDistanceKm: swimKm,
            bikeDistanceKm: bikeKm,
            runDistanceKm: runKm,
            swimRankOverall: ranks.swimOverall,
            bikeRankOverall: ranks.bikeOverall,
            runRankOverall: ranks.runOverall,
            finishRankOverall: ranks.finishOverall,
            finishRankGender: ranks.finishGender,
            finishRankGroup: ranks.finishGroup,
            swimRankGroup: ranks.swimGroup,
            bikeRankGroup: ranks.bikeGroup,
            runRankGroup: ranks.runGroup,
            isFinisher: true,
            didNotFinish: false,
            didNotStart: false,
            disqualified: false
        )
    }
}
#endif
