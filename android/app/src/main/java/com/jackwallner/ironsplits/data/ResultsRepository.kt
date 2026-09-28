package com.jackwallner.ironsplits.data

import android.content.Context
import android.net.Uri
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceResult
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest
import java.text.Normalizer
import java.time.Instant
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class ResultsRepository(context: Context) {
    private val preferences = context.getSharedPreferences("feed_config", Context.MODE_PRIVATE)
    private var config = preferences.getString("cached", null)?.let {
        runCatching { FeedConfig.parse(JSONObject(it)) }.getOrNull()
    } ?: FeedConfig.bundled

    suspend fun searchAthletes(query: String, substring: Boolean = false): List<Athlete> = withContext(Dispatchers.IO) {
        refreshConfigIfStale()
        val filter = nameFilter(query, substring)
        if (filter.isBlank()) return@withContext emptyList()
        val fetched = fetch(filter, "wtc_EventId/wtc_eventdate desc", pageSize = 250, pageLimit = 2,
            timeoutSeconds = if (substring) 60 else 20, allowTruncation = true)
        collapseAthletes(fetched.first)
    }

    suspend fun resultsForAthlete(contactIds: List<String>): List<RaceResult> = withContext(Dispatchers.IO) {
        refreshConfigIfStale()
        val uniqueIds = contactIds.distinct().filter(::isGuid)
        require(uniqueIds.isNotEmpty()) { "No valid athlete IDs were supplied." }
        val parts = uniqueIds.map { "wtc_ContactId/contactid eq $it" }
        val filter = if (parts.size == 1) parts.single() else "(${parts.joinToString(" or ")})"
        fetch(filter, "wtc_EventId/wtc_eventdate desc").first
            .distinctBy { it.second.id }
            .map { it.second }
            .filter { it.kind.isSupported }
            .sortedByDescending { it.eventDate.orEmpty() }
    }

    suspend fun resultsForEvent(eventId: String): List<RaceResult> = withContext(Dispatchers.IO) {
        refreshConfigIfStale()
        require(isGuid(eventId)) { "Invalid event ID." }
        fetch("_wtc_eventid_value eq $eventId and wtc_AgeGroupId/wtc_agegroupname ne 'ODIV'",
            "wtc_finishrankoverall").first.map { it.second }.filter { it.kind.isSupported }
    }

    private suspend fun refreshConfigIfStale() {
        val last = preferences.getLong("last_attempt", 0L)
        if (System.currentTimeMillis() - last < CONFIG_REFRESH_MS) return
        preferences.edit().putLong("last_attempt", System.currentTimeMillis()).apply()
        val candidate = runCatching {
            val response = request(URL(CONFIG_URL), timeoutSeconds = 10)
            FeedConfig.parse(JSONObject(response))
        }.getOrNull()
        if (candidate != null) {
            config = candidate
            preferences.edit().putString("cached", candidate.toJson().toString()).apply()
        } else if (last > 0) {
            preferences.getString("cached", null)?.let { cached ->
                runCatching { FeedConfig.parse(JSONObject(cached)) }.getOrNull()?.let { config = it }
            }
        }
    }

    private fun fetch(
        filter: String,
        orderBy: String,
        pageSize: Int = config.pageSize,
        pageLimit: Int = config.maxPages,
        timeoutSeconds: Int = 25,
        allowTruncation: Boolean = false,
    ): Pair<List<Pair<String, RaceResult>>, Boolean> {
        val rows = mutableListOf<Pair<String, RaceResult>>()
        var url = requestUrl(filter, orderBy, pageSize)
        var truncated = false
        for (page in 0 until pageLimit) {
            val envelope = JSONObject(request(url, timeoutSeconds))
            envelope.optString("error").takeIf(String::isNotBlank)?.let {
                throw ResultsFeedException("The results service could not complete that search.")
            }
            val values = envelope.optJSONArray("value") ?: JSONArray()
            for (index in 0 until values.length()) {
                val row = values.optJSONObject(index) ?: continue
                val result = parseODataRow(row)
                val id = result.id
                rows += id to result
            }
            val next = envelope.optString("@odata.nextLink").takeIf(String::isNotBlank) ?: break
            if (page == pageLimit - 1) {
                if (!allowTruncation) throw ResultsFeedException("Some older results may be missing. Refresh later.")
                truncated = true
                break
            }
            url = requestNextUrl(next)
        }
        return rows to truncated
    }

    private fun request(url: URL, timeoutSeconds: Int): String {
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = timeoutSeconds * 1_000
            readTimeout = timeoutSeconds * 1_000
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Referer", config.referer)
        }
        try {
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw ResultsFeedException("The results site is having trouble. Try again shortly.")
            return body
        } finally {
            connection.disconnect()
        }
    }

    private fun requestUrl(filter: String, orderBy: String, pageSize: Int): URL {
        val upstream = buildString {
            append(config.resultsUrl)
            append("?\$filter=").append(encode(filter))
            append("&\$expand=").append(encode(EXPAND))
            append("&\$orderby=").append(encode(orderBy))
        }
        val proxy = Uri.parse(config.proxyUrl).buildUpon()
            .appendQueryParameter(config.proxyUrlParameter, upstream)
            .appendQueryParameter(config.pageSizeParameter, pageSize.toString())
            .build()
        return URL(proxy.toString())
    }

    private fun requestNextUrl(nextLink: String): URL {
        val parsed = Uri.parse(nextLink)
        require(parsed.scheme == "https" && parsed.host == "api.competitor.com" && parsed.path == "/web/results") {
            "The results service returned an invalid page link."
        }
        val proxy = Uri.parse(config.proxyUrl).buildUpon()
            .appendQueryParameter(config.proxyUrlParameter, nextLink)
            .appendQueryParameter(config.pageSizeParameter, config.pageSize.toString())
            .build()
        return URL(proxy.toString())
    }

    private fun collapseAthletes(rows: List<Pair<String, RaceResult>>): List<Athlete> {
        val grouped = linkedMapOf<String, MutableList<RaceResult>>()
        rows.distinctBy { it.first }.map { it.second }
            .filter { it.kind.isSupported && it.athleteId != null }
            .forEach { result ->
                val id = result.athleteId.orEmpty()
                val key = athleteIdentityKey(result, id)
                grouped.getOrPut(key) { mutableListOf() }.add(result)
            }
        return grouped.values.map { results ->
            val latest = results.maxByOrNull(RaceResult::year) ?: results.first()
            val contactIds = results.mapNotNull(RaceResult::athleteId).distinct()
            Athlete(
                id = contactIds.firstOrNull() ?: latest.id,
                name = latest.athleteName,
                city = latest.athleteCity,
                state = latest.athleteState,
                country = latest.athleteCountry ?: latest.countryISO2,
                gender = latest.athleteGender,
                contactIds = contactIds,
                resultCount = results.size,
            )
        }.sortedWith(compareByDescending<Athlete> { it.resultCount }.thenBy { it.name })
    }

    companion object {
        const val CONFIG_URL = "https://jackwallner.github.io/ironman/api-config.json"
        const val CONFIG_REFRESH_MS = 6 * 60 * 60 * 1_000L
        const val EXPAND = "wtc_EventId(\$select=wtc_name,wtc_eventdate,wtc_externaleventname)," +
            "wtc_ContactId(\$select=contactid,firstname,lastname,fullname,address1_city,address1_stateorprovince,address1_country,gendercode)," +
            "wtc_CountryRepresentingId(\$select=wtc_iso2,wtc_name),wtc_AgeGroupId(\$select=wtc_agegroupname)"

        fun nameFilter(query: String, substring: Boolean = false): String {
            val parts = query.trim().split(',', limit = 2)
            val words = parts.first().trim().split(Regex("\\s+")).filter(String::isNotBlank).take(3)
            if (words.isEmpty()) return ""
            val op = if (substring) "contains" else "startswith"
            val filters = words.map { raw ->
                val word = raw.replace("'", "''")
                "($op(wtc_ContactId/firstname,'$word') or $op(wtc_ContactId/lastname,'$word'))"
            }.toMutableList()
            parts.getOrNull(1)?.trim()?.takeIf(String::isNotBlank)?.let { location ->
                val escaped = location.replace("'", "''")
                filters += "(startswith(wtc_ContactId/address1_city,'$escaped') or startswith(wtc_ContactId/address1_stateorprovince,'$escaped'))"
            }
            return filters.joinToString(" and ")
        }

        private fun encode(value: String): String = URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")

        private fun isGuid(value: String): Boolean = GUID.matches(value.trim().removePrefix("{").removeSuffix("}"))

        private val GUID = Regex("^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$")

    }
}

