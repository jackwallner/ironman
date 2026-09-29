package com.jackwallner.ironsplits.model

import java.time.LocalDate

/**
 * One athlete's finish in one event, normalised from the results feed.
 *
 * Every split is raw seconds. Rankings, deltas and paces are arithmetic on
 * seconds, and the feed's display strings are lossy under an hour.
 */
data class RaceResult(
    val id: String,
    val eventId: String,
    val eventName: String,
    /** The feed's event date is a UTC calendar day, not an instant. */
    val eventDate: LocalDate?,
    val externalEventName: String?,
    val athleteId: String?,
    val athleteName: String,
    val bib: Int?,
    val ageGroup: String?,
    val countryISO2: String?,
    val swim: Int?,
    val t1: Int?,
    val bike: Int?,
    val t2: Int?,
    val run: Int?,
    val finish: Int?,
    val swimDistanceKm: Double?,
    val bikeDistanceKm: Double?,
    val runDistanceKm: Double?,
    val swimRankOverall: Int?,
    val bikeRankOverall: Int?,
    val runRankOverall: Int?,
    val finishRankOverall: Int?,
    val finishRankGender: Int?,
    val finishRankGroup: Int?,
    val swimRankGroup: Int?,
    val bikeRankGroup: Int?,
    val runRankGroup: Int?,
    val isFinisher: Boolean,
    val didNotFinish: Boolean,
    val didNotStart: Boolean,
    val disqualified: Boolean,
) {
    /** From the event date, or the "2025 ..." name prefix. Zero when neither exists. */
    val year: Int
        get() = eventDate?.year ?: eventName.take(4).toIntOrNull() ?: 0

    /** Event name without the leading year every row repeats. */
    val raceName: String
        get() {
            val trimmed = eventName.trim()
            if (trimmed.length <= 5 || trimmed.take(4).toIntOrNull() == null) return trimmed
            return trimmed.drop(4).trim()
        }

    val kind: RaceKind
        get() = RaceKind.classify(bikeDistanceKm, runDistanceKm, bike, externalEventName, eventName)

    /** DNF rows carry partial splits that would otherwise win every leaderboard. */
    val isComplete: Boolean
        get() = isFinisher && !didNotFinish && !didNotStart && !disqualified && (finish ?: 0) > 0

    fun seconds(discipline: Discipline): Int? = when (discipline) {
        Discipline.SWIM -> swim
        Discipline.T1 -> t1
        Discipline.BIKE -> bike
        Discipline.T2 -> t2
        Discipline.RUN -> run
        Discipline.FINISH -> finish
        Discipline.TRANSITIONS -> if (t1 != null && t2 != null) t1 + t2 else t1 ?: t2
    }

    fun overallRank(discipline: Discipline): Int? = when (discipline) {
        Discipline.SWIM -> swimRankOverall
        Discipline.BIKE -> bikeRankOverall
        Discipline.RUN -> runRankOverall
        Discipline.FINISH -> finishRankOverall
        else -> null
    }

    fun divisionRank(discipline: Discipline): Int? = when (discipline) {
        Discipline.SWIM -> swimRankGroup
        Discipline.BIKE -> bikeRankGroup
        Discipline.RUN -> runRankGroup
        Discipline.FINISH -> finishRankGroup
        else -> null
    }

    fun distanceKm(discipline: Discipline): Double? = when (discipline) {
        Discipline.SWIM -> swimDistanceKm
        Discipline.BIKE -> bikeDistanceKm
        Discipline.RUN -> runDistanceKm
        else -> null
    }

    val statusLabel: String?
        get() = when {
            isComplete -> null
            disqualified -> "DQ"
            didNotStart -> "DNS"
            else -> "DNF"
        }
}

/** Newest first, falling back to the year when a row has no date. */
fun List<RaceResult>.sortedByDateDescending(): List<RaceResult> = sortedWith { lhs, rhs ->
    val l = lhs.eventDate
    val r = rhs.eventDate
    if (l != null && r != null && l != r) r.compareTo(l) else rhs.year.compareTo(lhs.year)
}

/** The six legs plus the aggregate the app ranks transitions on. */
enum class Discipline(val title: String) {
    SWIM("Swim"), T1("T1"), BIKE("Bike"), T2("T2"), RUN("Run"), TRANSITIONS("Transitions"), FINISH("Finish");

    /** "Transitions" truncates in a chip. "T1+T2" is what triathletes call it anyway. */
    val shortTitle: String get() = if (this == TRANSITIONS) "T1+T2" else title

    companion object {
        /** T1 and T2 fold into transitions: nobody chases a T2 personal best alone. */
        val rankable = listOf(FINISH, SWIM, BIKE, RUN, TRANSITIONS)
        val legs = listOf(SWIM, T1, BIKE, T2, RUN)
    }
}

enum class RaceKind(val rawValue: String, val title: String, val longTitle: String) {
    FULL_DISTANCE("fullDistance", "Full", "Full distance"),
    HALF_DISTANCE("halfDistance", "Half", "Half distance"),
    OTHER_TRIATHLON("otherTriathlon", "Tri", "Triathlon"),
    RUNNING("running", "Run", "Running"),
    UNKNOWN("unknown", "Race", "Race");

    /** A two-distance app: other feed rows never reach a product surface. */
    val isSupported: Boolean get() = this == FULL_DISTANCE || this == HALF_DISTANCE

    companion object {
        /** No age-grouper, and no professional, rides 180 km at this speed. */
        private const val IMPLAUSIBLE_BIKE_SPEED_KMH = 46.0

        val supported = listOf(FULL_DISTANCE, HALF_DISTANCE)

        fun fromRaw(raw: String?): RaceKind? = entries.firstOrNull { it.rawValue == raw }

        /**
         * Distance first, name second, but only a distance the bike split agrees
         * with. A shortened race still reports the scheduled 180 km; halving it
         * only stands when that makes the ride plausible.
         */
        fun classify(
            bikeDistanceKm: Double?,
            runDistanceKm: Double?,
            bikeSeconds: Int?,
            externalEventName: String?,
            eventName: String,
        ): RaceKind {
            var bike = bikeDistanceKm
            if (bike != null && bike > 1) {
                if (bikeSeconds != null && bikeSeconds > 0) {
                    val hours = bikeSeconds / 3600.0
                    if (bike / hours > IMPLAUSIBLE_BIKE_SPEED_KMH && (bike / 2) / hours <= IMPLAUSIBLE_BIKE_SPEED_KMH) {
                        bike /= 2
                    }
                }
                return when {
                    bike > 140 -> FULL_DISTANCE
                    bike > 60 -> HALF_DISTANCE
                    else -> OTHER_TRIATHLON
                }
            }
            val haystack = "${externalEventName.orEmpty()} $eventName".uppercase()
            return when {
                "70.3" in haystack || "IM703" in haystack || "-703-" in haystack -> HALF_DISTANCE
                "IRONMAN" in haystack || "TRIATHLON" in haystack || haystack.startsWith("IRM") -> FULL_DISTANCE
                runDistanceKm != null && runDistanceKm > 1 -> RUNNING
                else -> UNKNOWN
            }
        }
    }
}
