package com.jackwallner.ironsplits.model

import kotlin.math.roundToInt

/** One row of a split leaderboard. */
data class SplitStanding(
    val result: RaceResult,
    val discipline: Discipline,
    val seconds: Int,
    val rank: Int,
    val gapToBest: Int,
) {
    val id: String get() = result.id + discipline.name
    val isPersonalBest: Boolean get() = rank == 1
}

data class PersonalBest(val discipline: Discipline, val seconds: Int, val result: RaceResult) {
    val id: String get() = discipline.name + result.id
}

/** Where one time sits inside the field that raced it. 0-100, higher is faster. */
data class FieldPlacement(val discipline: Discipline, val percentile: Int, val rank: Int, val fieldSize: Int)

data class LegShare(val discipline: Discipline, val share: Double, val seconds: Int)

data class CareerSummary(
    val starts: Int,
    val finishes: Int,
    val didNotFinish: Int,
    val fullDistance: Int,
    val halfDistance: Int,
    val years: IntRange?,
    val totalRacingSeconds: Int,
    val podiums: Int,
)

/**
 * Every derived number the app shows. Ranking is always scoped to one
 * [RaceKind]: a half bike split will always beat a full one.
 */
object RaceAnalytics {
    fun comparable(results: List<RaceResult>, kind: RaceKind?): List<RaceResult> =
        results.filter { it.kind.isSupported && it.isComplete && (kind == null || it.kind == kind) }

    /** Most-raced first, so a fourteen-half athlete does not land on their one full. */
    fun availableKinds(results: List<RaceResult>): List<RaceKind> {
        val counts = linkedMapOf<RaceKind, Int>()
        results.filter { it.isComplete && it.kind.isSupported }.forEach { counts[it.kind] = (counts[it.kind] ?: 0) + 1 }
        return counts.entries
            .sortedWith(compareByDescending<Map.Entry<RaceKind, Int>> { it.value }.thenBy { it.key.rawValue })
            .map { it.key }
    }

    fun standings(results: List<RaceResult>, discipline: Discipline, kind: RaceKind?): List<SplitStanding> {
        val timed = comparable(results, kind)
            .mapNotNull { result -> result.seconds(discipline)?.takeIf { it > 0 }?.let { result to it } }
            .sortedBy { it.second }
        val best = timed.firstOrNull()?.second ?: return emptyList()
        return timed.mapIndexed { index, (result, seconds) ->
            SplitStanding(result, discipline, seconds, index + 1, seconds - best)
        }
    }

    fun personalBest(results: List<RaceResult>, discipline: Discipline, kind: RaceKind?): PersonalBest? =
        standings(results, discipline, kind).firstOrNull()?.let { PersonalBest(discipline, it.seconds, it.result) }

    fun personalBests(results: List<RaceResult>, kind: RaceKind?): List<PersonalBest> =
        Discipline.rankable.mapNotNull { personalBest(results, it, kind) }

    /** A first race at a distance is not a personal best: it needs something to beat. */
    fun isPersonalBest(result: RaceResult, discipline: Discipline, within: List<RaceResult>): Boolean {
        val seconds = result.seconds(discipline)
        if (!result.isComplete || seconds == null || seconds <= 0) return false
        val ranked = standings(within, discipline, result.kind)
        if (ranked.size <= 1) return false
        return ranked.first().result.id == result.id
    }

    fun placement(result: RaceResult, discipline: Discipline, field: List<RaceResult>): FieldPlacement? {
        val finishers = field.filter { it.isComplete && (it.seconds(discipline) ?: 0) > 0 }
        val mine = result.seconds(discipline)
        if (finishers.size <= 1 || mine == null || mine <= 0) return null
        val faster = finishers.count { (it.seconds(discipline) ?: Int.MAX_VALUE) < mine }
        val rank = faster + 1
        val percentile = ((finishers.size - rank).toDouble() / (finishers.size - 1) * 100).roundToInt()
        return FieldPlacement(discipline, percentile.coerceIn(0, 100), rank, finishers.size)
    }