internal fun athleteIdentityKey(result: RaceResult, fallbackId: String): String {
    val city = normalizeForMatching(result.athleteCity)
    if (city.isEmpty()) return "id:$fallbackId"
    val first = normalizeForMatching(result.athleteFirstName)
    val last = normalizeForMatching(result.athleteLastName)
    val name = if (first.isBlank() && last.isBlank()) normalizeForMatching(result.athleteName) else "$first $last"
    if (name.isBlank()) return "id:$fallbackId"
    return listOf(
        name,
        normalizeForMatching(result.athleteGender),
        city,
        normalizeRegion(result.athleteState),
        normalizeCountry(result.athleteCountry),
    ).joinToString("|")
}

private fun normalizeForMatching(value: String?): String {
    if (value.isNullOrBlank()) return ""
    val plain = Normalizer.normalize(value.lowercase(Locale.ROOT), Normalizer.Form.NFD)
        .replace(Regex("\\p{Mn}+"), "")
    return plain.replace(Regex("[^\\p{L}\\p{N}]+"), " ").trim().replace(Regex("\\s+"), " ")
}

private fun normalizeRegion(value: String?): String {
    var normalized = normalizeForMatching(value)
    for (prefix in listOf("united states of america", "united states", "usa", "us")) {
        if (normalized.startsWith("$prefix ")) {
            normalized = normalized.removePrefix("$prefix ")
            break
        }
    }
    return US_STATE_ABBREVIATIONS[normalized] ?: normalized
}

