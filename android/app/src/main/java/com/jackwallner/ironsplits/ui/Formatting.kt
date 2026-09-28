package com.jackwallner.ironsplits.ui

import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import com.jackwallner.ironsplits.model.Athlete

fun formatTime(seconds: Int?): String {
    if (seconds == null || seconds <= 0) return "—"
    val hours = seconds / 3_600
    val minutes = (seconds % 3_600) / 60
    val remainder = seconds % 60
    return if (hours > 0) String.format(Locale.US, "%d:%02d:%02d", hours, minutes, remainder)
    else String.format(Locale.US, "%d:%02d", minutes, remainder)
}

fun formatDate(value: String?): String {
    if (value.isNullOrBlank()) return "Date unavailable"
    val date = runCatching { Instant.parse(value).atZone(java.time.ZoneId.systemDefault()).toLocalDate() }
        .getOrNull() ?: runCatching { LocalDate.parse(value.take(10)) }.getOrNull() ?: return value.take(10)
    return date.format(DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US))
}

fun formatGap(seconds: Int): String = when {
    seconds <= 0 -> "Best"
    seconds >= 3_600 -> "+${seconds / 3_600}h ${seconds % 3_600 / 60}m"
    seconds >= 60 -> "+${seconds / 60}m ${seconds % 60}s"
    else -> "+${seconds}s"
}

fun athleteLocation(athlete: Athlete): String {
    val city = athlete.city?.trim()?.takeIf(String::isNotBlank)?.let { value ->
        if (value == value.uppercase(Locale.ROOT) && value.length > 2) value.lowercase(Locale.ROOT).replaceFirstChar(Char::uppercase)
        else value
    }
    val rawState = athlete.state?.trim()?.takeIf(String::isNotBlank)
    val state = rawState?.substringAfterLast('-')?.let { value ->
        if (value.length <= 3) value.uppercase(Locale.ROOT)
        else value.lowercase(Locale.ROOT).replaceFirstChar(Char::uppercase)
    }
    val country = athlete.country?.trim()?.takeIf { value ->
        val key = value.lowercase(Locale.ROOT).replace(".", "").trim()
        key !in setOf("us", "usa", "united states", "united states of america")
    }
    return listOfNotNull(city, state, country).joinToString(", ").ifBlank { "Published athlete profile" }
}