    /** Legs as fractions of their own sum, so the bar always fills its track. */
    fun legShares(result: RaceResult): List<LegShare> {
        val pairs = Discipline.legs.mapNotNull { leg -> result.seconds(leg)?.takeIf { it > 0 }?.let { leg to it } }
        val total = pairs.sumOf { it.second }
        if (total <= 0) return emptyList()
        return pairs.map { LegShare(it.first, it.second.toDouble() / total, it.second) }
    }

    fun summary(results: List<RaceResult>): CareerSummary {
        val started = results.filter { it.kind.isSupported && !it.didNotStart }
        val finished = started.filter { it.isComplete }
        val years = started.map { it.year }.filter { it > 0 }
        return CareerSummary(
            starts = started.size,
            finishes = finished.size,
            didNotFinish = started.count { it.didNotFinish || it.disqualified },
            fullDistance = finished.count { it.kind == RaceKind.FULL_DISTANCE },
            halfDistance = finished.count { it.kind == RaceKind.HALF_DISTANCE },
            years = if (years.isEmpty()) null else years.min()..years.max(),
            totalRacingSeconds = finished.sumOf { it.finish ?: 0 },
            podiums = finished.count { (it.finishRankGroup ?: Int.MAX_VALUE) <= 3 },
        )
    }
}

data class RaceBookLegDelta(val discipline: Discipline, val earlierSeconds: Int, val laterSeconds: Int) {
    val change: Int get() = laterSeconds - earlierSeconds
    val improved: Boolean get() = change < 0
}

data class RaceBookProgressionPoint(val result: RaceResult, val seconds: Int) {
    val id: String get() = result.id
}

/** What an export includes. Also the contract between the builder and the PDF. */
data class RaceBookOptions(
    val kinds: Set<RaceKind> = RaceKind.supported.toSet(),
    val includeCareerSummary: Boolean = true,
    val includePodiumHighlights: Boolean = true,
    val includePersonalBests: Boolean = true,
    val includeProgression: Boolean = true,
    val includeRaceHistory: Boolean = true,
    val includeSplits: Boolean = true,
    val includePlacements: Boolean = true,
    val includeRaceNotes: Boolean = false,
    val includeIncomplete: Boolean = false,
    val onePage: Boolean = false,
)

/** Free calculations for the Race Book preview and its paid comparison. */
object RaceBookAnalytics {
    fun comparableRaces(results: List<RaceResult>, kind: RaceKind?): List<RaceResult> =
        results.filter { it.kind.isSupported && it.isComplete && (kind == null || it.kind == kind) }
            .sortedByDateDescending()

    fun deltas(earlier: RaceResult, later: RaceResult): List<RaceBookLegDelta> {
        if (earlier.kind != later.kind) return emptyList()
        return Discipline.rankable.mapNotNull { discipline ->
            val a = earlier.seconds(discipline)?.takeIf { it > 0 } ?: return@mapNotNull null
            val b = later.seconds(discipline)?.takeIf { it > 0 } ?: return@mapNotNull null
            RaceBookLegDelta(discipline, a, b)
        }
    }

    fun progression(results: List<RaceResult>, discipline: Discipline, kind: RaceKind?): List<RaceBookProgressionPoint> =
        comparableRaces(results, kind).reversed().mapNotNull { result ->
            result.seconds(discipline)?.takeIf { it > 0 }?.let { RaceBookProgressionPoint(result, it) }
        }

    fun bests(results: List<RaceResult>, kind: RaceKind?): List<PersonalBest> = RaceAnalytics.personalBests(results, kind)

    fun filteredResults(results: List<RaceResult>, options: RaceBookOptions): List<RaceResult> =
        results.filter { it.kind.isSupported && it.kind in options.kinds }
            .filter { options.includeIncomplete || it.isComplete }
            .sortedByDateDescending()
}