private fun normalizeCountry(value: String?): String = when (normalizeForMatching(value)) {
    "us", "usa", "united states", "united states of america" -> "us"
    else -> normalizeForMatching(value)
}

private val US_STATE_ABBREVIATIONS = mapOf(
    "alabama" to "al", "alaska" to "ak", "arizona" to "az", "arkansas" to "ar",
    "california" to "ca", "colorado" to "co", "connecticut" to "ct", "delaware" to "de",
    "florida" to "fl", "georgia" to "ga", "hawaii" to "hi", "idaho" to "id",
    "illinois" to "il", "indiana" to "in", "iowa" to "ia", "kansas" to "ks",
    "kentucky" to "ky", "louisiana" to "la", "maine" to "me", "maryland" to "md",
    "massachusetts" to "ma", "michigan" to "mi", "minnesota" to "mn", "mississippi" to "ms",
    "missouri" to "mo", "montana" to "mt", "nebraska" to "ne", "nevada" to "nv",
    "new hampshire" to "nh", "new jersey" to "nj", "new mexico" to "nm", "new york" to "ny",
    "north carolina" to "nc", "north dakota" to "nd", "ohio" to "oh", "oklahoma" to "ok",
    "oregon" to "or", "pennsylvania" to "pa", "rhode island" to "ri", "south carolina" to "sc",
    "south dakota" to "sd", "tennessee" to "tn", "texas" to "tx", "utah" to "ut",
    "vermont" to "vt", "virginia" to "va", "washington" to "wa", "west virginia" to "wv",
    "wisconsin" to "wi", "wyoming" to "wy",
)

internal fun parseODataRow(row: JSONObject): RaceResult {
    val contact = row.optJSONObject("wtc_ContactId")
    val event = row.optJSONObject("wtc_EventId")
    val contactId = contact?.string("contactid")
    val eventId = row.string("_wtc_eventid_value") ?: event?.string("wtc_eventid").orEmpty()
    val fullName = contact?.string("fullname")
        ?: listOfNotNull(contact?.string("firstname"), contact?.string("lastname")).joinToString(" ")
    val date = event?.string("wtc_eventdate")
    val id = row.string("wtc_resultid")?.takeIf(String::isNotBlank) ?: stableResultId(
        listOf(contactId, eventId, date, row.number("wtc_bibnumber"), row.number("wtc_finishtime"), fullName)
            .joinToString("|")
    )
    return RaceResult(
        id = id,
        eventId = eventId,
        eventName = event?.string("wtc_name") ?: "Unknown race",
        eventDate = date,
        externalEventName = event?.string("wtc_externaleventname"),
        athleteId = contactId,
        athleteName = fullName.ifBlank { "Unknown athlete" },
        athleteFirstName = contact?.string("firstname"),
        athleteLastName = contact?.string("lastname"),
        athleteCity = contact?.string("address1_city"),
        athleteState = contact?.string("address1_stateorprovince"),
        athleteCountry = contact?.string("address1_country"),
        athleteGender = contact?.string("gendercode_formatted"),
        bib = row.int("wtc_bibnumber"),
        ageGroup = row.string("_wtc_agegroupid_value_formatted"),
        countryISO2 = row.optJSONObject("wtc_CountryRepresentingId")?.string("wtc_iso2"),
        swim = row.positiveInt("wtc_swimtime"),
        t1 = row.positiveInt("wtc_transition1time"),
        bike = row.positiveInt("wtc_biketime"),
        t2 = row.positiveInt("wtc_transition2time"),
        run = row.positiveInt("wtc_runtime"),
        finish = row.positiveInt("wtc_finishtime"),
        swimDistanceKm = row.double("wtc_swimdistancecompleted"),
        bikeDistanceKm = row.double("wtc_bikedistancecompleted"),
        runDistanceKm = row.double("wtc_rundistancecompleted"),
        swimRankOverall = row.rank("wtc_swimrankoverall"),
        bikeRankOverall = row.rank("wtc_bikerankoverall"),
        runRankOverall = row.rank("wtc_runrankoverall"),
        finishRankOverall = row.rank("wtc_finishrankoverall"),
        finishRankGender = row.rank("wtc_finishrankgender"),
        finishRankGroup = row.rank("wtc_finishrankgroup"),
        swimRankGroup = row.rank("wtc_swimrankgroup"),
        bikeRankGroup = row.rank("wtc_bikerankgroup"),
        runRankGroup = row.rank("wtc_runrankgroup"),
        isFinisher = row.flag("wtc_finisher"),
        didNotFinish = row.flag("wtc_dnf"),
        didNotStart = row.flag("wtc_dns"),
        disqualified = row.flag("wtc_dq"),
    )
}

