package com.jackwallner.ironsplits.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Thumbnails for the episode list: memory, then disk, then network. */
private object ThumbnailCache {
    private val memory = object : LruCache<String, Bitmap>(12 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    fun cached(url: String): Bitmap? = memory.get(url)

    suspend fun load(context: Context, url: String): Bitmap? = withContext(Dispatchers.IO) {
        memory.get(url)?.let { return@withContext it }
        val name = MessageDigest.getInstance("SHA-256").digest(url.toByteArray()).joinToString("") { "%02x".format(it) }
        val file = File(File(context.cacheDir, "thumbnails").apply { mkdirs() }, name)
        if (!file.exists()) {
            runCatching {
                val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15_000
                    readTimeout = 15_000
                }
                try {
                    if (connection.responseCode in 200..299) {
                        val temp = File(file.parentFile, "$name.part")
                        connection.inputStream.use { input -> temp.outputStream().use { input.copyTo(it) } }
                        temp.renameTo(file)
                    }
                } finally {
                    connection.disconnect()
                }
            }
        }
        val options = BitmapFactory.Options().apply { inSampleSize = 2 }
        val bitmap = runCatching { BitmapFactory.decodeFile(file.path, options) }.getOrNull()
        bitmap?.also { memory.put(url, it) }
    }
}

@Composable
fun RemoteImage(url: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var bitmap by remember(url) { mutableStateOf(ThumbnailCache.cached(url)) }
    LaunchedEffect(url) {
        if (bitmap == null) bitmap = ThumbnailCache.load(context, url)
    }
    bitmap?.let { Image(it.asImageBitmap(), null, modifier, contentScale = ContentScale.Crop) }
}
