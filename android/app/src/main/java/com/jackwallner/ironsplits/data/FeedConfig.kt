package com.jackwallner.ironsplits.data

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * Where the results come from and how a request is spelled. The compiled-in
 * values are only the fallback: [FeedConfigLoader] replaces them from the
 * GitHub Pages hotfix channel, so a moved feed never needs an app update.
 */
data class FeedConfig(
    val proxyUrl: String,
    val proxyUrlParameter: String,
    val pageSizeParameter: String,
    val resultsUrl: String,
    val pageSize: Int,
    val maxPages: Int,
    val referer: String,
) {
    val isValid: Boolean
        get() = isValidEndpoint(proxyUrl, "labs-v2.competitor.com", "/api/results-proxy") &&
            isValidEndpoint(resultsUrl, "api.competitor.com", "/web/results") &&
            isValidReferer(referer) &&
            proxyUrlParameter == "url" &&
            pageSizeParameter == "pageSize" &&
            pageSize in 1..2_000 &&
            maxPages in 1..100

    /** Proxied request URL for one already-encoded OData query string. */
    fun requestUrl(query: String, overridePageSize: Int? = null): String? {
        if (!isValid) return null
        if (overridePageSize != null && overridePageSize !in 1..2_000) return null
        val upstream = "$resultsUrl?$query"
        return Uri.parse(proxyUrl).buildUpon()
            .appendQueryParameter(proxyUrlParameter, upstream)
            .appendQueryParameter(pageSizeParameter, (overridePageSize ?: pageSize).toString())
            .build().toString()
    }

    /** A `@odata.nextLink` is an absolute upstream URL that still has to be signed. */
    fun requestUrl(nextLink: String): String? {
        if (!isValid) return null
        val next = runCatching { URL(nextLink) }.getOrNull() ?: return null
        if (!next.protocol.equals("https", true) || !next.host.equals("api.competitor.com", true)) return null
        if (next.port != -1 && next.port != 443) return null
        // The upstream pages through its own entity-set name, `/web/wtc_results`.
        if (next.path != "/web/results" && next.path != "/web/wtc_results") return null
        return Uri.parse(proxyUrl).buildUpon()
            .appendQueryParameter(proxyUrlParameter, nextLink)
            .appendQueryParameter(pageSizeParameter, pageSize.toString())
            .build().toString()
    }

    fun toJson(): JSONObject = JSONObject()
        .put("proxyURL", proxyUrl)
        .put("proxyURLParameter", proxyUrlParameter)
        .put("pageSizeParameter", pageSizeParameter)
        .put("resultsURL", resultsUrl)
        .put("pageSize", pageSize)
        .put("maxPages", maxPages)
        .put("referer", referer)

    private fun isValidEndpoint(raw: String, host: String, path: String): Boolean {
        val url = runCatching { URL(raw) }.getOrNull() ?: return false
        return url.protocol.equals("https", true) &&
            url.host.equals(host, true) &&
            (url.port == -1 || url.port == 443) &&
            url.path == path &&
            url.query == null &&
            url.userInfo == null
    }

    private fun isValidReferer(raw: String): Boolean {
        val url = runCatching { URL(raw) }.getOrNull() ?: return false
        return url.protocol.equals("https", true) &&
            url.host.equals("labs-v2.competitor.com", true) &&
            (url.port == -1 || url.port == 443) &&
            url.userInfo == null &&
            url.query == null &&
            (url.path.isEmpty() || url.path == "/")
    }

    companion object {
        val bundled = FeedConfig(
            proxyUrl = "https://labs-v2.competitor.com/api/results-proxy",
            proxyUrlParameter = "url",
            pageSizeParameter = "pageSize",
            resultsUrl = "https://api.competitor.com/web/results",
            pageSize = 500,
            maxPages = 12,
            referer = "https://labs-v2.competitor.com/",
        )

        fun parse(json: JSONObject): FeedConfig? = runCatching {
            FeedConfig(
                proxyUrl = json.getString("proxyURL"),
                proxyUrlParameter = json.getString("proxyURLParameter"),
                pageSizeParameter = json.getString("pageSizeParameter"),
                resultsUrl = json.getString("resultsURL"),
                pageSize = json.getInt("pageSize"),
                maxPages = json.getInt("maxPages"),
                referer = json.getString("referer"),
            )
        }.getOrNull()?.takeIf { it.isValid }
    }
}

/** The hotfix channel: re-reads `docs/api-config.json` at most every six hours. */
class FeedConfigLoader(context: Context) {
    private val defaults: SharedPreferences = context.getSharedPreferences("feed.config", Context.MODE_PRIVATE)

    @Volatile private var current: FeedConfig? = null

    /** Best config available now, without waiting on the network. */
    fun config(): FeedConfig {
        current?.let { return it }
        val cached = defaults.getString(CACHE_KEY, null)
            ?.let { runCatching { FeedConfig.parse(JSONObject(it)) }.getOrNull() }
        if (cached != null) {
            current = cached
            return cached
        }
        return FeedConfig.bundled
    }

    suspend fun refreshIfStale() = withContext(Dispatchers.IO) {
        val last = defaults.getLong(CACHE_DATE_KEY, 0L)
        if (last > 0 && System.currentTimeMillis() - last < REFRESH_INTERVAL_MS) return@withContext
        val fetched = runCatching {
            val connection = (URL(REMOTE_URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = 10_000
                readTimeout = 10_000
                useCaches = false
            }
            try {
                if (connection.responseCode !in 200..299) return@runCatching null
                connection.inputStream.bufferedReader().use { it.readText() }
            } finally {
                connection.disconnect()
            }
        }.getOrNull()
        val config = fetched?.let { runCatching { FeedConfig.parse(JSONObject(it)) }.getOrNull() }
        val editor = defaults.edit().putLong(CACHE_DATE_KEY, System.currentTimeMillis())
        if (config != null) {
            current = config
            editor.putString(CACHE_KEY, fetched)
        }
        editor.apply()
    }

    fun clear() {
        current = null
        defaults.edit().clear().apply()
    }

    private companion object {
        const val REMOTE_URL = "https://jackwallner.github.io/ironman/api-config.json"
        const val CACHE_KEY = "feed.config.cached"
        const val CACHE_DATE_KEY = "feed.config.cachedAt"
        const val REFRESH_INTERVAL_MS = 6 * 60 * 60 * 1_000L
    }
}
