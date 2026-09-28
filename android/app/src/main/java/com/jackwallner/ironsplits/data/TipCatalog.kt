package com.jackwallner.ironsplits.data

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

data class PattieGoal(val id: String, val title: String, val subtitle: String, val topicIds: List<String>)
data class PattieTopic(val id: String, val title: String, val question: String)
data class PattieAnswer(
    val id: String,
    val topicId: String,
    val goalIds: List<String>,
    val headline: String,
    val situation: String,
    val solution: String,
    val pointerId: String,
    val situationVoice: String?,
    val solutionVoice: String?,
    val signoffVoice: String?,
)
data class PointerEpisode(
    val id: String,
    val episode: Int,
    val title: String,
    val summary: String,
    val discipline: String?,
    val videoUrl: String?,
    val linkUrl: String?,
    val thumbnailUrl: String?,
    val durationSeconds: Int,
)

class TipCatalog(private val context: Context) {
    private val preferences = context.getSharedPreferences("tip_catalog", Context.MODE_PRIVATE)
    private fun askJson(): JSONObject {
        val cached = preferences.getString("ask_catalog", null)
        return cached?.let { runCatching { JSONObject(it) }.getOrNull() }
            ?: JSONObject(context.assets.open("ask-pattie.json").bufferedReader().use { it.readText() })
    }

    val goals: List<PattieGoal>
        get() = askJson().optJSONArray("goals")?.objects()?.map { json ->
            PattieGoal(json.optString("id"), json.optString("title"), json.optString("subtitle"),
                json.optJSONArray("topics").strings())
        }.orEmpty()

    val topics: List<PattieTopic>
        get() = askJson().optJSONArray("topics")?.objects()?.map { json ->
            PattieTopic(json.optString("id"), json.optString("title"), json.optString("question"))
        }.orEmpty()

    val answers: List<PattieAnswer>
        get() = askJson().optJSONArray("answers")?.objects()?.map { json ->
            PattieAnswer(
                id = json.optString("id"),
                topicId = json.optString("topic"),
                goalIds = json.optJSONArray("goals").strings(),
                headline = json.optString("headline"),
                situation = json.optString("situation"),
                solution = json.optString("solution"),
                pointerId = json.optString("pointerID"),
                situationVoice = json.optNullableString("situationVoice"),
                solutionVoice = json.optNullableString("solutionVoice"),
                signoffVoice = json.optNullableString("signoffVoice"),
            )
        }.orEmpty()

