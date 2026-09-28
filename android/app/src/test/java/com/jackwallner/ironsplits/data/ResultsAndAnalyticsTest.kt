package com.jackwallner.ironsplits.data

import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.ui.formatTime
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ResultsAndAnalyticsTest {
    @Test
    fun prefixSearchIsFastByDefaultAndSubstringIsExplicit() {
        val fast = ResultsRepository.nameFilter("Pattie Wallner")
        val broad = ResultsRepository.nameFilter("Pattie Wallner", substring = true)
        assertTrue(fast.contains("startswith("))
        assertFalse(fast.contains("contains("))
        assertTrue(broad.contains("contains("))
    }

    @Test
    fun searchEscapesODataQuotesAndSupportsLocation() {
        val filter = ResultsRepository.nameFilter("O'Neil, Vancouver")
        assertTrue(filter.contains("O''Neil"))
        assertTrue(filter.contains("address1_city"))
        assertTrue(filter.contains("address1_stateorprovince"))
    }

    @Test
    fun expandListKeepsEveryRelationTheDecoderNeeds() {
        listOf("wtc_EventId", "wtc_ContactId", "wtc_CountryRepresentingId", "wtc_AgeGroupId")
            .forEach { assertTrue(ResultsRepository.EXPAND.contains(it)) }
    }

    @Test
    fun looseNumbersAcceptNumbersStringsAndFormattedBibsWhileZerosBecomeNil() {
        val result = parseODataRow(
            JSONObject(
                """
                {
                  "_wtc_eventid_value":"a1b2c3d4-a1b2-c3d4-a1b2-c3d4a1b2c3d4",
                  "_wtc_agegroupid_value_formatted":"45-49",
                  "wtc_bibnumber":"1,009",
                  "wtc_swimtime":3010,
                  "wtc_transition1time":"0",
                  "wtc_biketime":"17000",
                  "wtc_transition2time":120,
                  "wtc_runtime":0,
                  "wtc_finishtime":"24890",
                  "wtc_bikedistancecompleted":"180.0",
                  "wtc_swimrankoverall":"4",
                  "wtc_finisher":true,
                  "wtc_dnf":"0",
                  "wtc_dns":0,
                  "wtc_dq":false,
                  "wtc_ContactId":{"contactid":"11111111-2222-3333-4444-555555555555","fullname":"Morgan Athlete"},
                  "wtc_EventId":{"wtc_name":"2025 Full Distance Race","wtc_eventdate":"2025-09-15T07:00:00Z"}
                }
                """.trimIndent(),
            ),
        )
        assertEquals(1009, result.bib)
        assertEquals(3010, result.swim)
        assertNull(result.t1)
        assertEquals(17000, result.bike)
        assertNull(result.run)
        assertEquals(24890, result.finish)
        assertEquals(4, result.swimRankOverall)
        assertEquals("45-49", result.ageGroup)
        assertEquals(RaceKind.FULL, result.kind)
        assertTrue(result.isComplete)
    }

    @Test
    fun missingResultIDIsStableAcrossDecodes() {
        val json = JSONObject(
            """
            {"wtc_bibnumber":"37","wtc_finishtime":"25000","wtc_finisher":"1",
             "wtc_ContactId":{"contactid":"11111111-2222-3333-4444-555555555555","fullname":"Morgan Athlete"},
             "wtc_EventId":{"wtc_name":"2025 Half Distance Race","wtc_eventdate":"2025-09-15T07:00:00Z"}}
            """.trimIndent(),
        )
        val first = parseODataRow(json)
        val second = parseODataRow(json)
        assertEquals(first.id, second.id)
        assertNotNull(first.id)
    }

    @Test
    fun athleteIdentityMergeNormalizesStateAndCountryAliases() {
        val older = result("older", RaceKind.HALF, 14_000).copy(
            athleteId = "contact-old",
            athleteFirstName = "Pattie",
            athleteLastName = "Wallner",
            athleteName = "Pattie Wallner",
            athleteCity = "LINCOLN",
            athleteState = "US-CA",
            athleteCountry = "usa",
            athleteGender = "Female",
        )
        val newer = older.copy(
            id = "newer",
            athleteId = "contact-new",
            athleteCity = "Lincoln",
            athleteState = "California",
            athleteCountry = "United States",
        )
        val namesake = newer.copy(athleteCity = "Sacramento")

        assertEquals(athleteIdentityKey(older, "contact-old"), athleteIdentityKey(newer, "contact-new"))
        assertNotEquals(athleteIdentityKey(older, "contact-old"), athleteIdentityKey(namesake, "contact-new"))
    }

    @Test
    fun rankingExcludesDNFAndKeepsDistancesSeparate() {
        val halfBest = result("half-best", RaceKind.HALF, finish = 14_000)
        val halfNext = result("half-next", RaceKind.HALF, finish = 15_000)
        val dnf = result("dnf", RaceKind.HALF, finish = null, run = null, dnf = true)
        val full = result("full", RaceKind.FULL, finish = 13_000)
        val results = listOf(halfBest, halfNext, dnf, full)

        val halfRankings = RaceAnalytics.standings(results, Discipline.FINISH, RaceKind.HALF)
        assertEquals(listOf("half-best", "half-next"), halfRankings.map { it.result.id })
        assertEquals(listOf("full"), RaceAnalytics.standings(results, Discipline.FINISH, RaceKind.FULL).map { it.result.id })
        assertFalse(RaceAnalytics.isPersonalBest(halfBest, Discipline.FINISH, listOf(halfBest)))
        assertTrue(RaceAnalytics.isPersonalBest(halfBest, Discipline.FINISH, results))
    }

    @Test
    fun fieldPercentileUsesOnlyCompleteFinishersWithThatSplit() {
        val mine = result("mine", RaceKind.HALF, finish = 14_000)
        val faster = result("faster", RaceKind.HALF, finish = 13_000)
        val slower = result("slower", RaceKind.HALF, finish = 15_000)
        val dnf = result("dnf-field", RaceKind.HALF, finish = null, dnf = true)

        val placement = RaceAnalytics.placement(mine, Discipline.FINISH, listOf(mine, faster, slower, dnf))
        assertEquals(2, placement?.rank)
        assertEquals(50, placement?.percentile)
        assertEquals(3, placement?.fieldSize)
    }

    @Test
    fun timeFormattingKeepsNumericColumnsStable() {
        assertEquals("0:59", formatTime(59))
        assertEquals("1:00:01", formatTime(3_601))
        assertEquals("—", formatTime(0))
        assertEquals("—", formatTime(null))
    }

    private fun result(
        id: String,
        kind: RaceKind,
        finish: Int?,
        run: Int? = 3_600,
        dnf: Boolean = false,
    ) = RaceResult(
        id = id,
        eventId = id,
        eventName = if (kind == RaceKind.HALF) "2025 Half Distance Race" else "2025 Full Distance Race",
        eventDate = "2025-09-15T07:00:00Z",
        externalEventName = null,
        athleteId = "athlete",
        athleteName = "Morgan Athlete",
        athleteFirstName = "Morgan",
        athleteLastName = "Athlete",
        athleteCity = null,
        athleteState = null,
        athleteCountry = null,
        athleteGender = null,
        bib = null,
        ageGroup = null,
        countryISO2 = null,
        swim = 1_800,
        t1 = 60,
        bike = 15_000,
        t2 = 60,
        run = run,
        finish = finish,
        swimDistanceKm = 1.9,
        bikeDistanceKm = if (kind == RaceKind.HALF) 90.0 else 180.0,
        runDistanceKm = if (kind == RaceKind.HALF) 21.1 else 42.2,
        swimRankOverall = 4,
        bikeRankOverall = null,
        runRankOverall = null,
        finishRankOverall = null,
        finishRankGender = null,
        finishRankGroup = null,
        swimRankGroup = null,
        bikeRankGroup = null,
        runRankGroup = null,
        isFinisher = !dnf,
        didNotFinish = dnf,
        didNotStart = false,
        disqualified = false,
    )
}
