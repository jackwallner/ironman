package com.jackwallner.ironsplits.data

import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceResult
import java.time.LocalDate
import org.json.JSONArray
import org.json.JSONObject

/** On-device JSON for the locker cache, recents and notes. */
object Codec {
    fun athlete(athlete: Athlete): JSONObject = JSONObject()
        .put("id", athlete.id)
        .put("contactIDs", JSONArray(athlete.contactIds))
        .put("name", athlete.name)
        .putOpt("countryISO2", athlete.countryISO2)
        .putOpt("city", athlete.city)
        .putOpt("stateOrProvince", athlete.stateOrProvince)
        .putOpt("gender", athlete.gender)
        .putOpt("latestAgeGroup", athlete.latestAgeGroup)
        .put("knownRaceCount", athlete.knownRaceCount)
        .putOpt("latestRaceName", athlete.latestRaceName)
        .putOpt("latestRaceYear", athlete.latestRaceYear)

    fun athlete(json: JSONObject): Athlete? {
        val id = json.optNullableString("id") ?: return null
        val name = json.optNullableString("name") ?: return null
        return Athlete(
            id = id,
            contactIds = json.optJSONArray("contactIDs").strings().ifEmpty { listOf(id) },
            name = name,
            countryISO2 = json.optNullableString("countryISO2"),
            city = json.optNullableString("city"),
            stateOrProvince = json.optNullableString("stateOrProvince"),
            gender = json.optNullableString("gender"),
            latestAgeGroup = json.optNullableString("latestAgeGroup"),
            knownRaceCount = json.optInt("knownRaceCount"),
            latestRaceName = json.optNullableString("latestRaceName"),
            latestRaceYear = json.optIntOrNull("latestRaceYear"),
        )
    }

    fun result(result: RaceResult): JSONObject = JSONObject().apply {
        put("id", result.id)
        put("eventID", result.eventId)
        put("eventName", result.eventName)
        putOpt("eventDate", result.eventDate?.toString())
        putOpt("externalEventName", result.externalEventName)
        putOpt("athleteID", result.athleteId)
        put("athleteName", result.athleteName)
        putOpt("bib", result.bib)
        putOpt("ageGroup", result.ageGroup)
        putOpt("countryISO2", result.countryISO2)
        putOpt("swim", result.swim)
        putOpt("t1", result.t1)
        putOpt("bike", result.bike)
        putOpt("t2", result.t2)
        putOpt("run", result.run)
        putOpt("finish", result.finish)
        putOpt("swimDistanceKm", result.swimDistanceKm)
        putOpt("bikeDistanceKm", result.bikeDistanceKm)
        putOpt("runDistanceKm", result.runDistanceKm)
        putOpt("swimRankOverall", result.swimRankOverall)
        putOpt("bikeRankOverall", result.bikeRankOverall)
        putOpt("runRankOverall", result.runRankOverall)
        putOpt("finishRankOverall", result.finishRankOverall)
        putOpt("finishRankGender", result.finishRankGender)
        putOpt("finishRankGroup", result.finishRankGroup)
        putOpt("swimRankGroup", result.swimRankGroup)
        putOpt("bikeRankGroup", result.bikeRankGroup)
        putOpt("runRankGroup", result.runRankGroup)
        put("isFinisher", result.isFinisher)
        put("didNotFinish", result.didNotFinish)
        put("didNotStart", result.didNotStart)
        put("disqualified", result.disqualified)
    }

    fun result(json: JSONObject): RaceResult? {
        val id = json.optNullableString("id") ?: return null
        return RaceResult(
            id = id,
            eventId = json.optNullableString("eventID").orEmpty(),
            eventName = json.optNullableString("eventName") ?: "Unknown race",
            eventDate = json.optNullableString("eventDate")?.let { runCatching { LocalDate.parse(it) }.getOrNull() },
            externalEventName = json.optNullableString("externalEventName"),
            athleteId = json.optNullableString("athleteID"),
            athleteName = json.optNullableString("athleteName") ?: "Unknown athlete",
            bib = json.optIntOrNull("bib"),
            ageGroup = json.optNullableString("ageGroup"),
            countryISO2 = json.optNullableString("countryISO2"),
            swim = json.optIntOrNull("swim"),
            t1 = json.optIntOrNull("t1"),
            bike = json.optIntOrNull("bike"),
            t2 = json.optIntOrNull("t2"),
            run = json.optIntOrNull("run"),
            finish = json.optIntOrNull("finish"),
            swimDistanceKm = json.optDoubleOrNull("swimDistanceKm"),
            bikeDistanceKm = json.optDoubleOrNull("bikeDistanceKm"),
            runDistanceKm = json.optDoubleOrNull("runDistanceKm"),
            swimRankOverall = json.optIntOrNull("swimRankOverall"),
            bikeRankOverall = json.optIntOrNull("bikeRankOverall"),
            runRankOverall = json.optIntOrNull("runRankOverall"),
            finishRankOverall = json.optIntOrNull("finishRankOverall"),
            finishRankGender = json.optIntOrNull("finishRankGender"),
            finishRankGroup = json.optIntOrNull("finishRankGroup"),
            swimRankGroup = json.optIntOrNull("swimRankGroup"),
            bikeRankGroup = json.optIntOrNull("bikeRankGroup"),
            runRankGroup = json.optIntOrNull("runRankGroup"),
            isFinisher = json.optBoolean("isFinisher"),
            didNotFinish = json.optBoolean("didNotFinish"),
            didNotStart = json.optBoolean("didNotStart"),
            disqualified = json.optBoolean("disqualified"),
        )
    }

    fun athletes(array: JSONArray?): List<Athlete> =
        if (array == null) emptyList() else (0 until array.length()).mapNotNull { array.optJSONObject(it)?.let(::athlete) }

    fun results(array: JSONArray?): List<RaceResult> =
        if (array == null) emptyList() else (0 until array.length()).mapNotNull { array.optJSONObject(it)?.let(::result) }

    private fun JSONObject.optIntOrNull(key: String): Int? = if (!has(key) || isNull(key)) null else optInt(key)
    private fun JSONObject.optDoubleOrNull(key: String): Double? =
        if (!has(key) || isNull(key)) null else optDouble(key).takeIf { !it.isNaN() }
}
