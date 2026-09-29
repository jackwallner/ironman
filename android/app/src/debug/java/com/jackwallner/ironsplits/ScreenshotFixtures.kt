package com.jackwallner.ironsplits

import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceResult
import java.time.LocalDate

/** The same invented athletes as `DebugScreenshotFixtures.swift`, for captures and tests. */
object ScreenshotFixtures {
    const val EVENT_ID = "screenshot-event-riverbend-2025"

    private data class Ranks(
        val swimOverall: Int, val swimGroup: Int, val bikeOverall: Int, val bikeGroup: Int,
        val runOverall: Int, val runGroup: Int, val finishOverall: Int, val finishGender: Int, val finishGroup: Int,
    )

    private val riverbend2025 = Ranks(8, 8, 15, 11, 12, 11, 13, 13, 11)

    val results: List<RaceResult> = listOf(
        finish("demo-full-2022", 2022, "Riverbend Triathlon", 9, 11, 3_850, 340, 20_100, 250, 15_100),
        finish("demo-full-2023", 2023, "Coastline Triathlon", 10, 1, 3_720, 315, 19_300, 225, 14_750),
        finish("demo-full-2024", 2024, "Riverbend Triathlon", 9, 8, 3_650, 300, 18_900, 210, 14_400),
        finish("demo-full-2025", 2025, "Riverbend Triathlon", 9, 7, 3_590, 282, 18_500, 200, 14_100, eventId = EVENT_ID, ranks = riverbend2025),
        finish("demo-half-2022", 2022, "Cascade Half Triathlon", 6, 19, 1_780, 180, 9_800, 140, 7_400, bikeKm = 90.1, runKm = 21.1, swimKm = 1.9),
        finish("demo-half-2024", 2024, "Cascade Half Triathlon", 6, 16, 1_710, 165, 9_350, 130, 7_180, bikeKm = 90.1, runKm = 21.1, swimKm = 1.9),
        finish("demo-half-2025", 2025, "Lakeside Half Triathlon", 5, 25, 1_690, 160, 9_280, 125, 7_100, bikeKm = 90.1, runKm = 21.1, swimKm = 1.9),
    )

    val athlete = Athlete(
        id = "screenshot-athlete", name = "Alex Runner", city = "Vancouver", stateOrProvince = "WA",
        gender = "Male", latestAgeGroup = "M40-44", knownRaceCount = results.size,
        latestRaceName = "Riverbend Triathlon", latestRaceYear = 2025,
    )

    val exploreResults: List<RaceResult> = listOf(
        explore("explore-full-2022", 2022, "High Desert Triathlon", 9, 11, 4_050, 350, 21_200, 250, 17_600, 412),
        explore("explore-half-2023", 2023, "Willow Bend Triathlon", 6, 18, 1_930, 185, 10_150, 145, 8_200, 428, half = true),
        explore("explore-full-2024", 2024, "Canyon Ridge Triathlon", 9, 8, 3_820, 325, 20_100, 230, 16_400, 405),
        explore("explore-half-2024", 2024, "Pine Creek Half Triathlon", 6, 16, 1_850, 175, 9_800, 135, 7_850, 421, half = true),
        explore("explore-full-2025", 2025, "Sierra Crest Triathlon", 9, 7, 3_710, 310, 19_450, 220, 15_600, 398),
        explore("explore-half-2025", 2025, "North Shore Triathlon", 5, 25, 1_790, 170, 9_500, 130, 7_550, 390, half = true),
    )

    val exploreAthlete = Athlete(
        id = "explore-screenshot-athlete", name = "Riley Example", city = "Bend", stateOrProvince = "OR",
        gender = "Female", latestAgeGroup = "F35-39", knownRaceCount = exploreResults.size,
        latestRaceName = "Sierra Crest Triathlon", latestRaceYear = 2025,
    )

    val field: List<RaceResult> = listOf(results.first { it.id == "demo-full-2025" }) + (0 until 36).map { index ->
        finish(
            "demo-field-$index", 2025, "Riverbend Triathlon", 9, 7,
            3_300 + index * 48, 230 + index * 5, 16_200 + index * 170, 175 + index * 4, 12_600 + index * 145,
            eventId = EVENT_ID, athleteName = "Demo Finisher ${index + 1}",
            ageGroup = if (index < 10) "M40-44" else "M35-39", bib = 1_100 + index,
        )
    }

    private fun explore(
        id: String, year: Int, race: String, month: Int, day: Int,
        swim: Int, t1: Int, bike: Int, t2: Int, run: Int, bib: Int, half: Boolean = false,
    ) = finish(
        id, year, race, month, day, swim, t1, bike, t2, run,
        bikeKm = if (half) 90.1 else 180.0, runKm = if (half) 21.1 else 42.2, swimKm = if (half) 1.9 else 3.8,
        eventId = id.replace("explore-", "explore-event-"), athleteName = "Riley Example", ageGroup = "F35-39",
        bib = bib, athleteId = "explore-screenshot-athlete",
    )

    private fun finish(
        id: String, year: Int, race: String, month: Int, day: Int,
        swim: Int, t1: Int, bike: Int, t2: Int, run: Int,
        bikeKm: Double = 180.0, runKm: Double = 42.2, swimKm: Double = 3.8,
        eventId: String? = null, athleteName: String = "Alex Runner", ageGroup: String = "M40-44",
        bib: Int = 1_087, ranks: Ranks? = null, athleteId: String = "screenshot-athlete",
    ): RaceResult {
        val r = ranks ?: Ranks(
            180 + bib % 120, 9 + bib % 6, 120 + bib % 90, 4 + bib % 5,
            240 + bib % 140, 7 + bib % 8, 200 + bib % 120, 150 + bib % 100, 6 + bib % 9,
        )
        return RaceResult(
            id = id, eventId = eventId ?: "demo-event-$id", eventName = "$year $race",
            eventDate = LocalDate.of(year, month, day), externalEventName = null,
            athleteId = athleteId, athleteName = athleteName, bib = bib, ageGroup = ageGroup, countryISO2 = "US",
            swim = swim, t1 = t1, bike = bike, t2 = t2, run = run, finish = swim + t1 + bike + t2 + run,
            swimDistanceKm = swimKm, bikeDistanceKm = bikeKm, runDistanceKm = runKm,
            swimRankOverall = r.swimOverall, bikeRankOverall = r.bikeOverall, runRankOverall = r.runOverall,
            finishRankOverall = r.finishOverall, finishRankGender = r.finishGender, finishRankGroup = r.finishGroup,
            swimRankGroup = r.swimGroup, bikeRankGroup = r.bikeGroup, runRankGroup = r.runGroup,
            isFinisher = true, didNotFinish = false, didNotStart = false, disqualified = false,
        )
    }
}
