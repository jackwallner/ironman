package com.jackwallner.ironsplits.data

import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.model.sortedByDateDescending
import java.io.IOException
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.URLEncoder
import java.net.UnknownHostException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

sealed class ResultsApiException(message: String) : Exception(message) {
    class BadConfiguration : ResultsApiException("The results search could not be prepared. Please try again.")
    class BadResponse(val code: Int) : ResultsApiException("The results site is having trouble. Please try again shortly.")
    class UpstreamRejected(val detail: String) : ResultsApiException("The results site could not complete that search. Please try again.")
    class PageLimitReached : ResultsApiException("Some older results may be missing. Try refreshing again later.")
}

data class AthleteSearchResponse(
    val athletes: List<Athlete>,
    val hasUnsupportedResults: Boolean,
    val wasTruncated: Boolean,
) {
    val hasOnlyUnsupportedResults: Boolean get() = hasUnsupportedResults && !wasTruncated
}

/**
 * How hard a name search may work. `startswith` answers in about a second and
 * a half; `contains` is a full upstream scan of about thirty seconds.
 */
enum class SearchDepth { PREFIX, SUBSTRING }

interface ResultsProviding {
    suspend fun searchAthletes(query: String, depth: SearchDepth = SearchDepth.PREFIX): AthleteSearchResponse
    suspend fun results(contactIds: List<String>): List<RaceResult>
    suspend fun results(eventId: String): List<RaceResult>
}

private class ResultsFetch(val rows: List<ODataResultRow>, val wasTruncated: Boolean)

class ResultsApi(private val configLoader: FeedConfigLoader) : ResultsProviding {

    override suspend fun searchAthletes(query: String, depth: SearchDepth): AthleteSearchResponse {
        val term = query.trim()
        if (term.length < 2) return AthleteSearchResponse(emptyList(), hasUnsupportedResults = false, wasTruncated = false)
        val fetched = fetch(
            filter = nameFilter(term, depth),
            orderBy = "wtc_EventId/wtc_eventdate desc",
            pageLimit = 2,
            pageSize = 250,
            timeoutSeconds = if (depth == SearchDepth.PREFIX) 20 else 60,
            allowTruncation = true,
        )
        val athletes = collapseToAthletes(fetched.rows)
        val hasUnsupported = athletes.isEmpty() && fetched.rows.any { !it.result.kind.isSupported }
        return AthleteSearchResponse(athletes, hasUnsupported, fetched.wasTruncated)
    }

    /** A whole career, with every contact id ORed into one filter so paging covers all of it. */
    override suspend fun results(contactIds: List<String>): List<RaceResult> {
        val ids = contactIds.distinct()
        if (ids.isEmpty() || !ids.all(::isGuid)) throw ResultsApiException.BadConfiguration()
        val clause = ids.joinToString(" or ") { "wtc_ContactId/contactid eq $it" }
        val fetched = fetch(if (ids.size == 1) clause else "($clause)", "wtc_EventId/wtc_eventdate desc")
        return deduplicatedRows(fetched.rows).map { it.result }.filter { it.kind.isSupported }.sortedByDateDescending()
    }

    override suspend fun results(eventId: String): List<RaceResult> {
        if (!isGuid(eventId)) throw ResultsApiException.BadConfiguration()
        val fetched = fetch(
            "_wtc_eventid_value eq $eventId and wtc_AgeGroupId/wtc_agegroupname ne 'ODIV'",
            "wtc_finishrankoverall",
        )
        return deduplicatedRows(fetched.rows).map { it.result }.filter { it.kind.isSupported }
    }

    private suspend fun fetch(
        filter: String,
        orderBy: String?,
        pageLimit: Int? = null,
        pageSize: Int? = null,
        timeoutSeconds: Int = 25,
        allowTruncation: Boolean = false,
    ): ResultsFetch = withContext(Dispatchers.IO) {
        val config = configLoader.config()
        var query = "\$filter=" + encodeODataValue(filter) + "&\$expand=" + encodeODataValue(EXPAND_CLAUSE)
        if (orderBy != null) query += "&\$orderby=" + encodeODataValue(orderBy)
        var url = config.requestUrl(query, pageSize) ?: throw ResultsApiException.BadConfiguration()
        val rows = mutableListOf<ODataResultRow>()
        var truncated = false
        val limit = maxOf(minOf(pageLimit ?: config.maxPages, config.maxPages), 1)
        for (pageIndex in 0 until limit) {
            coroutineContext.ensureActive()
            val page = load(url, config, timeoutSeconds)
            rows += page.first
            val next = page.second ?: break
            if (pageIndex == limit - 1) {
                if (!allowTruncation) throw ResultsApiException.PageLimitReached()
                truncated = true
                break
            }
            url = config.requestUrl(next) ?: throw ResultsApiException.BadConfiguration()
        }
        ResultsFetch(rows, truncated)
    }

