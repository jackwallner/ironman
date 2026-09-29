package com.jackwallner.ironsplits.model

import java.util.Locale

/**
 * A person in the results feed, collapsed from the rows they appear in.
 *
 * [contactIds] carries every contact record the feed holds for them, because
 * registration mints a new one whenever the typed details differ, and a
 * career routinely arrives split across two.
 */
data class Athlete(
    val id: String,
    val contactIds: List<String> = listOf(id),
    val name: String,
    val countryISO2: String? = null,
    val city: String? = null,
    val stateOrProvince: String? = null,
    val gender: String? = null,
    /** Most recent age-group label seen, e.g. "M50-54". */
    val latestAgeGroup: String? = null,
    /** At least this many: search pages are capped. */
    val knownRaceCount: Int = 0,
    val latestRaceName: String? = null,
    val latestRaceYear: Int? = null,
) {
    /** "Madison, WI". City and region are cased separately so "WI" never becomes "Wi". */
    val location: String?
        get() {
            val city = city?.trim()?.takeIf { it.isNotEmpty() }?.capitalizedIfShouting()
            val region = stateOrProvince?.trim()?.takeIf { it.isNotEmpty() }?.uppercase(Locale.ROOT)
            val parts = listOfNotNull(city, region)
            return if (parts.isEmpty()) null else parts.joinToString(", ")
        }

    val subtitle: String
        get() {
            val bits = mutableListOf<String>()
            location?.let(bits::add)
            latestAgeGroup?.let(bits::add)
            val year = latestRaceYear
            if (year != null && year > 0 && latestRaceName != null) bits += "$year $latestRaceName"
            return bits.joinToString(" · ")
        }
}

/** The feed stores cities as typed at registration, often "MADISON". */
fun String.capitalizedIfShouting(): String {
    if (this != uppercase(Locale.ROOT) || length <= 2) return this
    return split(" ").joinToString(" ") { word ->
        word.lowercase(Locale.ROOT).replaceFirstChar { it.titlecase(Locale.ROOT) }
    }
}
