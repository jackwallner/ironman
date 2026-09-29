package com.jackwallner.ironsplits

import com.jackwallner.ironsplits.data.AskPattieGuide
import com.jackwallner.ironsplits.data.FeedConfig
import com.jackwallner.ironsplits.data.ODataResultRow
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.PattiePetState
import com.jackwallner.ironsplits.data.PattieVoiceLibrary
import com.jackwallner.ironsplits.data.ResultsApi
import com.jackwallner.ironsplits.data.SearchDepth
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.Ordinal
import com.jackwallner.ironsplits.model.PaceFormat
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceBookAnalytics
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.model.TimeFormat
import com.jackwallner.ironsplits.model.UnitPreference
import com.jackwallner.ironsplits.model.sortedByDateDescending
import java.io.File
import java.time.LocalDate
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ResultsAndAnalyticsTest {
    private fun row(json: String) = ODataResultRow(JSONObject(json))

    private fun result(
        id: String,
        kind: RaceKind = RaceKind.FULL_DISTANCE,
        finish: Int? = 40_000,
        swim: Int? = 4_000,
        bike: Int? = 20_000,
        run: Int? = 15_000,
        t1: Int? = 300,
        t2: Int? = 200,
        date: LocalDate? = LocalDate.of(2024, 9, 1),
        complete: Boolean = true,
        group: Int? = 10,
    ) = RaceResult(
        id = id, eventId = "e-$id", eventName = "2024 Test Race $id", eventDate = date, externalEventName = null,
        athleteId = "a", athleteName = "A", bib = 1, ageGroup = "M40-44", countryISO2 = "US",
        swim = swim, t1 = t1, bike = bike, t2 = t2, run = run, finish = finish,
        swimDistanceKm = if (kind == RaceKind.FULL_DISTANCE) 3.8 else 1.9,
        bikeDistanceKm = if (kind == RaceKind.FULL_DISTANCE) 180.0 else 90.0,
        runDistanceKm = if (kind == RaceKind.FULL_DISTANCE) 42.2 else 21.1,
        swimRankOverall = null, bikeRankOverall = null, runRankOverall = null, finishRankOverall = null,
        finishRankGender = null, finishRankGroup = group, swimRankGroup = null, bikeRankGroup = null, runRankGroup = null,
        isFinisher = complete, didNotFinish = !complete, didNotStart = false, disqualified = false,
    )

    @Test
    fun prefixSearchIsTheDefaultAndSubstringIsExplicit() {
        val fast = ResultsApi.nameFilter("Pattie Wallner")
        val broad = ResultsApi.nameFilter("Pattie Wallner", SearchDepth.SUBSTRING)
        assertTrue(fast.contains("startswith(wtc_ContactId/firstname,'Pattie')"))
        assertFalse(fast.contains("contains("))
        assertTrue(broad.contains("contains(wtc_ContactId/lastname,'Wallner')"))
    }

    @Test
    fun searchEscapesQuotesCapsWordsAndNarrowsByLocation() {
        val filter = ResultsApi.nameFilter("O'Neil Mary Ann Jo, Vancouver")
        assertTrue(filter.contains("O''Neil"))
        assertFalse(filter.contains("'Jo'"))
        assertTrue(filter.contains("startswith(wtc_ContactId/address1_city,'Vancouver')"))
        assertTrue(filter.contains("startswith(wtc_ContactId/address1_stateorprovince,'Vancouver')"))
    }

    @Test
    fun expandClauseListsEveryRelationTheDecoderReads() {
        listOf("wtc_EventId(", "wtc_ContactId(", "wtc_CountryRepresentingId(", "wtc_AgeGroupId(", "gendercode", "address1_country")
            .forEach { assertTrue(it, ResultsApi.EXPAND_CLAUSE.contains(it)) }
    }

    @Test
    fun looseNumbersDecodeAndZerosAndSentinelsBecomeMissing() {
        val parsed = row(
            """
            {"_wtc_eventid_value":"a1b2c3d4-a1b2-c3d4-a1b2-c3d4a1b2c3d4","_wtc_agegroupid_value_formatted":"F65-69",
             "wtc_bibnumber":"1,009","wtc_swimtime":3010,"wtc_transition1time":"0","wtc_biketime":"17000",
             "wtc_transition2time":120.0,"wtc_runtime":0,"wtc_finishtime":"24890","wtc_bikedistancecompleted":"180.0",
             "wtc_swimrankoverall":"4","wtc_finishrankgroup":99999,"wtc_finisher":"true","wtc_dnf":"0","wtc_dns":0,"wtc_dq":false,
             "wtc_ContactId":{"contactid":"11111111-2222-3333-4444-555555555555","fullname":"Morgan Athlete"},
             "wtc_EventId":{"wtc_name":"2025 IRONMAN Somewhere","wtc_eventdate":"2025-09-07T00:00:00Z"}}
            """.trimIndent(),
        ).result
        assertEquals(1009, parsed.bib)
        assertEquals(3010, parsed.swim)
        assertNull(parsed.t1)
        assertEquals(120, parsed.t2)
        assertNull(parsed.run)
        assertNull(parsed.finishRankGroup)
        assertEquals(4, parsed.swimRankOverall)
        assertEquals(LocalDate.of(2025, 9, 7), parsed.eventDate)
        assertEquals(2025, parsed.year)
        assertEquals("IRONMAN Somewhere", parsed.raceName)
        assertEquals(RaceKind.FULL_DISTANCE, parsed.kind)
        assertTrue(parsed.isComplete)
    }

    @Test
    fun missingResultIdIsStableAcrossDecodes() {
        val json = """{"wtc_finishtime":100,"wtc_ContactId":{"contactid":"x","fullname":"Y"},"wtc_EventId":{"wtc_name":"2020 A"}}"""
        assertEquals(row(json).result.id, row(json).result.id)
        assertNotEquals(row(json).result.id, row(json.replace("100", "101")).result.id)
    }

    @Test
    fun shortenedFullIsReclassifiedByBikeSpeed() {
        // 180 km in 3.5 h is 51 km/h; halved it is a plausible half.
        assertEquals(RaceKind.HALF_DISTANCE, RaceKind.classify(180.0, 42.2, 12_600, null, "2012 IRONMAN New Zealand"))
        assertEquals(RaceKind.FULL_DISTANCE, RaceKind.classify(180.0, 42.2, 20_000, null, "x"))
        assertEquals(RaceKind.HALF_DISTANCE, RaceKind.classify(null, null, null, null, "2019 IRONMAN 70.3 Oceanside"))
        assertEquals(RaceKind.RUNNING, RaceKind.classify(null, 42.2, null, null, "2019 Marathon"))
    }

    @Test
    fun rankingsAreScopedToOneDistanceAndSkipDnfs() {
        val results = listOf(
            result("full-a", finish = 40_000),
            result("full-b", finish = 38_000),
            result("half", kind = RaceKind.HALF_DISTANCE, finish = 18_000),
            result("dnf", finish = null, run = 0, complete = false),
        )
        val standings = RaceAnalytics.standings(results, Discipline.FINISH, RaceKind.FULL_DISTANCE)
        assertEquals(listOf("full-b", "full-a"), standings.map { it.result.id })
        assertEquals(2_000, standings[1].gapToBest)
        assertEquals(listOf(RaceKind.FULL_DISTANCE, RaceKind.HALF_DISTANCE), RaceAnalytics.availableKinds(results))
    }

    @Test
    fun firstRaceAtADistanceIsNotAPersonalBest() {
        val only = result("solo")
        assertFalse(RaceAnalytics.isPersonalBest(only, Discipline.FINISH, listOf(only)))
        val faster = result("faster", finish = 39_000)
        assertTrue(RaceAnalytics.isPersonalBest(faster, Discipline.FINISH, listOf(only, faster)))
    }

    @Test
    fun placementCountsPercentileAgainstFinishersOnly() {
        val mine = result("mine", finish = 30_000)
        val field = listOf(mine, result("a", finish = 20_000), result("b", finish = 40_000), result("c", finish = 50_000), result("d", finish = null, complete = false))
        val placement = RaceAnalytics.placement(mine, Discipline.FINISH, field)!!
        assertEquals(2, placement.rank)
        assertEquals(4, placement.fieldSize)
        assertEquals(67, placement.percentile)
    }

    @Test
    fun summaryCountsPodiumsAndYears() {
        val summary = RaceAnalytics.summary(listOf(result("a", group = 2), result("b", group = 5, date = LocalDate.of(2012, 1, 1))))
        assertEquals(2, summary.finishes)
        assertEquals(1, summary.podiums)
        assertEquals(2012..2024, summary.years)
    }

    @Test
    fun comparisonDeltasStayInOneKindAndProgressionRunsOldestFirst() {
        val early = result("early", finish = 40_000, date = LocalDate.of(2020, 1, 1))
        val late = result("late", finish = 38_000, date = LocalDate.of(2024, 1, 1))
        val deltas = RaceBookAnalytics.deltas(early, late)
        assertEquals(-2_000, deltas.first { it.discipline == Discipline.FINISH }.change)
        assertTrue(RaceBookAnalytics.deltas(early, result("half", kind = RaceKind.HALF_DISTANCE)).isEmpty())
        assertEquals(listOf("early", "late"), RaceBookAnalytics.progression(listOf(late, early), Discipline.FINISH, RaceKind.FULL_DISTANCE).map { it.result.id })
        assertEquals(listOf("late", "early"), listOf(early, late).sortedByDateDescending().map { it.id })
    }

    @Test
    fun formattingMatchesIos() {
        assertEquals("9:38:11", TimeFormat.hms(34_691))
        assertEquals("3:03", TimeFormat.hms(183))
        assertEquals("--", TimeFormat.hms(0))
        assertEquals("48th", Ordinal.text(48))
        assertEquals("11th", Ordinal.text(11))
        assertEquals("22nd", Ordinal.text(22))
        assertEquals("1:34 /100m", PaceFormat.text(Discipline.SWIM, 3_570, 3.8, UnitPreference.METRIC))
        assertEquals("36.0 km/h", PaceFormat.text(Discipline.BIKE, 18_000, 180.0, UnitPreference.METRIC))
    }

    @Test
    fun collapseMergesOneAthleteSplitAcrossTwoContacts() {
        fun contactRow(id: String, contact: String, region: String, year: Int) = row(
            """{"wtc_resultid":"$id","wtc_finishtime":40000,"wtc_finisher":true,"wtc_bikedistancecompleted":180,
               "wtc_ContactId":{"contactid":"$contact","firstname":"Pattie","lastname":"Wallner","fullname":"Pattie Wallner",
               "address1_city":"Lincoln","address1_stateorprovince":"$region","gendercode_formatted":"Female"},
               "wtc_EventId":{"wtc_name":"$year IRONMAN A","wtc_eventdate":"$year-06-01T00:00:00Z"}}""",
        )
        val athletes = ResultsApi.collapseToAthletes(
            listOf(contactRow("1", "c-1", "US-CA", 2015), contactRow("2", "c-2", "CA", 2025), contactRow("1", "c-1", "US-CA", 2015)),
        )
        assertEquals(1, athletes.size)
        assertEquals(listOf("c-1", "c-2"), athletes.single().contactIds)
        assertEquals(2, athletes.single().knownRaceCount)
        assertEquals(2025, athletes.single().latestRaceYear)
    }

    @Test
    fun hotfixConfigRejectsForeignHosts() {
        assertTrue(FeedConfig.bundled.isValid)
        assertFalse(FeedConfig.bundled.copy(proxyUrl = "https://evil.example/api/results-proxy").isValid)
        assertFalse(FeedConfig.bundled.copy(maxPages = 0).isValid)
    }

    @Test
    fun bundledAskPattieTreeHasNoDeadEndsAndFeedsPattieMode() {
        val text = File("src/main/assets/ask-pattie.json").readText()
        val guide = AskPattieGuide.parse(text)!!
        assertTrue(guide.isValid)
        guide.goals.forEach { goal -> assertTrue(guide.topics(goal).isNotEmpty()) }
        val tips = PattieVoiceLibrary.modeTips(guide)
        assertTrue(tips.isNotEmpty())
        tips.forEach { assertTrue(it.voice, File("src/main/assets/pattie-voice/${it.voice}.m4a").exists()) }
        PattieMode.DECK.mapNotNull { it.voice }.forEach { assertTrue(it, File("src/main/assets/pattie-voice/$it.m4a").exists()) }
        PattieVoiceLibrary.catchphrases.forEach { assertTrue(it.voice, File("src/main/assets/pattie-voice/${it.voice}.m4a").exists()) }
    }

    @Test
    fun nextModeTipNeverRepeatsBeforeThePoolIsSpent() {
        val tips = (1..5).map { PattieVoiceLibrary.ModeTip("t$it", "x", "text", "v") }
        val played = mutableSetOf<String>()
        repeat(5) {
            val tip = PattieVoiceLibrary.nextModeTip(tips, played, null)!!
            assertFalse(tip.id in played)
            played += tip.id
        }
    }

    @Test
    fun petLoopIsContinuous() {
        PattiePetState.entries.forEach { state ->
            val frame = state.animationFrame(0.0)
            assertEquals(frame.imageRes, state.animationFrame(1000.0).imageRes)
        }
    }
}
