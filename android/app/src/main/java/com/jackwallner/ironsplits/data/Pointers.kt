package com.jackwallner.ironsplits.data

import android.content.Context
import android.text.format.Formatter
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.TimeFormat
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject

/** One coaching clip. A hosted video plays in the app; a watch link opens outside it. */
data class Pointer(
    val id: String,
    val episode: Int?,
    val title: String,
    val summary: String?,
    val discipline: Discipline?,
    val videoUrl: String?,
    val linkUrl: String?,
    val thumbnailUrl: String?,
    val durationSeconds: Int?,
    val fileSizeBytes: Long?,
) {
    val durationText: String? get() = durationSeconds?.takeIf { it > 0 }?.let(TimeFormat::hms)

    fun fileSizeText(context: Context): String? =
        fileSizeBytes?.takeIf { it > 0 }?.let { Formatter.formatShortFileSize(context, it) }

    val playableUrl: String? get() = videoUrl ?: linkUrl
    val opensExternally: Boolean get() = videoUrl == null && linkUrl != null
}

data class PointerCatalog(
    val title: String,
    val subtitle: String?,
    val emptyMessage: String?,
    val pointers: List<Pointer>,
) {
    companion object {
        val empty = PointerCatalog(
            title = "Tri Pointers",
            subtitle = null,
            emptyMessage = "The Tri Pointers episodes aren't published yet. They'll appear here as soon as they are, with no app update needed.",
            pointers = emptyList(),
        )

        fun parse(text: String): PointerCatalog? = runCatching {
            val json = JSONObject(text)
            PointerCatalog(
                title = json.getString("title"),
                subtitle = json.optNullableString("subtitle"),
                emptyMessage = json.optNullableString("emptyMessage"),
                pointers = json.getJSONArray("pointers").objects().map {
                    Pointer(
                        id = it.getString("id"),
                        episode = if (it.isNull("episode")) null else it.optInt("episode"),
                        title = it.getString("title"),
                        summary = it.optNullableString("summary"),
                        discipline = it.optNullableString("discipline")?.let { raw ->
                            Discipline.entries.firstOrNull { d -> d.name.equals(raw, ignoreCase = true) }
                        },
                        videoUrl = it.optNullableString("videoURL"),
                        linkUrl = it.optNullableString("linkURL"),
                        thumbnailUrl = it.optNullableString("thumbnailURL"),
                        durationSeconds = if (it.isNull("durationSeconds")) null else it.optInt("durationSeconds"),
                        fileSizeBytes = if (it.isNull("fileSizeBytes")) null else it.optLong("fileSizeBytes"),
                    )
                },
            )
        }.getOrNull()
    }
}

/** Loads and caches the episode catalog on the same hotfix channel as the feed config. */
class PointerLibrary(private val context: Context) {
    private val defaults = context.getSharedPreferences("pointers", Context.MODE_PRIVATE)
    @Volatile private var current: PointerCatalog? = null
    @Volatile var errorMessage: String? = null
        private set

    fun catalog(): PointerCatalog {
        current?.let { return it }
        defaults.getString(CACHE_KEY, null)?.let(PointerCatalog::parse)?.let {
            current = it
            return it
        }
        // The bundled copy keeps episode links working offline on a first launch.
        runCatching { context.assets.open("pointers.json").bufferedReader().use { it.readText() } }
            .getOrNull()?.let(PointerCatalog::parse)?.let {
                current = it
                return it
            }
        return PointerCatalog.empty
    }

    suspend fun refresh(force: Boolean = false): PointerCatalog = withContext(Dispatchers.IO) {
        val last = defaults.getLong(CACHE_DATE_KEY, 0L)
        if (!force && last > 0 && System.currentTimeMillis() - last < REFRESH_MS) {
            if (catalog().pointers.isEmpty()) errorMessage = UNREACHABLE
            return@withContext catalog()
        }
        val text = fetchText(REMOTE_URL)
        val fetched = text?.let(PointerCatalog::parse)
        if (fetched == null) {
            defaults.edit().putLong(CACHE_DATE_KEY, System.currentTimeMillis()).apply()
            errorMessage = UNREACHABLE
            return@withContext catalog()
        }
        current = fetched
        errorMessage = null
        defaults.edit().putString(CACHE_KEY, text).putLong(CACHE_DATE_KEY, System.currentTimeMillis()).apply()
        fetched
    }

