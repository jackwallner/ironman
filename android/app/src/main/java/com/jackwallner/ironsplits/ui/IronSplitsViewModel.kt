package com.jackwallner.ironsplits.ui

import android.app.Activity
import android.app.Application
import android.media.MediaPlayer
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.jackwallner.ironsplits.billing.RevenueCatStore
import com.jackwallner.ironsplits.data.LocalStore
import com.jackwallner.ironsplits.data.PointerMediaCache
import com.jackwallner.ironsplits.data.ResultsRepository
import com.jackwallner.ironsplits.data.TipCatalog
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class AppTab(val title: String) {
    LOCKER("Locker"), EXPLORE("Explore"), TIPS("Tips"), RACE_BOOK("Race Book"), SETTINGS("Settings");
}

enum class TipsSection(val title: String) {
    ASK("Ask Pattie"), EPISODES("Episodes");
}

data class AppUiState(
    val tab: AppTab = AppTab.LOCKER,
    val lockerAthlete: Athlete? = null,
    val lockerResults: List<RaceResult> = emptyList(),
    val profile: Athlete? = null,
    val profileResults: List<RaceResult> = emptyList(),
    val isClaimingProfile: Boolean = false,
    val recentAthletes: List<Athlete> = emptyList(),
    val searchQuery: String = "",
    val searchResults: List<Athlete> = emptyList(),
    val isSearching: Boolean = false,
    val isSubstringSearch: Boolean = false,
    val slowSearchAvailable: Boolean = false,
    val searchError: String? = null,
    val loadingResults: Boolean = false,
    val selectedKind: RaceKind? = null,
    val selectedDiscipline: Discipline = Discipline.FINISH,
    val selectedResult: RaceResult? = null,
    val detailOrigin: AppTab = AppTab.LOCKER,
    val fieldResults: List<RaceResult> = emptyList(),
    val loadingField: Boolean = false,
    val raceNote: String = "",
    val isPro: Boolean = false,
    val purchasesConfigured: Boolean = false,
    val lifetimePrice: String? = null,
    val loadingPrice: Boolean = false,
    val isPurchasing: Boolean = false,
    val paywallMessage: String? = null,
    val restoreMessage: String? = null,
    val tipsSection: TipsSection = TipsSection.ASK,
    val selectedGoalId: String? = null,
    val selectedTopicId: String? = null,
    val selectedAnswerId: String? = null,
    val episodes: List<com.jackwallner.ironsplits.data.PointerEpisode> = emptyList(),
    val selectedEpisode: com.jackwallner.ironsplits.data.PointerEpisode? = null,
    val loadingTips: Boolean = false,
    val loadingVideo: Boolean = false,
    val videoPath: String? = null,
    val playingVoiceClip: String? = null,
    val statusMessage: String? = null,
)

class IronSplitsViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = ResultsRepository(application)
    private val localStore = LocalStore(application)
    private val store = RevenueCatStore(application)
    private val tipCatalog = TipCatalog(application)
    private val mediaCache = PointerMediaCache(application)
    private val _state = MutableStateFlow(
        AppUiState(
            lockerAthlete = localStore.athlete(),
            lockerResults = localStore.results(),
            recentAthletes = localStore.recentAthletes(),
            purchasesConfigured = store.isConfigured,
        ),
    )
    val state: StateFlow<AppUiState> = _state.asStateFlow()
    private var searchJob: Job? = null
    private var profileJob: Job? = null
    private var saveLoadedProfileToLocker = false
    private var audioPlayer: MediaPlayer? = null

    init {
        store.refreshEntitlement { unlocked -> update { it.copy(isPro = unlocked) } }
        if (_state.value.lockerAthlete != null) loadLocker()
        loadEpisodes()
    }

    fun selectTab(tab: AppTab) {
        update { it.copy(tab = tab, selectedResult = null) }
        if (tab == AppTab.RACE_BOOK) loadLifetimePrice()
    }
    fun selectKind(kind: RaceKind) = update { it.copy(selectedKind = kind) }
    fun selectDiscipline(discipline: Discipline) = update { it.copy(selectedDiscipline = discipline) }

    fun onSearchQueryChanged(query: String) {
        searchJob?.cancel()
        update { it.copy(searchQuery = query, searchError = null, slowSearchAvailable = false, searchResults = emptyList()) }
        if (query.trim().length < 2) {
            update { it.copy(isSearching = false, isSubstringSearch = false) }
            return
        }
        searchJob = viewModelScope.launch {
            delay(400)
            runSearch(query, substring = false)
        }
    }

    fun searchNow() {
        val query = _state.value.searchQuery
        if (query.trim().length < 2) return
        searchJob?.cancel()
        searchJob = viewModelScope.launch { runSearch(query, substring = false) }
    }

    fun searchWithinName() {
        val query = _state.value.searchQuery
        if (query.trim().length < 2) return
        searchJob?.cancel()
        searchJob = viewModelScope.launch { runSearch(query, substring = true) }
    }

    fun stopSearch() {
        searchJob?.cancel()
        update { it.copy(isSearching = false, isSubstringSearch = false, statusMessage = "Search stopped.") }
    }

    private suspend fun runSearch(query: String, substring: Boolean) {
        update {
            it.copy(
                isSearching = true,
                isSubstringSearch = substring,
                slowSearchAvailable = false,
                searchError = null,
                searchResults = emptyList(),
            )
        }
        try {
            val athletes = repository.searchAthletes(query, substring)
            update {
                it.copy(
                    isSearching = false,
                    isSubstringSearch = false,
                    searchResults = athletes,
                    slowSearchAvailable = athletes.isEmpty() && !substring,
                    searchError = null,
                )
            }
        } catch (error: Exception) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            update {
                it.copy(
                    isSearching = false,
                    isSubstringSearch = false,
                    searchError = error.message ?: "The results service is unavailable. Try again shortly.",
                    slowSearchAvailable = !substring,
                )
            }
        }
    }

    fun openAthlete(athlete: Athlete, saveToLocker: Boolean = false) {
        profileJob?.cancel()
        saveLoadedProfileToLocker = saveToLocker
        localStore.addRecentAthlete(athlete)
        update {
                it.copy(
                    profile = athlete,
                    profileResults = emptyList(),
                    loadingResults = true,
                    isClaimingProfile = saveToLocker,
                recentAthletes = localStore.recentAthletes(),
                selectedKind = null,
            )
        }
        profileJob = viewModelScope.launch {
            try {
                val results = repository.resultsForAthlete(athlete.contactIds.ifEmpty { listOf(athlete.id) })
                if (saveLoadedProfileToLocker) {
                    localStore.saveAthlete(athlete)
                    localStore.saveResults(results)
                    saveLoadedProfileToLocker = false
                    update {
                        it.copy(
                            lockerAthlete = athlete,
                            lockerResults = results,
                            selectedKind = mostRacedKind(results),
                            profile = null,
                            profileResults = emptyList(),
                            loadingResults = false,
                            isClaimingProfile = false,
                            searchError = null,
                            searchResults = emptyList(),
                        )
                    }
                } else {
                    update { it.copy(profileResults = results, loadingResults = false, isClaimingProfile = false) }
                }
            } catch (error: Exception) {
                if (error is kotlinx.coroutines.CancellationException) throw error
                saveLoadedProfileToLocker = false
                update { it.copy(loadingResults = false, isClaimingProfile = false, searchError = error.message) }
            }
        }
    }

    fun closeProfile() = update { it.copy(profile = null, profileResults = emptyList(), loadingResults = false) }

    fun saveProfileToLocker() {
        val athlete = _state.value.profile ?: return
        val results = _state.value.profileResults
        localStore.saveAthlete(athlete)
        localStore.saveResults(results)
        update {
            it.copy(
                lockerAthlete = athlete,
                lockerResults = results,
                selectedKind = RaceKind.HALF.takeIf { kind -> results.count { row -> row.kind == kind && row.isComplete } >
                    results.count { row -> row.kind == RaceKind.FULL && row.isComplete } }
                    ?: RaceKind.FULL.takeIf { kind -> results.any { row -> row.kind == kind && row.isComplete } }
                    ?: RaceKind.HALF.takeIf { kind -> results.any { row -> row.kind == kind && row.isComplete } },
                tab = AppTab.LOCKER,
                profile = null,
                profileResults = emptyList(),
                searchError = null,
                searchResults = emptyList(),
            )
        }
    }

    fun unclaimAthlete() {
        localStore.clearLocker()
        update { it.copy(lockerAthlete = null, lockerResults = emptyList(), selectedKind = null, profile = null) }
    }

    private fun loadLocker() {
        val athlete = _state.value.lockerAthlete ?: return
        viewModelScope.launch {
            update { it.copy(loadingResults = true) }
            try {
                val results = repository.resultsForAthlete(athlete.contactIds.ifEmpty { listOf(athlete.id) })
                localStore.saveResults(results)
                update {
                    it.copy(
                        lockerResults = results,
                        selectedKind = it.selectedKind ?: mostRacedKind(results),
                        loadingResults = false,
                    )
                }
            } catch (error: Exception) {
                update {
                    it.copy(
                        loadingResults = false,
                        statusMessage = if (it.lockerResults.isEmpty()) error.message else "Showing saved results. Refresh when you have service.",
                    )
                }
            }
        }
    }

    fun openRace(result: RaceResult, origin: AppTab = _state.value.tab) {
        update {
            it.copy(
                selectedResult = result,
                detailOrigin = origin,
                fieldResults = emptyList(),
                loadingField = true,
                raceNote = localStore.note(result.id),
            )
        }
        viewModelScope.launch {
            runCatching { repository.resultsForEvent(result.eventId) }
                .onSuccess { rows -> update { it.copy(fieldResults = rows, loadingField = false) } }
                .onFailure { update { it.copy(loadingField = false) } }
        }
    }

    fun closeRace() = update { it.copy(selectedResult = null, tab = it.detailOrigin) }
    fun saveRaceNote(value: String) {
        val id = _state.value.selectedResult?.id ?: return
        localStore.saveNote(id, value)
        update { it.copy(raceNote = value.take(2_000)) }
    }

    fun chooseTipsSection(section: TipsSection) = update { it.copy(tipsSection = section, selectedAnswerId = null) }
    fun chooseGoal(goalId: String) = update { it.copy(selectedGoalId = goalId, selectedTopicId = null, selectedAnswerId = null) }
    fun chooseTopic(topicId: String) = update { it.copy(selectedTopicId = topicId, selectedAnswerId = null) }
    fun chooseAnswer(answerId: String) = update { it.copy(selectedAnswerId = answerId) }
    fun backAskPattie() = update {
        when {
            it.selectedAnswerId != null -> it.copy(selectedAnswerId = null)
            it.selectedTopicId != null -> it.copy(selectedTopicId = null)
            it.selectedGoalId != null -> it.copy(selectedGoalId = null)
            else -> it
        }
    }

    fun refreshTips() = loadEpisodes(refresh = true)

    val pattieGoals get() = tipCatalog.goals
    val pattieTopics get() = tipCatalog.topics
    val pattieAnswers get() = tipCatalog.answers
    fun pattieGoal(id: String?) = tipCatalog.goal(id)
    fun pattieTopic(id: String?) = tipCatalog.topic(id)

    private fun loadEpisodes(refresh: Boolean = false) {
        viewModelScope.launch {
            update { it.copy(loadingTips = true) }
            runCatching { tipCatalog.refreshAsk(refresh) }
            val episodes = runCatching { tipCatalog.episodes(refresh) }.getOrDefault(emptyList())
            update { it.copy(episodes = episodes, loadingTips = false) }
        }
    }

    fun playEpisode(episode: com.jackwallner.ironsplits.data.PointerEpisode) {
        val link = episode.linkUrl
        if (link != null) {
            update { it.copy(statusMessage = "This tip opens in your browser.", selectedEpisode = episode) }
            return
        }
        update { it.copy(selectedEpisode = episode, loadingVideo = true, videoPath = null) }
        viewModelScope.launch {
            runCatching { mediaCache.videoFile(episode) }
                .onSuccess { file -> update { it.copy(loadingVideo = false, videoPath = file.absolutePath) } }
                .onFailure { error -> update { it.copy(loadingVideo = false, statusMessage = error.message) } }
        }
    }

    fun closeEpisode() = update { it.copy(selectedEpisode = null, videoPath = null, loadingVideo = false) }

    fun voiceFile(clip: String?): String? = tipCatalog.voiceAsset(clip)?.let { mediaCache.voiceFile(it)?.absolutePath }

    fun toggleVoiceClip(clip: String?) {
        val safeClip = tipCatalog.voiceAsset(clip) ?: return
        if (_state.value.playingVoiceClip == safeClip) {
            audioPlayer?.release()
            audioPlayer = null
            update { it.copy(playingVoiceClip = null) }
            return
        }
        val file = mediaCache.voiceFile(safeClip) ?: return
        audioPlayer?.release()
        val player = MediaPlayer()
        audioPlayer = player
        update { it.copy(playingVoiceClip = safeClip) }
        player.setOnPreparedListener { if (audioPlayer === player) player.start() }
        player.setOnCompletionListener {
            if (audioPlayer === player) {
                player.release()
                audioPlayer = null
                update { it.copy(playingVoiceClip = null) }
            }
        }
        player.setOnErrorListener { failed, _, _ ->
            if (audioPlayer === failed) {
                failed.release()
                audioPlayer = null
                update { it.copy(playingVoiceClip = null, statusMessage = "That voice clip could not be played.") }
            }
            true
        }
        runCatching {
            player.setDataSource(file.absolutePath)
            player.prepareAsync()
        }.onFailure {
            player.release()
            audioPlayer = null
            update { it.copy(playingVoiceClip = null, statusMessage = "That voice clip could not be played.") }
        }
    }

    fun refreshEntitlement() {
        store.refreshEntitlement { unlocked -> update { it.copy(isPro = unlocked) } }
    }

    fun loadLifetimePrice() {
        if (!store.isConfigured) return
        update { it.copy(loadingPrice = true) }
        store.loadLifetimePrice { price -> update { it.copy(lifetimePrice = price, loadingPrice = false) } }
    }

    fun buyRaceBook(activity: Activity) {
        update { it.copy(isPurchasing = true, paywallMessage = null) }
        store.purchaseLifetime(activity) { unlocked, message ->
            update { it.copy(isPurchasing = false, isPro = unlocked || it.isPro, paywallMessage = message) }
        }
    }

    fun restorePurchases() {
        update { it.copy(restoreMessage = null) }
        store.restore { unlocked, message ->
            update { it.copy(isPro = unlocked || it.isPro, restoreMessage = message ?: "Race Book purchase restored.") }
        }
    }

    fun dismissMessage() = update { it.copy(statusMessage = null, searchError = null) }

    private fun mostRacedKind(results: List<RaceResult>): RaceKind? =
        com.jackwallner.ironsplits.data.RaceAnalytics.availableKinds(results).firstOrNull()

    private fun update(transform: (AppUiState) -> AppUiState) {
        _state.value = transform(_state.value)
    }

    override fun onCleared() {
        audioPlayer?.release()
        audioPlayer = null
        super.onCleared()
    }
}
