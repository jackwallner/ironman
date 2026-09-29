package com.jackwallner.ironsplits.data

import android.content.Context
import android.text.format.DateUtils
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

sealed interface LoadState {
    data object Idle : LoadState
    data object Loading : LoadState
    data object Loaded : LoadState
    data class Failed(val message: String) : LoadState
}

data class LockerState(
    val athlete: Athlete? = null,
    val results: List<RaceResult> = emptyList(),
    val loadState: LoadState = LoadState.Idle,
    val lastRefreshed: Long? = null,
    val refreshWarning: String? = null,
) {
    val hasClaimedAthlete: Boolean get() = athlete != null
    val availableKinds: List<RaceKind> get() = RaceAnalytics.availableKinds(results)
}

/**
 * The athlete's own results, cached on disk and refreshed from the feed. The
 * cache is the point: a locker opened on a start line with one bar of signal
 * should still show every bib number.
 */
class LockerStore(
    context: Context,
    private val api: ResultsProviding,
    private val configLoader: FeedConfigLoader,
    private val scope: CoroutineScope,
) {
    private val file = File(context.filesDir, "locker.json")
    private val _state = MutableStateFlow(LockerState())
    val state: StateFlow<LockerState> = _state.asStateFlow()

    /** Invalidates an older response when a newer claim or refresh starts. */
    private var refreshGeneration = 0
    private var refreshingContactIds: List<String>? = null

    init {
        load()?.let { snapshot ->
            _state.value = LockerState(
                athlete = snapshot.first,
                results = snapshot.second.filter { it.kind.isSupported },
                loadState = LoadState.Loaded,
                lastRefreshed = snapshot.third,
            )
        }
    }

    val current: LockerState get() = _state.value

    /**
     * Network work runs in the app scope, not the calling screen's: claiming
     * from onboarding replaces that screen, and a refresh must not die with it.
     */
    fun claim(athlete: Athlete): Job {
        refreshGeneration++
        _state.value = LockerState(athlete = athlete, loadState = LoadState.Loading)
        return refresh(force = true)
    }

    /**
     * Add another official contact record to the current athlete, the recovery
     * path for a race entered under a different name. Nothing is invented locally.
     */
    fun addContact(candidate: Athlete): Job {
        val existing = current.athlete ?: return claim(candidate)
        val merged = (existing.contactIds + candidate.contactIds).distinct()
        if (merged == existing.contactIds) return Job().apply { complete() }
        refreshGeneration++
        _state.update {
            it.copy(
                athlete = existing.copy(
                    contactIds = merged,
                    knownRaceCount = maxOf(existing.knownRaceCount, candidate.knownRaceCount),
                ),
                results = emptyList(),
                loadState = LoadState.Loading,
                refreshWarning = null,
            )
        }
        return refresh(force = true)
    }

    fun unclaim() {
        refreshGeneration++
        _state.value = LockerState()
        file.delete()
    }

    /**
     * A failed refresh over a cached locker is not worth interrupting anyone:
     * the screen is still correct, just not newer.
     */
    fun refresh(force: Boolean = false): Job = scope.launch { refreshNow(force) }

    private suspend fun refreshNow(force: Boolean) {
        val athlete = current.athlete ?: return
        val last = current.lastRefreshed
        if (!force && last != null && System.currentTimeMillis() - last < 30 * 60 * 1_000L) return
        val contactIds = athlete.contactIds
        if (refreshingContactIds == contactIds) return
        refreshingContactIds = contactIds
        refreshGeneration++
        val generation = refreshGeneration
        _state.update { it.copy(refreshWarning = null, loadState = if (it.results.isEmpty()) LoadState.Loading else it.loadState) }
        scope.launch { configLoader.refreshIfStale() }
        try {
            val fetched = api.results(contactIds)
            if (generation != refreshGeneration || current.athlete?.contactIds != contactIds) return
            val now = System.currentTimeMillis()
            _state.update {
                it.copy(
                    results = fetched.filter { result -> result.kind.isSupported },
                    lastRefreshed = now,
                    loadState = LoadState.Loaded,
                    refreshWarning = null,
                )
            }
            persist()
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            if (generation != refreshGeneration || current.athlete?.contactIds != contactIds) return
            var warning: String? = if (error is ResultsApiException.PageLimitReached) error.message else null
            if (current.results.isEmpty()) {
                _state.update { it.copy(loadState = LoadState.Failed(ResultsApi.userFacingMessage(error)), refreshWarning = warning) }
            } else {
                if (force) {
                    val updated = current.lastRefreshed?.let(::relativeTime) ?: "earlier"
                    warning = "Couldn't update. Showing results last refreshed $updated."
                }
                _state.update { it.copy(loadState = LoadState.Loaded, refreshWarning = warning) }
            }
        } finally {
            if (refreshingContactIds == contactIds) refreshingContactIds = null
        }
    }

    /** Debug fixtures and UI tests start from a known locker. */
    fun replaceForTesting(athlete: Athlete?, results: List<RaceResult>) {
        refreshGeneration++
        file.delete()
        _state.value = if (athlete == null) LockerState() else LockerState(
            athlete = athlete,
            results = results,
            loadState = LoadState.Loaded,
            lastRefreshed = System.currentTimeMillis(),
        )
    }

    private suspend fun persist() = withContext(Dispatchers.IO) {
        val snapshot = current
        val athlete = snapshot.athlete ?: return@withContext
        val json = JSONObject()
            .put("athlete", Codec.athlete(athlete))
            .put("results", JSONArray().apply { snapshot.results.forEach { put(Codec.result(it)) } })
            .put("refreshedAt", snapshot.lastRefreshed ?: System.currentTimeMillis())
        val temp = File(file.parentFile, "locker.json.tmp")
        temp.writeText(json.toString())
        temp.renameTo(file)
    }

    private fun load(): Triple<Athlete, List<RaceResult>, Long>? = runCatching {
        if (!file.exists()) return null
        val json = JSONObject(file.readText())
        val athlete = Codec.athlete(json.getJSONObject("athlete")) ?: return null
        Triple(athlete, Codec.results(json.optJSONArray("results")), json.optLong("refreshedAt"))
    }.getOrNull()
}

/** "now", "5 minutes ago", "yesterday". */
fun relativeTime(millis: Long, now: Long = System.currentTimeMillis()): String {
    if (now - millis < 60_000L) return "now"
    return DateUtils.getRelativeTimeSpanString(millis, now, DateUtils.MINUTE_IN_MILLIS).toString()
}
