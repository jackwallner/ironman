package com.jackwallner.ironsplits.data

import android.content.Context
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * The Ask Pattie decision tree: pick a goal, pick a topic, get the pointers
 * she already recorded on exactly that. Deterministic, free per question, and
 * it works on a start line with no signal.
 */
data class AskPattieGuide(
    val version: Int,
    val title: String,
    val subtitle: String,
    val goalQuestion: String,
    val goals: List<Goal>,
    val topics: List<Topic>,
    val answers: List<Answer>,
) {
    data class Goal(val id: String, val title: String, val subtitle: String, val symbol: String, val topics: List<String>)
    data class Topic(val id: String, val title: String, val symbol: String, val question: String)
    data class Answer(
        val id: String,
        val topic: String,
        val goals: List<String>,
        val headline: String,
        val situation: String,
        val solution: String,
        val pointerId: String?,
        val situationVoice: String?,
        val solutionVoice: String?,
        val signoffVoice: String?,
    )

    fun goal(id: String): Goal? = goals.firstOrNull { it.id == id }
    fun topic(id: String): Topic? = topics.firstOrNull { it.id == id }

    fun topics(goal: Goal): List<Topic> =
        goal.topics.mapNotNull { id -> topic(id)?.takeIf { answers(goal.id, id).isNotEmpty() } }

    fun answers(goalId: String, topicId: String): List<Answer> =
        answers.filter { it.topic == topicId && goalId in it.goals }

    /** Every path a thumb can take must land on an answer before hosted content is accepted. */
    val isValid: Boolean
        get() {
            if (version <= 0 || goals.isEmpty() || topics.isEmpty() || answers.isEmpty()) return false
            val goalIds = goals.map { it.id }.toSet()
            val topicIds = topics.map { it.id }.toSet()
            if (goalIds.size != goals.size || topicIds.size != topics.size) return false
            for (goal in goals) {
                if (goal.topics.isEmpty()) return false
                if (!goal.topics.all { it in topicIds && answers(goal.id, it).isNotEmpty() }) return false
            }
            return answers.all { answer ->
                answer.topic in topicIds && answer.goals.isNotEmpty() && answer.goals.all { it in goalIds } &&
                    answer.headline.isNotEmpty() && answer.situation.isNotEmpty() && answer.solution.isNotEmpty()
            }
        }

    companion object {
        val empty = AskPattieGuide(0, "Ask Pattie", "", "What are you training for?", emptyList(), emptyList(), emptyList())

        fun parse(text: String): AskPattieGuide? = runCatching {
            val json = JSONObject(text)
            AskPattieGuide(
                version = json.getInt("version"),
                title = json.getString("title"),
                subtitle = json.getString("subtitle"),
                goalQuestion = json.getString("goalQuestion"),
                goals = json.getJSONArray("goals").objects().map {
                    Goal(it.getString("id"), it.getString("title"), it.getString("subtitle"), it.getString("symbol"),
                        it.optJSONArray("topics").strings())
                },
                topics = json.getJSONArray("topics").objects().map {
                    Topic(it.getString("id"), it.getString("title"), it.getString("symbol"), it.optString("question"))
                },
                answers = json.getJSONArray("answers").objects().map {
                    Answer(
                        id = it.getString("id"),
                        topic = it.getString("topic"),
                        goals = it.optJSONArray("goals").strings(),
                        headline = it.getString("headline"),
                        situation = it.getString("situation"),
                        solution = it.getString("solution"),
                        pointerId = it.optNullableString("pointerID"),
                        situationVoice = it.optNullableString("situationVoice"),
                        solutionVoice = it.optNullableString("solutionVoice"),
                        signoffVoice = it.optNullableString("signoffVoice"),
                    )
                },
            )
        }.getOrNull()
    }
}

/** Bundled first so the screen is never empty, then the hosted copy on the hotfix channel. */
class AskPattieLibrary(private val context: Context) {
    private val defaults = context.getSharedPreferences("askpattie", Context.MODE_PRIVATE)
    @Volatile private var current: AskPattieGuide? = null

    fun guide(): AskPattieGuide {
        current?.let { return it }
        defaults.getString(CACHE_KEY, null)?.let(AskPattieGuide::parse)?.takeIf { it.isValid }?.let {
            current = it
            return it
        }
        bundled()?.let {
            current = it
            return it
        }
        return AskPattieGuide.empty
    }

    fun bundled(): AskPattieGuide? = runCatching {
        context.assets.open("ask-pattie.json").bufferedReader().use { it.readText() }
    }.getOrNull()?.let(AskPattieGuide::parse)?.takeIf { it.isValid }

    suspend fun refresh(force: Boolean = false): AskPattieGuide = withContext(Dispatchers.IO) {
        val last = defaults.getLong(CACHE_DATE_KEY, 0L)
        if (!force && last > 0 && System.currentTimeMillis() - last < REFRESH_MS) return@withContext guide()
        val text = fetchText(REMOTE_URL)
        val fetched = text?.let(AskPattieGuide::parse)
        // Never let a truncated or reordered publish replace a good tree.
        if (fetched == null || !fetched.isValid || fetched.version < guide().version) {
            defaults.edit().putLong(CACHE_DATE_KEY, System.currentTimeMillis()).apply()
            return@withContext guide()
        }
        current = fetched
        defaults.edit().putString(CACHE_KEY, text).putLong(CACHE_DATE_KEY, System.currentTimeMillis()).apply()
        fetched
    }

    fun clear() {
        current = null
        defaults.edit().clear().apply()
    }

    private companion object {
        const val REMOTE_URL = "https://jackwallner.github.io/ironman/ask-pattie.json"
        const val CACHE_KEY = "askpattie.guide.cached"
        const val CACHE_DATE_KEY = "askpattie.guide.cachedAt"
        const val REFRESH_MS = 12 * 60 * 60 * 1_000L
    }
}

internal fun fetchText(url: String, timeoutMs: Int = 15_000): String? = runCatching {
    val connection = (URL(url).openConnection() as HttpURLConnection).apply {
        connectTimeout = timeoutMs
        readTimeout = timeoutMs
        useCaches = false
    }
    try {
        if (connection.responseCode !in 200..299) return@runCatching null
        connection.inputStream.bufferedReader().use { it.readText() }
    } finally {
        connection.disconnect()
    }
}.getOrNull()

internal fun JSONArray.objects(): List<JSONObject> = (0 until length()).mapNotNull { optJSONObject(it) }
