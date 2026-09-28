package com.jackwallner.ironsplits.model

import java.time.Instant
import java.time.Year

data class Athlete(
    val id: String,
    val name: String,
    val city: String?,
    val state: String?,
    val country: String?,
    val gender: String?,
    val contactIds: List<String>,
    val resultCount: Int,
)

data class RaceResult(
    val id: String,
    val eventId: String,
    val eventName: String,
    val eventDate: String?,
    val externalEventName: String?,
    val athleteId: String?,
    val athleteName: String,
    val athleteFirstName: String?,
    val athleteLastName: String?,
    val athleteCity: String?,
    val athleteState: String?,
    val athleteCountry: String?,
    val athleteGender: String?,
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
    val year: Int
        get() = eventDate?.let { runCatching { Instant.parse(it).atZone(java.time.ZoneOffset.UTC).year }.getOrNull() }
            ?: eventName.take(4).toIntOrNull()
            ?: Year.now().value

    val raceName: String
        get() = if (eventName.take(4).toIntOrNull() != null) eventName.drop(4).trim() else eventName.trim()

    val kind: RaceKind
        get() = RaceKind.classify(bikeDistanceKm, runDistanceKm, bike, externalEventName, eventName)

    val isComplete: Boolean
        get() = isFinisher && !didNotFinish && !didNotStart && !disqualified && (finish ?: 0) > 0

    fun seconds(discipline: Discipline): Int? = when (discipline) {
        Discipline.SWIM -> swim
        Discipline.T1 -> t1
        Discipline.BIKE -> bike
        Discipline.T2 -> t2
        Discipline.RUN -> run
        Discipline.TRANSITIONS -> if (t1 != null && t2 != null) t1 + t2 else t1 ?: t2
        Discipline.FINISH -> finish
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
}

enum class RaceKind(val label: String, val fullLabel: String) {
    FULL("Full", "Full distance"),
    HALF("Half", "Half distance"),
    OTHER_TRIATHLON("Triathlon", "Triathlon"),
    RUNNING("Run", "Running"),
    UNKNOWN("Race", "Race");

    val isSupported: Boolean get() = this == FULL || this == HALF

    companion object {
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
                    val speed = bike / (bikeSeconds / 3600.0)
                    val halfSpeed = (bike / 2.0) / (bikeSeconds / 3600.0)
                    if (speed > 46.0 && halfSpeed <= 46.0) bike /= 2.0
                }
                return when {
                    bike > 140 -> FULL
                    bike > 60 -> HALF
                    else -> OTHER_TRIATHLON
                }
            }
            val name = "${externalEventName.orEmpty()} $eventName".uppercase()
            return when {
                "70.3" in name || "IM703" in name || "-703-" in name -> HALF
                "IRONMAN" in name || "TRIATHLON" in name || name.startsWith("IRM") -> FULL
                runDistanceKm != null && runDistanceKm > 1 -> RUNNING
                else -> UNKNOWN
            }
        }
    }
}

enum class Discipline(val label: String, val rankable: Boolean = true) {
    FINISH("Finish"), SWIM("Swim"), BIKE("Bike"), RUN("Run"), TRANSITIONS("T1+T2"),
    T1("T1", false), T2("T2", false);

    companion object {
        val rankings = listOf(FINISH, SWIM, BIKE, RUN, TRANSITIONS)
        val raceLegs = listOf(SWIM, T1, BIKE, T2, RUN)
    }
}
