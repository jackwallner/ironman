package com.jackwallner.ironsplits.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Pattie Mode: a small Pattie in the corner who offers one useful tip at a
 * time. Off on a first install. The budget keeps it fun rather than
 * exhausting: a quiet gap behind every moment, per-moment cooldowns, and no
 * tip repeats until the whole pool has been started.
 */
class PattieMode(
    context: Context,
    private val voice: PattieVoice,
    private val tips: () -> List<PattieVoiceLibrary.ModeTip>,
    private val onPresent: () -> Unit,
) {
    enum class Moment(val cooldownMs: Long) {
        ACTION(2_500),
        WELCOME(Long.MAX_VALUE),
        CLAIMED(Long.MAX_VALUE),
        SEARCHING(240_000),
        RACE_OPENED(240_000),
        PERSONAL_BEST(90_000),
        DID_NOT_FINISH(240_000),
        WORLD_CHAMPIONSHIP(90_000),
        BESTS(240_000),
        BESTS_FILTERED(240_000),
        RESUME(240_000),
        RESUME_EXPORTED(240_000),
        POINTERS(240_000),
        ASK_OPENED(240_000),
        ASK_ANSWERED(90_000),
        NOTE_SAVED(240_000),
        VETERAN(Long.MAX_VALUE),
        REFRESHED(240_000),
        SETTINGS(240_000),
    }

    enum class Action { TAB, FILTER, SELECTION, SEARCH, CHOICE, SAVE, EXPORT, PLAY, REFRESH, TAP, BACK }

    data class Line(
        val id: String,
        val moment: Moment,
        val text: String,
        val voice: String? = null,
        val action: Action? = null,
        val petState: PattiePetState = PattiePetState.IDLE,
        val isGiantCatchphrase: Boolean = false,
        /** Unique per presentation, so a replayed line restarts its timer. */
        val presentationId: Long = 0,
    ) {
        val defaultPetState: PattiePetState
            get() = when (id) {
                "claimed-1", "claimed-2", "pb-1", "pb-2", "worlds-1", "veteran-1", "resume-2" -> PattiePetState.CELEBRATE
                "dnf-1", "dnf-2", "race-4", "ask-answered-2" -> PattiePetState.ENCOURAGE
                "race-2", "refresh-1" -> PattiePetState.BIKE
                "bests-1", "bests-2", "bests-filter-1", "bests-filter-2", "search-1", "search-2", "resume-1",
                "pointers-1", "pointers-2", "ask-1", "ask-2",
                "action-tab-1", "action-tab-2", "action-filter-1", "action-filter-2", "action-selection-1",
                "action-selection-2", "action-search-1", "action-search-2", "action-choice-1", "action-choice-2",
                "race-1", "race-3", "settings-1" -> PattiePetState.COACH
                "action-save-1", "action-save-2", "action-export-1", "action-export-2", "note-1" -> PattiePetState.ENCOURAGE
                else -> PattiePetState.IDLE
            }
    }

    private val defaults = context.getSharedPreferences("pattie.mode", Context.MODE_PRIVATE)
    private val _enabled = MutableStateFlow(defaults.getBoolean(ENABLED_KEY, false))
    val enabled: StateFlow<Boolean> = _enabled.asStateFlow()
    private val _current = MutableStateFlow<Line?>(null)
    val current: StateFlow<Line?> = _current.asStateFlow()

    private val firedAt = mutableMapOf<Moment, Long>()
    private val firedActions = mutableMapOf<Action, Long>()
    private var lastFired: Long? = null
    private var lastAutomaticReactionAt: Long? = null
    private var pointerPlaybackActive = false
    private var presentationCounter = 0L

    var isEnabled: Boolean
        get() = _enabled.value
        set(value) {
            if (value == _enabled.value) return
            _enabled.value = value
            defaults.edit().putBoolean(ENABLED_KEY, value).apply()
            if (!value) dismiss()
        }

    /** A meaningful screen moment. Lands only when the budget allows it. */
    fun fire(moment: Moment, petState: PattiePetState? = null) {
        if (!isEnabled || pointerPlaybackActive || _current.value != null || voice.isSpeaking) return
        val now = System.currentTimeMillis()
        firedAt[moment]?.let { if (moment.cooldownMs == Long.MAX_VALUE || now - it < moment.cooldownMs) return }
        lastFired?.let { if (now - it < QUIET_PERIOD_MS) return }
        val line = pick(DECK.filter { it.moment == moment }) ?: return
        present(line, petState = petState)
    }

    /** A small interaction, replacing the bubble in place. At most one a minute or so. */
    fun react(action: Action, petState: PattiePetState? = null) {
        if (!isEnabled || pointerPlaybackActive || voice.isSpeaking) return
        val now = System.currentTimeMillis()
        lastAutomaticReactionAt?.let { if (now - it < AUTOMATIC_REACTION_INTERVAL_MS) return }
        firedActions[action]?.let { if (now - it < ACTION_COOLDOWN_MS) return }
        if (action != Action.BACK) lastFired?.let { if (now - it < QUIET_PERIOD_MS) return }
        val line = pick(DECK.filter { it.action == action }) ?: return
        lastAutomaticReactionAt = now
        present(line, petState = petState)
    }

    /** Preview one now, ignoring the budget. Used by Settings and the idle avatar. */
    fun demo() {
        if (pointerPlaybackActive) return
        val line = DECK.firstOrNull { it.action == Action.TAP } ?: return
        present(line, respectingBudget = false, companionAudio = false)
    }

    /** A pointer video shares the audio; a companion clip must never play over it. */
    fun beginPointerPlayback() {
        pointerPlaybackActive = true
        dismiss()
    }

    fun endPointerPlayback() {
        pointerPlaybackActive = false
    }

    fun replayVoice() {
        val line = _current.value ?: return
        voice.toggle(line.voice)
    }

    fun dismiss() {
        voice.stop()
        _current.value = null
    }

    fun resetForTesting(enabled: Boolean) {
        defaults.edit().clear().putBoolean(ENABLED_KEY, enabled).apply()
        _enabled.value = enabled
        _current.value = null
        firedAt.clear()
        firedActions.clear()
        lastFired = null
        lastAutomaticReactionAt = null
    }

    private fun present(line: Line, respectingBudget: Boolean = true, petState: PattiePetState? = null, companionAudio: Boolean = true) {
        if (pointerPlaybackActive || voice.isSpeaking) return
        var next = line.copy(petState = petState ?: line.defaultPetState, presentationId = ++presentationCounter)
        // The deck decides when; the real answer tree decides what she says.
        if (next.moment == Moment.ACTION && next.action != null) {
            when (val presentation = nextModePresentation()) {
                is ModePresentation.Tip -> next = next.copy(
                    text = presentation.tip.text,
                    voice = presentation.tip.voice,
                    petState = petState ?: PattiePetState.forTopicId(presentation.tip.topic),
                )
                is ModePresentation.Catch -> next = next.copy(
                    text = presentation.catchphrase.text,
                    voice = presentation.catchphrase.voice,
                    petState = PattiePetState.DANCE,
                    isGiantCatchphrase = true,
                )
                null -> Unit
            }
        }
        if (respectingBudget) {
            val now = System.currentTimeMillis()
            firedAt[next.moment] = now
            next.action?.let { firedActions[it] = now }
            lastFired = now
        }
        markSeen(next.id)
        _current.value = next
        onPresent()
        if (companionAudio) voice.playCompanionIfQuiet(next.voice) else voice.playIfQuiet(next.voice)
    }

    private fun pick(candidates: List<Line>): Line? {
        if (candidates.isEmpty()) return null
        val seen = seenLines()
        val fresh = candidates.filter { it.id !in seen }
        return (fresh.ifEmpty { candidates }).random()
    }

    private fun seenLines(): Set<String> = defaults.getStringSet(SEEN_KEY, emptySet()).orEmpty()

    private fun markSeen(id: String) {
        var seen = seenLines() + id
        // Once she has said everything, start the deck over rather than going quiet.
        if (seen.size >= DECK.size) seen = setOf(id)
        defaults.edit().putStringSet(SEEN_KEY, seen).apply()
    }

    private sealed interface ModePresentation {
        data class Tip(val tip: PattieVoiceLibrary.ModeTip) : ModePresentation
        data class Catch(val catchphrase: PattieVoiceLibrary.Catchphrase) : ModePresentation
    }

    /** Every fourth slot is a short celebration instead of another paragraph of advice. */
    private fun nextModePresentation(): ModePresentation? {
        val pool = tips()
        if (pool.isEmpty()) return null
        val slot = maxOf(0, defaults.getInt(TIP_SLOT_KEY, 0)) + 1
        defaults.edit().putInt(TIP_SLOT_KEY, slot).apply()
        if (slot % 4 == 0) {
            val catchphrases = PattieVoiceLibrary.catchphrases
            val index = maxOf(0, defaults.getInt(CATCHPHRASE_INDEX_KEY, 0))
            defaults.edit().putInt(CATCHPHRASE_INDEX_KEY, index + 1).apply()
            return ModePresentation.Catch(catchphrases[index % catchphrases.size])
        }
        val ids = pool.map { it.id }.toSet()
        val played = defaults.getStringSet(PLAYED_KEY, emptySet()).orEmpty().intersect(ids)
        val last = defaults.getString(LAST_TIP_KEY, null)
        val tip = PattieVoiceLibrary.nextModeTip(pool, played, last) ?: return null
        val nextPlayed = (if (played.size >= ids.size) emptySet() else played) + tip.id
        defaults.edit().putStringSet(PLAYED_KEY, nextPlayed).putString(LAST_TIP_KEY, tip.id).apply()
        return ModePresentation.Tip(tip)
    }

    companion object {
        private const val ENABLED_KEY = "pattie.mode.enabled"
        private const val SEEN_KEY = "pattie.mode.seenLines"
        private const val PLAYED_KEY = "pattie.mode.playedTipIDs"
        private const val LAST_TIP_KEY = "pattie.mode.lastTipID"
        private const val TIP_SLOT_KEY = "pattie.mode.tipSlot"
        private const val CATCHPHRASE_INDEX_KEY = "pattie.mode.catchphraseIndex"
        private const val QUIET_PERIOD_MS = 900L
        private const val AUTOMATIC_REACTION_INTERVAL_MS = 75_000L
        private const val ACTION_COOLDOWN_MS = 900L

        private fun action(id: String, text: String, action: Action) = Line(id, Moment.ACTION, text, action = action)

        /** When she appears. The tip catalog supplies what she says for action moments. */
        val DECK = listOf(
            action("action-tab-1", "Here's the situation: a race story is easier to use when the swim, bike, run, and finish stay together. Keep it all in one place.", Action.TAB),
            action("action-tab-2", "Here's the solution: look at the whole pattern, not one shiny number. The useful clue is usually in the split beside it.", Action.TAB),
            action("action-filter-1", "A half and a full are different races. Compare like with like before you call something your best.", Action.FILTER),
            action("action-filter-2", "Different leg, different story. The transition number is often the free time hiding in plain sight.", Action.FILTER),
            action("action-selection-1", "Pick the piece you can practise. Small changes are the ones that make it to race day.", Action.SELECTION),
            action("action-selection-2", "Good choice. If it matters on race day, give it one rehearsal before you need it.", Action.SELECTION),
            action("action-search-1", "Here's the situation: the timing feed knows the name on your registration. Start there, then we can find the rest.", Action.SEARCH),
            action("action-search-2", "Surname first works too. The important thing is matching the entry, not guessing at a nickname.", Action.SEARCH),
            action("action-choice-1", "Here's the solution: choose the race first, then the problem you want to solve. No typing, no invented advice.", Action.CHOICE),
            action("action-choice-2", "That is the useful choice. Take one pointer and try it on a training day before race day.", Action.CHOICE),
            action("action-save-1", "Write down the weather and what went wrong while it is fresh. In two years, that detail will be worth more than the time.", Action.SAVE),
            action("action-save-2", "That is smart racecraft. The small detail you save today becomes your best advice later.", Action.SAVE),
            action("action-export-1", "Away you go. Put the race history in front of the next person who needs to see it.", Action.EXPORT),
            action("action-export-2", "Here's the solution: one clean resume, with the splits that prove the story.", Action.EXPORT),
            action("action-play-1", "Here's the situation, then here's the solution. Listen for the small thing you can try before the next start.", Action.PLAY),
            action("action-play-2", "Press play when you have a quiet minute. These pointers are built from the things that went wrong first.", Action.PLAY),
            action("action-refresh-1", "Fresh results, straight from the timers. If the latest race is not here, it has not been posted yet.", Action.REFRESH),
            action("action-refresh-2", "A refresh checks the official feed again. It cannot make an unpublished result appear early.", Action.REFRESH),
            action("action-tap-1", "One small move at a time. The next useful clue is usually one tap away.", Action.TAP),
            action("action-tap-2", "Good. Keep going. We are looking for the detail that makes the next race easier.", Action.TAP),
            action("action-back-1", "Good, take the pointer with you. You do not need to stay on a screen after you have got the useful bit.", Action.BACK),
            action("action-back-2", "Away you go. The best tip is the one you can try before the next start.", Action.BACK),
            Line("welcome-1", Moment.WELCOME, "Here's the situation: your races are scattered across a dozen result pages. Here's the solution. They're all in here now.", "pattie-here-s-the-situation"),
            Line("welcome-2", Moment.WELCOME, "Every bib, every split, every year. No more digging through old emails the night before a race.", "pattie-here-s-the-solution"),
            Line("search-1", Moment.SEARCHING, "Type your name the way you registered. Full legal first name, usually, whether you like it or not."),
            Line("search-2", Moment.SEARCHING, "Surname first works too. I've spelled mine both ways on an entry form and so has everyone else."),
            Line("claimed-1", Moment.CLAIMED, "There you are. That's your whole career, straight off the timing feed.", "pattie-now-that-s-a-great-idea"),
            Line("claimed-2", Moment.CLAIMED, "Found you. Now you never have to remember a bib number again.", "pattie-nice"),
            Line("race-1", Moment.RACE_OPENED, "Look at your transitions. That's free time sitting right there, and it costs nothing to practise."),
            Line("race-2", Moment.RACE_OPENED, "The bike is where the day is won or thrown away. Everything after it is just holding on.", "pattie-bike"),
            Line("race-3", Moment.RACE_OPENED, "Splits don't lie. They just don't tell you how hot it was that day."),
            Line("race-4", Moment.RACE_OPENED, "Somewhere in this one there's a mile you'd rather not talk about. There is in all of mine too."),
            Line("pb-1", Moment.PERSONAL_BEST, "That's a personal best. Go on, look at it for a minute. You earned that one.", "pattie-that-s-a-great-idea"),
            Line("pb-2", Moment.PERSONAL_BEST, "Best you've ever gone at that distance. Now that's a great idea.", "pattie-now-that-s-a-great-idea"),
            Line("dnf-1", Moment.DID_NOT_FINISH, "A DNF is a day, not a verdict. I've had mine. The next one still counts the same."),
            Line("dnf-2", Moment.DID_NOT_FINISH, "Everybody who races long enough collects one of these. It stays on the record and so do you."),
            Line("worlds-1", Moment.WORLD_CHAMPIONSHIP, "A World Championship start line. Not many people get one of those on their record.", "pattie-good"),
            Line("bests-1", Moment.BESTS, "Best swim, best bike, best run, all scoped to the right distance. A half and a full were never the same race."),
            Line("bests-2", Moment.BESTS, "Sorted by your fastest leg. This is the list you quote at dinner.", "pattie-nice"),
            Line("bests-filter-1", Moment.BESTS_FILTERED, "Different leg, different story. The transitions one is the list nobody wants to look at."),
            Line("bests-filter-2", Moment.BESTS_FILTERED, "Watch the gap column. That number is the whole training plan in one line."),
            Line("resume-1", Moment.RESUME, "Here's the situation: a race wants your history for validation. Here's the solution. Export it and send it.", "pattie-here-s-the-solution"),
            Line("resume-2", Moment.RESUME_EXPORTED, "That's the sheet they ask for, in one tap. Away you go.", "pattie-away-you-go"),
            Line("pointers-1", Moment.POINTERS, "These are my pointers. Little things that cost nothing and save your whole day.", "pattie-away-you-go"),
            Line("pointers-2", Moment.POINTERS, "Every one of these is something that went wrong for me first. That's how the list got written."),
            Line("ask-1", Moment.ASK_OPENED, "Tell me what you're training for and what's bothering you. I've probably already made a clip about it.", "pattie-here-s-the-situation"),
            Line("ask-2", Moment.ASK_OPENED, "Pick the race, pick the problem. No typing, and no waiting on me to answer."),
            Line("ask-answered-1", Moment.ASK_ANSWERED, "That's the one. Tap play and you'll get it in my own words.", "pattie-here-s-the-solution"),
            Line("ask-answered-2", Moment.ASK_ANSWERED, "Try it on a training day first. Race day is a bad time to learn a new trick."),
            Line("note-1", Moment.NOTE_SAVED, "Write down the conditions while you still remember them. In two years that note is worth more than the time."),
            Line("veteran-1", Moment.VETERAN, "That is a lot of start lines. Most people talk about doing one of these. You kept going back.", "pattie-good"),
            Line("refresh-1", Moment.REFRESHED, "Pulled it again, straight from the timers. If your latest race isn't here, they haven't posted it yet."),
            Line("settings-1", Moment.SETTINGS, "If I'm getting on your nerves there's a switch on this very screen. No hard feelings."),
        )
    }
}
