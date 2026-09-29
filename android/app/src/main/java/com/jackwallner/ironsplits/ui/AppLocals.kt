package com.jackwallner.ironsplits.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.core.content.FileProvider
import com.jackwallner.ironsplits.AppGraph
import java.io.File

val LocalGraph = staticCompositionLocalOf<AppGraph> { error("No app graph") }

/** Opens a web page in a Custom Tab, falling back to the browser. */
fun Context.openUrl(url: String) {
    runCatching { CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(this, Uri.parse(url)) }
        .onFailure {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (_: ActivityNotFoundException) {
            }
        }
}

/** Opens an external link (store page, video site) outside the app. */
fun Context.openExternal(url: String): Boolean = try {
    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    true
} catch (_: ActivityNotFoundException) {
    false
}

fun Context.shareText(text: String, subject: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, text)
    }
    startActivity(Intent.createChooser(intent, subject))
}

fun Context.shareFile(file: File, mimeType: String, title: String) {
    val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = mimeType
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_SUBJECT, title)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    startActivity(Intent.createChooser(intent, title))
}
