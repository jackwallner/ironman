package com.jackwallner.ironsplits.data

import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult

data class SplitStanding(
    val result: RaceResult,
    val discipline: Discipline,
    val seconds: Int,
    val rank: Int,
    val gapToBest: Int,
)

data class PersonalBest(val discipline: Discipline, val seconds: Int, val result: RaceResult)

data class FieldPlacement(val percentile: Int, val rank: Int, val fieldSize: Int)

data class CareerSummary(
    val starts: Int,
    val finishes: Int,
    val didNotFinish: Int,
    val fullDistance: Int,
    val halfDistance: Int,
    val firstYear: Int?,
    val lastYear: Int?,
    val totalRacingSeconds: Int,
    val podiums: Int,
) {
    val finishRate: Double get() = if (starts > 0) finishes.toDouble() / starts else 0.0
}

object RaceAnalytics {
    fun comparable(results: List<RaceResult>, kind: RaceKind?): List<RaceResult> =
        results.filter { it.kind.isSupported && it.isComplete && (kind == null || it.kind == kind) }

    fun availableKinds(results: List<RaceResult>): List<RaceKind> = results
        .filter { it.kind.isSupported && it.isComplete }
        .groupingBy(RaceResult::kind)
        .eachCount()
        .entries
        .sortedWith(compareByDescending<Map.Entry<RaceKind, Int>> { it.value }.thenBy { it.key.name })
        .map { it.key }

    fun standings(results: List<RaceResult>, discipline: Discipline, kind: RaceKind?): List<SplitStanding> {
        val timed = comparable(results, kind)
            .mapNotNull { result -> result.seconds(discipline)?.takeIf { it > 0 }?.let { result to it } }
            .sortedBy { it.second }
        val best = timed.firstOrNull()?.second ?: return emptyList()
        return timed.mapIndexed { index, (result, seconds) ->
            SplitStanding(result, discipline, seconds, index + 1, seconds - best)
        }
    }

    fun personalBests(results: List<RaceResult>, kind: RaceKind?): List<PersonalBest> =
        Discipline.rankings.mapNotNull { discipline ->
            standings(results, discipline, kind).firstOrNull()?.let {
                PersonalBest(discipline, it.seconds, it.result)
            }
        }

    fun isPersonalBest(result: RaceResult, discipline: Discipline, allResults: List<RaceResult>): Boolean {
        if (!result.isComplete || (result.seconds(discipline) ?: 0) <= 0) return false
        val ranking = standings(allResults, discipline, result.kind)
        return ranking.size > 1 && ranking.first().result.id == result.id
    }

    fun placement(result: RaceResult, discipline: Discipline, field: List<RaceResult>): FieldPlacement? {
        val finishers = field.filter { it.isComplete && (it.seconds(discipline) ?: 0) > 0 }
        val mine = result.seconds(discipline)?.takeIf { it > 0 } ?: return null
        if (finishers.size < 2) return null
        val rank = finishers.count { (it.seconds(discipline) ?: Int.MAX_VALUE) < mine } + 1
        val percentile = (((finishers.size - rank).toDouble() / (finishers.size - 1)) * 100).toInt()
        return FieldPlacement(percentile.coerceIn(0, 100), rank, finishers.size)
    }

    fun summary(results: List<RaceResult>): CareerSummary {
        val starts = results.filter { it.kind.isSupported && !it.didNotStart }
        val finishes = starts.filter(RaceResult::isComplete)
        val years = starts.map(RaceResult::year).filter { it > 0 }
        return CareerSummary(
            starts = starts.size,
            finishes = finishes.size,
            didNotFinish = starts.count { it.didNotFinish || it.disqualified },
            fullDistance = finishes.count { it.kind == RaceKind.FULL },
            halfDistance = finishes.count { it.kind == RaceKind.HALF },
            firstYear = years.minOrNull(),
            lastYear = years.maxOrNull(),
            totalRacingSeconds = finishes.sumOf { it.finish ?: 0 },
            podiums = finishes.count { (it.finishRankGroup ?: Int.MAX_VALUE) <= 3 },
        )
    }

    fun legShares(result: RaceResult): List<Pair<Discipline, Double>> {
        val values = Discipline.raceLegs.mapNotNull { leg ->
            result.seconds(leg)?.takeIf { it > 0 }?.let { leg to it }
        }
        val total = values.sumOf { it.second }
        if (total <= 0) return emptyList()
        return values.map { it.first to it.second.toDouble() / total }
    }
}