    private fun load(url: String, config: FeedConfig, timeoutSeconds: Int): Pair<List<ODataResultRow>, String?> {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = timeoutSeconds * 1_000
            readTimeout = timeoutSeconds * 1_000
            useCaches = true
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Referer", config.referer)
        }
        try {
            val status = connection.responseCode
            if (status !in 200..299) throw ResultsApiException.BadResponse(status)
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val json = runCatching { JSONObject(body) }.getOrNull() ?: throw ResultsApiException.BadResponse(-1)
            // The proxy answers 200 with {"error": "..."} for a URL it declines to sign.
            json.optNullableString("error")?.let { throw ResultsApiException.UpstreamRejected(it) }
            val values = json.optJSONArray("value") ?: throw ResultsApiException.BadResponse(-1)
            val rows = (0 until values.length()).mapNotNull { values.optJSONObject(it)?.let(::ODataResultRow) }
            return rows to json.optNullableString("@odata.nextLink")
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        /**
         * An explicit `$expand` replaces the server's default expansion. Every
         * relation the decoder reads has to be listed, or `wtc_ContactId`
         * silently disappears and search finds nobody.
         */
        val EXPAND_CLAUSE = listOf(
            "wtc_EventId(\$select=wtc_name,wtc_eventdate,wtc_externaleventname)",
            "wtc_ContactId(\$select=contactid,firstname,lastname,fullname,address1_city,address1_stateorprovince,address1_country,gendercode)",
            "wtc_CountryRepresentingId(\$select=wtc_iso2,wtc_name)",
            "wtc_AgeGroupId(\$select=wtc_agegroupname)",
        ).joinToString(",")

        fun encodeODataValue(value: String): String =
            URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")

        fun escapeODataLiteral(value: String): String = value.replace("'", "''")

        /**
         * Each typed word must match a first or last name, so "wallner pattie"
         * works as well as "pattie wallner". Text after a comma narrows by city
         * or state.
         */
        fun nameFilter(term: String, depth: SearchDepth = SearchDepth.PREFIX): String {
            val op = if (depth == SearchDepth.PREFIX) "startswith" else "contains"
            val components = term.split(",", limit = 2)
            val words = components.first().split(Regex("\\s+"))
                .map { escapeODataLiteral(it) }
                .filter { it.isNotEmpty() }
                .take(3)
            if (words.isEmpty()) return "$op(wtc_ContactId/fullname,'')"
            var filter = words.joinToString(" and ") { word ->
                "($op(wtc_ContactId/firstname,'$word') or $op(wtc_ContactId/lastname,'$word'))"
            }
            if (components.size > 1) {
                val location = escapeODataLiteral(components[1].trim())
                if (location.isNotEmpty()) {
                    filter += " and (startswith(wtc_ContactId/address1_city,'$location') or " +
                        "startswith(wtc_ContactId/address1_stateorprovince,'$location'))"
                }
            }
            return filter
        }

        fun userFacingMessage(error: Throwable): String = when (error) {
            is ResultsApiException -> error.message.orEmpty()
            is UnknownHostException, is ConnectException, is SocketTimeoutException ->
                "The results site is unavailable right now. Please check your connection and try again."
            is IOException -> "Couldn't reach the results site. Please try again."
            else -> "Couldn't reach the results site. Please try again."
        }

        private val GUID = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

        fun isGuid(value: String): Boolean = GUID.matches(value)

        /**
         * Group rows into people. Rows merge when normalised name, gender, city,
         * region and country agree, which reunites "Lincoln, US-CA" with
         * "Lincoln, CA". A contact with no city keeps its own id as the key.
         */
        fun collapseToAthletes(rows: List<ODataResultRow>): List<Athlete> {
            val byKey = linkedMapOf<String, Athlete>()
            val latestYear = mutableMapOf<String, Int>()
            for (row in deduplicatedRows(rows)) {
                val contact = row.contact ?: continue
                val id = contact.contactId ?: continue
                val result = row.result
                if (!result.kind.isSupported) continue
                val key = identityKey(contact, id)
                val year = result.year
                val existing = byKey[key]
                if (existing != null) {
                    var athlete = existing.copy(
                        knownRaceCount = existing.knownRaceCount + 1,
                        contactIds = if (id in existing.contactIds) existing.contactIds else existing.contactIds + id,
                    )
                    if (year > (latestYear[key] ?: 0)) {
                        latestYear[key] = year
                        athlete = athlete.copy(
                            latestRaceName = result.raceName,
                            latestRaceYear = year,
                            latestAgeGroup = result.ageGroup,
                            name = contact.fullName ?: result.athleteName,
                            city = contact.city ?: athlete.city,
                            stateOrProvince = contact.stateOrProvince ?: athlete.stateOrProvince,
                            countryISO2 = result.countryISO2 ?: athlete.countryISO2,
                        )
                    }
                    byKey[key] = athlete
                } else {
                    latestYear[key] = year
                    byKey[key] = Athlete(
                        id = id,
                        contactIds = listOf(id),
                        name = contact.fullName ?: result.athleteName,
                        countryISO2 = result.countryISO2,
                        city = contact.city,
                        stateOrProvince = contact.stateOrProvince,
                        gender = contact.gender,
                        latestAgeGroup = result.ageGroup,
                        knownRaceCount = 1,
                        latestRaceName = result.raceName,
                        latestRaceYear = year,
                    )
                }
            }
            return byKey.values.sortedWith(
                compareByDescending<Athlete> { it.latestRaceYear ?: 0 }
                    .thenByDescending { it.knownRaceCount }
                    .thenBy { it.name },
            )
        }

        /** The proxy can repeat a row across page boundaries while its cache warms. */
        fun deduplicatedRows(rows: List<ODataResultRow>): List<ODataResultRow> {
            val seen = HashSet<String>()
            return rows.filter { seen.add(it.result.id) }
        }

        fun identityKey(contact: ODataResultRow.Contact, fallbackId: String): String {
            val city = normalizeForMatching(contact.city)
            if (city.isEmpty()) return "id:$fallbackId"
            val first = normalizeForMatching(contact.firstName)
            val last = normalizeForMatching(contact.lastName)
            val name = if (first.isEmpty() && last.isEmpty()) normalizeForMatching(contact.fullName) else "$first $last"
            if (name.isBlank()) return "id:$fallbackId"
            return listOf(
                name,
                normalizeForMatching(contact.gender),
                city,
                normalizeRegion(contact.stateOrProvince),
                normalizeCountry(contact.country),
            ).joinToString("|")
        }

        fun normalizeForMatching(value: String?): String {
            if (value == null) return ""
            val folded = java.text.Normalizer.normalize(value, java.text.Normalizer.Form.NFD)
                .replace(Regex("\\p{Mn}+"), "")
                .lowercase()
            return folded.map { if (it.isLetterOrDigit()) it else ' ' }.joinToString("")
                .split(' ').filter { it.isNotEmpty() }.joinToString(" ")
        }

        private fun normalizeRegion(value: String?): String {
            var normalized = normalizeForMatching(value)
            for (prefix in listOf("united states of america", "united states", "usa", "us")) {
                if (normalized.startsWith("$prefix ")) {
                    normalized = normalized.removePrefix("$prefix ")
                    break
                }
            }
            return US_STATES[normalized] ?: normalized
        }

        private fun normalizeCountry(value: String?): String = when (val n = normalizeForMatching(value)) {
            "us", "usa", "united states", "united states of america" -> "us"
            else -> n
        }

        private val US_STATES = mapOf(
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
    }
}

/** True when a thrown error only means the caller stopped waiting. */
fun isCancellation(error: Throwable): Boolean = error is CancellationException

internal fun JSONObject.optNullableString(key: String): String? {
    if (!has(key) || isNull(key)) return null
    return opt(key)?.toString()
}

internal fun JSONArray?.strings(): List<String> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { optString(it).takeIf(String::isNotEmpty) }
