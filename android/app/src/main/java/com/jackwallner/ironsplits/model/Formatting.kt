package com.jackwallner.ironsplits.model

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

object TimeFormat {
    /**
     * "9:38:11" for a race, "58:18" for a swim, "3:03" for a transition. Leading
     * zeros are dropped: "0:03:03" reads as three hours in a column of races.
     */
    fun hms(seconds: Int?): String {
        if (seconds == null || seconds <= 0) return "--"
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s)
        else String.format(Locale.US, "%d:%02d", m, s)
    }

    fun delta(seconds: Int): String = (if (seconds < 0) "−" else "+") + hms(abs(seconds))

    fun mmss(seconds: Double): String {
        if (!seconds.isFinite() || seconds <= 0) return "--"
        val total = seconds.roundToInt()
        return String.format(Locale.US, "%d:%02d", total / 60, total % 60)
    }

    fun spoken(seconds: Int?): String {
        if (seconds == null || seconds <= 0) return "No time"
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        val parts = mutableListOf<String>()
        if (h > 0) parts += "$h ${if (h == 1) "hour" else "hours"}"
        if (m > 0) parts += "$m ${if (m == 1) "minute" else "minutes"}"
        if (s > 0) parts += "$s ${if (s == 1) "second" else "seconds"}"
        return parts.joinToString(", ")
    }
}

enum class UnitPreference(val rawValue: String, val title: String) {
    METRIC("metric", "Metric (km)"),
    IMPERIAL("imperial", "Imperial (mi)");

    companion object {
        fun fromRaw(raw: String?): UnitPreference? = entries.firstOrNull { it.rawValue == raw }

        val deviceDefault: UnitPreference
            get() = when (Locale.getDefault().country.uppercase(Locale.ROOT)) {
                "US", "LR", "MM" -> IMPERIAL
                else -> METRIC
            }
    }
}

object PaceFormat {
    private const val METERS_PER_MILE = 1609.344
    private const val METERS_PER_YARD = 0.9144

    /** Time per 100 in the water, speed on the bike, time per mile or km on the run. */
    fun text(discipline: Discipline, seconds: Int?, distanceKm: Double?, units: UnitPreference): String? {
        if (seconds == null || seconds <= 0 || distanceKm == null || distanceKm <= 0.01) return null
        val metric = units == UnitPreference.METRIC
        return when (discipline) {
            Discipline.SWIM -> {
                val hundreds = if (metric) distanceKm * 10 else distanceKm * 1000 / METERS_PER_YARD / 100
                TimeFormat.mmss(seconds / hundreds) + if (metric) " /100m" else " /100yd"
            }
            Discipline.BIKE -> {
                val distance = if (metric) distanceKm else distanceKm * 1000 / METERS_PER_MILE
                String.format(Locale.US, "%.1f %s", distance / (seconds / 3600.0), if (metric) "km/h" else "mph")
            }
            Discipline.RUN -> {
                val distance = if (metric) distanceKm else distanceKm * 1000 / METERS_PER_MILE
                TimeFormat.mmss(seconds / distance) + if (metric) " /km" else " /mi"
            }
            else -> null
        }
    }
}

object Ordinal {
    /** "48th". */
    fun text(value: Int?): String? {
        if (value == null || value <= 0) return null
        val suffix = when {
            value % 100 in 11..13 -> "th"
            value % 10 == 1 -> "st"
            value % 10 == 2 -> "nd"
            value % 10 == 3 -> "rd"
            else -> "th"
        }
        return "$value$suffix"
    }
}

/** Race dates are UTC calendar days, so they never shift with the device time zone. */
object RaceDate {
    fun medium(date: LocalDate): String =
        date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(Locale.getDefault()))

    fun long(date: LocalDate): String =
        date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(Locale.getDefault()))

    /** "Sep 7, 2025", the year, or "Undated". */
    fun text(result: RaceResult): String =
        result.eventDate?.let(::medium) ?: if (result.year > 0) result.year.toString() else "Undated"
}