private fun stableResultId(seed: String): String = MessageDigest.getInstance("SHA-256")
    .digest(seed.toByteArray()).take(16).joinToString("") { "%02x".format(it) }

class ResultsFeedException(message: String) : Exception(message)

private data class FeedConfig(
    val proxyUrl: String,
    val proxyUrlParameter: String,
    val pageSizeParameter: String,
    val resultsUrl: String,
    val pageSize: Int,
    val maxPages: Int,
    val referer: String,
) {
    fun toJson() = JSONObject().apply {
        put("proxyURL", proxyUrl)
        put("proxyURLParameter", proxyUrlParameter)
        put("pageSizeParameter", pageSizeParameter)
        put("resultsURL", resultsUrl)
        put("pageSize", pageSize)
        put("maxPages", maxPages)
        put("referer", referer)
    }

    companion object {
        val bundled = FeedConfig(
            "https://labs-v2.competitor.com/api/results-proxy", "url", "pageSize",
            "https://api.competitor.com/web/results", 500, 12,
            "https://labs-v2.competitor.com/",
        )

        fun parse(json: JSONObject) = FeedConfig(
            proxyUrl = json.getString("proxyURL"),
            proxyUrlParameter = json.getString("proxyURLParameter"),
            pageSizeParameter = json.getString("pageSizeParameter"),
            resultsUrl = json.getString("resultsURL"),
            pageSize = json.optInt("pageSize", 500),
            maxPages = json.optInt("maxPages", 12),
            referer = json.getString("referer"),
        ).also { candidate ->
            require(candidate.proxyUrl == bundled.proxyUrl && candidate.resultsUrl == bundled.resultsUrl)
            require(candidate.proxyUrlParameter == "url" && candidate.pageSizeParameter == "pageSize")
            require(candidate.pageSize in 1..2_000 && candidate.maxPages in 1..100)
            require(candidate.referer == bundled.referer)
        }
    }
}

private fun JSONObject.string(key: String): String? = opt(key)?.takeIf { it != JSONObject.NULL }?.toString()
private fun JSONObject.number(key: String): String? = opt(key)?.takeIf { it != JSONObject.NULL }?.toString()
private fun JSONObject.int(key: String): Int? = number(key)?.replace(",", "")?.toDoubleOrNull()?.toInt()
private fun JSONObject.positiveInt(key: String): Int? = int(key)?.takeIf { it > 0 }
private fun JSONObject.rank(key: String): Int? = int(key)?.takeIf { it > 0 }
private fun JSONObject.double(key: String): Double? = number(key)?.replace(",", "")?.toDoubleOrNull()?.takeIf { it > 0 }
private fun JSONObject.flag(key: String): Boolean {
    val value = opt(key)
    return when (value) {
        is Boolean -> value
        is Number -> value.toInt() != 0
        is String -> value.trim().lowercase() in setOf("true", "1", "yes", "y")
        null -> false
        else -> false
    }
}
