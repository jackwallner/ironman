package com.jackwallner.ironsplits.data

import com.jackwallner.ironsplits.model.RaceResult
import java.security.MessageDigest
import java.time.LocalDate
import org.json.JSONObject

/**
 * One raw upstream row. Numeric columns arrive as `3`, `"4"` or `"1,009"`, so
 * every number goes through the loose readers below: one strict decode would
 * throw away a whole page over a single string-typed rank.
 */
class ODataResultRow(private val json: JSONObject) {
    class Contact(json: JSONObject) {
        val contactId: String? = json.optNullableString("contactid")
        val firstName: String? = json.optNullableString("firstname")
        val lastName: String? = json.optNullableString("lastname")
        val fullName: String? = json.optNullableString("fullname")
        val city: String? = json.optNullableString("address1_city")
        val stateOrProvince: String? = json.optNullableString("address1_stateorprovince")
        val country: String? = json.optNullableString("address1_country")
        val gender: String? = json.optNullableString("gendercode_formatted")
    }

    val contact: Contact? = json.optJSONObject("wtc_ContactId")?.let(::Contact)

    val result: RaceResult by lazy { buildResult() }

    private fun buildResult(): RaceResult {
        val event = json.optJSONObject("wtc_EventId")
        val name = contact?.fullName
            ?: listOfNotNull(contact?.firstName, contact?.lastName).joinToString(" ")
        val resultId = json.optNullableString("wtc_resultid")?.trim()?.takeIf { it.isNotEmpty() }
        return RaceResult(
            id = resultId ?: stableResultId(event),
            eventId = json.optNullableString("_wtc_eventid_value") ?: event?.optNullableString("wtc_eventid") ?: "",
            eventName = event?.optNullableString("wtc_name") ?: "Unknown race",
            eventDate = parseDate(event?.optNullableString("wtc_eventdate")),
            externalEventName = event?.optNullableString("wtc_externaleventname"),
            athleteId = contact?.contactId,
            athleteName = name.ifEmpty { "Unknown athlete" },
            bib = looseInt("wtc_bibnumber"),
            ageGroup = json.optNullableString("_wtc_agegroupid_value_formatted"),
            countryISO2 = json.optJSONObject("wtc_CountryRepresentingId")?.optNullableString("wtc_iso2"),
            swim = positive("wtc_swimtime"),
            t1 = positive("wtc_transition1time"),
            bike = positive("wtc_biketime"),
            t2 = positive("wtc_transition2time"),
            run = positive("wtc_runtime"),
            finish = positive("wtc_finishtime"),
            swimDistanceKm = looseDouble("wtc_swimdistancecompleted"),
            bikeDistanceKm = looseDouble("wtc_bikedistancecompleted"),
            runDistanceKm = looseDouble("wtc_rundistancecompleted"),
            swimRankOverall = rank("wtc_swimrankoverall"),
            bikeRankOverall = rank("wtc_bikerankoverall"),
            runRankOverall = rank("wtc_runrankoverall"),
            finishRankOverall = rank("wtc_finishrankoverall"),
            finishRankGender = rank("wtc_finishrankgender"),
            finishRankGroup = rank("wtc_finishrankgroup"),
            swimRankGroup = rank("wtc_swimrankgroup"),
            bikeRankGroup = rank("wtc_bikerankgroup"),
            runRankGroup = rank("wtc_runrankgroup"),
            isFinisher = looseBool("wtc_finisher") ?: false,
            didNotFinish = looseBool("wtc_dnf") ?: false,
            didNotStart = looseBool("wtc_dns") ?: false,
            disqualified = looseBool("wtc_dq") ?: false,
        )
    }

    /** A durable identity for a row with no result id, so notes never orphan. */
    private fun stableResultId(event: JSONObject?): String {
        val seed = listOf(
            contact?.contactId,
            json.optNullableString("_wtc_eventid_value") ?: event?.optNullableString("wtc_eventid"),
            event?.optNullableString("wtc_eventdate"),
            looseInt("wtc_bibnumber")?.toString(),
            looseInt("wtc_finishtime")?.toString(),
            looseInt("wtc_swimtime")?.toString(),
            looseInt("wtc_biketime")?.toString(),
            looseInt("wtc_runtime")?.toString(),
            contact?.fullName,
        ).mapNotNull { it?.trim() }.joinToString("|")
        val digest = MessageDigest.getInstance("SHA-256").digest(seed.toByteArray()).take(16).toByteArray()
        digest[6] = ((digest[6].toInt() and 0x0f) or 0x50).toByte()
        digest[8] = ((digest[8].toInt() and 0x3f) or 0x80).toByte()
        val hex = digest.joinToString("") { "%02x".format(it) }
        return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
            "${hex.substring(16, 20)}-${hex.substring(20, 32)}"
    }

    private fun looseInt(key: String): Int? {
        if (!json.has(key) || json.isNull(key)) return null
        return when (val value = json.opt(key)) {
            null -> null
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toDouble().toInt()
            is String -> value.replace(",", "").trim().toIntOrNull()
            else -> null
        }
    }

    private fun looseDouble(key: String): Double? {
        if (!json.has(key) || json.isNull(key)) return null
        return when (val value = json.opt(key)) {
            null -> null
            is Number -> value.toDouble()
            is String -> value.replace(",", "").trim().toDoubleOrNull()
            else -> null
        }
    }

    private fun looseBool(key: String): Boolean? {
        if (!json.has(key) || json.isNull(key)) return null
        return when (val value = json.opt(key)) {
            null -> null
            is Boolean -> value
            is Number -> value.toDouble() != 0.0
            is String -> when (value.trim().lowercase()) {
                "true", "yes", "1" -> true
                "false", "no", "0" -> false
                else -> null
            }
            else -> null
        }
    }

    /** Zero is the feed's "no data": a DNF carries a 0 run split. */
    private fun positive(key: String): Int? = looseInt(key)?.takeIf { it > 0 }

    /** The timer's 99999 sentinel means "never ranked". */
    private fun rank(key: String): Int? = positive(key)?.takeIf { it < 99_999 }

    companion object {
        /** "2025-09-07T00:00:00Z" is a calendar day, read straight from the digits. */
        fun parseDate(raw: String?): LocalDate? {
            if (raw == null || raw.length < 10) return null
            val year = raw.substring(0, 4).toIntOrNull() ?: return null
            val month = raw.substring(5, 7).toIntOrNull() ?: return null
            val day = raw.substring(8, 10).toIntOrNull() ?: return null
            return runCatching { LocalDate.of(year, month, day) }.getOrNull()
        }
    }
}