    fun clear() {
        current = null
        defaults.edit().clear().apply()
    }

    private companion object {
        const val REMOTE_URL = "https://jackwallner.github.io/ironman/pointers.json"
        const val CACHE_KEY = "pointers.catalog.cached"
        const val CACHE_DATE_KEY = "pointers.catalog.cachedAt"
        const val REFRESH_MS = 12 * 60 * 60 * 1_000L
        const val UNREACHABLE = "The episode library couldn't be reached. Check your connection and try again."
    }
}

/**
 * Downloads episodes before playing them. Release assets arrive as
 * `application/octet-stream` behind a redirect with no extension, so a local
 * `.mp4` is what plays, and it keeps working offline afterwards.
 */
class PointerMediaCache(context: Context, private val scope: CoroutineScope) {
    private val directory = File(context.filesDir, "PointerMedia")
    private val mutex = Mutex()
    private val inFlight = mutableMapOf<String, Deferred<File>>()
    private val _version = MutableStateFlow(0)
    /** Bumps whenever the cache changes, so offline badges and sizes can refresh. */
    val version: StateFlow<Int> = _version.asStateFlow()

    class MediaException(message: String) : Exception(message)

    fun cachedFile(pointer: Pointer): File? = localFile(pointer).takeIf { it.exists() && it.length() > 0 }

    suspend fun file(pointer: Pointer, progress: (Double) -> Unit): File {
        cachedFile(pointer)?.let { return it }
        val job = mutex.withLock {
            inFlight[pointer.id] ?: scope.async(Dispatchers.IO) { download(pointer, progress) }.also {
                inFlight[pointer.id] = it
                it.invokeOnCompletion { scope.async { mutex.withLock { inFlight.remove(pointer.id) } } }
            }
        }
        return job.await()
    }

    private suspend fun download(pointer: Pointer, progress: (Double) -> Unit): File = withContext(Dispatchers.IO) {
        val remote = pointer.videoUrl ?: throw MediaException("The episode file came back empty.")
        directory.mkdirs()
        val destination = localFile(pointer)
        val temporary = File(directory, "${destination.name}.part")
        var url = URL(remote)
        var connection: HttpURLConnection
        var redirects = 0
        while (true) {
            connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 30_000
                readTimeout = 60_000
                instanceFollowRedirects = true
            }
            val code = connection.responseCode
            if (code in 300..399 && redirects < 5) {
                val location = connection.getHeaderField("Location") ?: break
                connection.disconnect()
                url = URL(url, location)
                redirects++
                continue
            }
            break
        }
        try {
            val code = connection.responseCode
            if (code !in 200..299) throw MediaException("The episode couldn't be downloaded ($code).")
            val total = connection.contentLengthLong
            var written = 0L
            connection.inputStream.use { input ->
                temporary.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        coroutineContext.ensureActive()
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        written += read
                        if (total > 0) progress(written.toDouble() / total)
                    }
                }
            }
            if (written <= 0) throw MediaException("The episode file came back empty.")
            // Move into place last, so a failed download never looks cached.
            destination.delete()
            if (!temporary.renameTo(destination)) throw MediaException("The episode file came back empty.")
            progress(1.0)
            _version.value++
            destination
        } finally {
            temporary.delete()
            connection.disconnect()
        }
    }

    fun cacheSize(): Long = directory.listFiles()?.filter { it.isFile }?.sumOf { it.length() } ?: 0L

    suspend fun clear() {
        mutex.withLock {
            inFlight.values.forEach { it.cancel() }
            inFlight.clear()
        }
        withContext(Dispatchers.IO) { directory.deleteRecursively() }
        _version.value++
    }

    private fun localFile(pointer: Pointer): File {
        val digest = MessageDigest.getInstance("SHA-256").digest(pointer.id.toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(directory, "$digest.mp4")
    }
}