    suspend fun refreshAsk(refresh: Boolean = false) = withContext(Dispatchers.IO) {
        val lastRefresh = preferences.getLong("ask_last_refresh", 0L)
        if (!refresh && System.currentTimeMillis() - lastRefresh < REFRESH_MS) return@withContext
        val result = runCatching {
            val connection = (URL(ASK_URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = 12_000
                readTimeout = 12_000
                setRequestProperty("Accept", "application/json")
            }
            try {
                require(connection.responseCode in 200..299)
                connection.inputStream.bufferedReader().use { it.readText() }
            } finally {
                connection.disconnect()
            }
        }.getOrNull()
        preferences.edit().putLong("ask_last_refresh", System.currentTimeMillis()).apply()
        if (result != null) {
            val candidate = runCatching { JSONObject(result) }.getOrNull()
            if ((candidate?.optJSONArray("goals")?.length() ?: 0) > 0 &&
                (candidate?.optJSONArray("answers")?.length() ?: 0) > 0) {
                preferences.edit().putString("ask_catalog", result).apply()
            }
        }
    }

    suspend fun episodes(refresh: Boolean = false): List<PointerEpisode> = withContext(Dispatchers.IO) {
        val lastRefresh = preferences.getLong("last_refresh", 0L)
        val shouldRefresh = refresh || System.currentTimeMillis() - lastRefresh >= REFRESH_MS
        if (shouldRefresh) {
            val result = runCatching {
                val connection = (URL(POINTERS_URL).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 12_000
                    readTimeout = 12_000
                    setRequestProperty("Accept", "application/json")
                }
                try {
                    require(connection.responseCode in 200..299) { "Tips are unavailable right now." }
                    connection.inputStream.bufferedReader().use { it.readText() }
                } finally {
                    connection.disconnect()
                }
            }.getOrNull()
            preferences.edit().putLong("last_refresh", System.currentTimeMillis()).apply()
            if (result != null) preferences.edit().putString("catalog", result).apply()
        }
        val raw = preferences.getString("catalog", null)
            ?: context.assets.open("pointers.json").bufferedReader().use { it.readText() }
        parseEpisodes(JSONObject(raw))
    }

    fun goal(id: String?): PattieGoal? = goals.firstOrNull { it.id == id }
    fun topic(id: String?): PattieTopic? = topics.firstOrNull { it.id == id }
    fun voiceAsset(clip: String?): String? = clip?.takeIf { it.matches(Regex("pattie-[a-z0-9-]+")) }

    private fun parseEpisodes(json: JSONObject): List<PointerEpisode> = json.optJSONArray("pointers")
        ?.objects()
        ?.map { episode ->
            PointerEpisode(
                id = episode.optString("id"),
                episode = episode.optInt("episode"),
                title = episode.optString("title"),
                summary = episode.optString("summary"),
                discipline = episode.optNullableString("discipline"),
                videoUrl = episode.optNullableString("videoURL"),
                linkUrl = episode.optNullableString("linkURL"),
                thumbnailUrl = episode.optNullableString("thumbnailURL"),
                durationSeconds = episode.optInt("durationSeconds"),
            )
        }
        .orEmpty()

    companion object {
        const val ASK_URL = "https://jackwallner.github.io/ironman/ask-pattie.json"
        const val POINTERS_URL = "https://jackwallner.github.io/ironman/pointers.json"
        const val REFRESH_MS = 12 * 60 * 60 * 1_000L
    }
}

class PointerMediaCache(private val context: Context) {
    private val directory = File(context.cacheDir, "pointer-media").apply { mkdirs() }

    fun voiceFile(clip: String): File? {
        require(clip.matches(Regex("pattie-[a-z0-9-]+")))
        val target = File(directory, "$clip.m4a")
        if (target.exists()) return target
        return runCatching {
            context.assets.open("pattie-voice/$clip.m4a").use { input -> target.outputStream().use(input::copyTo) }
            target
        }.getOrNull()
    }

    suspend fun videoFile(episode: PointerEpisode): File = withContext(Dispatchers.IO) {
        val url = episode.videoUrl ?: throw IllegalArgumentException("This tip opens in a browser.")
        val parsed = Uri.parse(url)
        require(parsed.scheme == "https" && parsed.host in setOf("github.com", "objects.githubusercontent.com"))
        val safeName = episode.id.replace(Regex("[^a-zA-Z0-9_-]"), "")
        require(safeName.isNotBlank())
        val target = File(directory, "$safeName.mp4")
        if (target.exists() && target.length() > 0) return@withContext target

        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 20_000
            readTimeout = 60_000
            instanceFollowRedirects = true
            setRequestProperty("Accept", "video/mp4,application/octet-stream")
        }
        try {
            require(connection.responseCode in 200..299) { "That video could not be downloaded." }
            require(connection.contentLengthLong <= MAX_VIDEO_BYTES) { "That video is too large to cache." }
            val partial = File(directory, "$safeName.part")
            connection.inputStream.use { input -> partial.outputStream().use(input::copyTo) }
            require(partial.length() in 1..MAX_VIDEO_BYTES) { "That video could not be saved." }
            if (!partial.renameTo(target)) throw IllegalStateException("That video could not be saved.")
            target
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        const val MAX_VIDEO_BYTES = 100L * 1024 * 1024
    }
}

private fun org.json.JSONArray?.objects(): List<JSONObject> = this?.let { array ->
    (0 until array.length()).mapNotNull(array::optJSONObject)
}.orEmpty()

private fun org.json.JSONArray?.strings(): List<String> = this?.let { array ->
    (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
}.orEmpty()

private fun JSONObject.optNullableString(key: String): String? =
    opt(key)?.takeIf { it != JSONObject.NULL }?.toString()
