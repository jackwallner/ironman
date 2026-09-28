package com.jackwallner.ironsplits.data

import android.content.Context
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceResult
import org.json.JSONArray
import org.json.JSONObject

class LocalStore(context: Context) {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences("iron_splits_local", Context.MODE_PRIVATE)

    fun athlete(): Athlete? {
        val json = preferences.getString("locker_athlete", null)?.let { runCatching { JSONObject(it) }.getOrNull() }
            ?: return null
        return Athlete(
            id = json.optString("id"),
            name = json.optString("name"),
            city = json.optNullableString("city"),
            state = json.optNullableString("state"),
            country = json.optNullableString("country"),
            gender = json.optNullableString("gender"),
            contactIds = json.optJSONArray("contactIds").toStrings(),
            resultCount = json.optInt("resultCount"),
        )
    }

    fun saveAthlete(athlete: Athlete) {
        val json = JSONObject().apply {
            put("id", athlete.id)
            put("name", athlete.name)
            put("city", athlete.city)
            put("state", athlete.state)
            put("country", athlete.country)
            put("gender", athlete.gender)
            put("contactIds", JSONArray(athlete.contactIds))
            put("resultCount", athlete.resultCount)
        }
        preferences.edit().putString("locker_athlete", json.toString()).apply()
    }

    fun clearLocker() {
        preferences.edit().remove("locker_athlete").remove("locker_results").apply()
    }

    fun saveResults(results: List<RaceResult>) {
        val array = JSONArray()
        results.forEach { array.put(it.toCacheJson()) }
        preferences.edit().putString("locker_results", array.toString()).apply()
    }

    fun results(): List<RaceResult> = preferences.getString("locker_results", null)
        ?.let { raw -> runCatching { JSONArray(raw) }.getOrNull() }
        ?.let { array -> (0 until array.length()).mapNotNull { index -> array.optJSONObject(index)?.toRaceResult() } }
        .orEmpty()

    fun recentAthletes(): List<Athlete> = preferences.getString("recent_athletes", null)
        ?.let { raw -> runCatching { JSONArray(raw) }.getOrNull() }
        ?.let { array -> (0 until array.length()).mapNotNull { index -> array.optJSONObject(index)?.toAthlete() } }
        .orEmpty()

    fun addRecentAthlete(athlete: Athlete) {
        val next = (listOf(athlete) + recentAthletes().filterNot { it.id == athlete.id }).take(3)
        preferences.edit().putString("recent_athletes", JSONArray().apply { next.forEach { put(it.toJson()) } }.toString()).apply()
    }

    fun note(resultId: String): String = preferences.getString("note_$resultId", "").orEmpty()

    fun saveNote(resultId: String, value: String) {
        preferences.edit().putString("note_$resultId", value.take(2_000)).apply()
    }

    private fun Athlete.toJson() = JSONObject().apply {
        put("id", id)
        put("name", name)
        put("city", city)
        put("state", state)
        put("country", country)
        put("gender", gender)
        put("contactIds", JSONArray(contactIds))
        put("resultCount", resultCount)
    }

    private fun JSONObject.toAthlete() = Athlete(
        id = optString("id"),
        name = optString("name"),
        city = optNullableString("city"),
        state = optNullableString("state"),
        country = optNullableString("country"),
        gender = optNullableString("gender"),
        contactIds = optJSONArray("contactIds").toStrings(),
        resultCount = optInt("resultCount"),
    )

    private fun RaceResult.toCacheJson() = JSONObject().apply {
        put("id", id); put("eventId", eventId); put("eventName", eventName); put("eventDate", eventDate)
        put("externalEventName", externalEventName); put("athleteId", athleteId); put("athleteName", athleteName)
        put("athleteFirstName", athleteFirstName); put("athleteLastName", athleteLastName)
        put("athleteCity", athleteCity); put("athleteState", athleteState); put("athleteCountry", athleteCountry)
        put("athleteGender", athleteGender); put("bib", bib); put("ageGroup", ageGroup); put("countryISO2", countryISO2)
        put("swim", swim); put("t1", t1); put("bike", bike); put("t2", t2); put("run", run); put("finish", finish)
        put("swimDistanceKm", swimDistanceKm); put("bikeDistanceKm", bikeDistanceKm); put("runDistanceKm", runDistanceKm)
        put("swimRankOverall", swimRankOverall); put("bikeRankOverall", bikeRankOverall)
        put("runRankOverall", runRankOverall); put("finishRankOverall", finishRankOverall)
        put("finishRankGender", finishRankGender); put("finishRankGroup", finishRankGroup)
        put("swimRankGroup", swimRankGroup); put("bikeRankGroup", bikeRankGroup); put("runRankGroup", runRankGroup)
        put("isFinisher", isFinisher); put("didNotFinish", didNotFinish); put("didNotStart", didNotStart)
        put("disqualified", disqualified)
    }

    private fun JSONObject.toRaceResult() = RaceResult(
        id = optString("id"), eventId = optString("eventId"), eventName = optString("eventName"),
        eventDate = optNullableString("eventDate"), externalEventName = optNullableString("externalEventName"),
        athleteId = optNullableString("athleteId"), athleteName = optString("athleteName"),
        athleteFirstName = optNullableString("athleteFirstName"), athleteLastName = optNullableString("athleteLastName"),
        athleteCity = optNullableString("athleteCity"), athleteState = optNullableString("athleteState"),
        athleteCountry = optNullableString("athleteCountry"), athleteGender = optNullableString("athleteGender"),
        bib = optNullableInt("bib"), ageGroup = optNullableString("ageGroup"), countryISO2 = optNullableString("countryISO2"),
        swim = optNullableInt("swim"), t1 = optNullableInt("t1"), bike = optNullableInt("bike"),
        t2 = optNullableInt("t2"), run = optNullableInt("run"), finish = optNullableInt("finish"),
        swimDistanceKm = optNullableDouble("swimDistanceKm"), bikeDistanceKm = optNullableDouble("bikeDistanceKm"),
        runDistanceKm = optNullableDouble("runDistanceKm"), swimRankOverall = optNullableInt("swimRankOverall"),
        bikeRankOverall = optNullableInt("bikeRankOverall"), runRankOverall = optNullableInt("runRankOverall"),
        finishRankOverall = optNullableInt("finishRankOverall"), finishRankGender = optNullableInt("finishRankGender"),
        finishRankGroup = optNullableInt("finishRankGroup"), swimRankGroup = optNullableInt("swimRankGroup"),
        bikeRankGroup = optNullableInt("bikeRankGroup"), runRankGroup = optNullableInt("runRankGroup"),
        isFinisher = optBoolean("isFinisher"), didNotFinish = optBoolean("didNotFinish"),
        didNotStart = optBoolean("didNotStart"), disqualified = optBoolean("disqualified"),
    )

    private fun JSONObject.optNullableString(key: String): String? = opt(key)?.takeIf { it != JSONObject.NULL }?.toString()
    private fun JSONObject.optNullableInt(key: String): Int? = if (isNull(key)) null else optInt(key)
    private fun JSONObject.optNullableDouble(key: String): Double? = if (isNull(key)) null else optDouble(key)
    private fun JSONArray?.toStrings(): List<String> = this?.let { array ->
        (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
    }.orEmpty()
}
