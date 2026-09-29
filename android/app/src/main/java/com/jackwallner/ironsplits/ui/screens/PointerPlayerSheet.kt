package com.jackwallner.ironsplits.ui.screens

import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.jackwallner.ironsplits.data.Pointer
import com.jackwallner.ironsplits.data.isCancellation
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.theme.ToolbarTextButton
import com.jackwallner.ironsplits.ui.theme.LocalTriColors
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriColors
import com.jackwallner.ironsplits.ui.theme.TriPlaceholder
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType

/**
 * Plays an episode from a local copy. The hosting cannot be streamed, so the
 * sheet downloads with real progress first, and the file then plays offline.
 */
@Composable
fun PointerPlayerSheet(pointer: Pointer?, onClose: () -> Unit) {
    var shown by remember { mutableStateOf<Pointer?>(null) }
    if (pointer != null) shown = pointer
    TriSheet(visible = pointer != null, onDismiss = onClose, background = Tri.colors.mediaCanvas) {
        shown?.let { PlayerContent(it, onClose) }
    }
}

@OptIn(androidx.media3.common.util.UnstableApi::class)
@Composable
private fun PlayerContent(pointer: Pointer, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val colors = Tri.colors
    var progress by remember { mutableDoubleStateOf(0.0) }
    var error by remember { mutableStateOf<String?>(null) }
    var filePath by remember { mutableStateOf<String?>(null) }
    var attempt by remember { mutableIntStateOf(0) }

    LaunchedEffect(pointer.id, attempt) {
        graph.pattie.beginPointerPlayback()
        error = null
        progress = 0.0
        try {
            val file = graph.mediaCache.file(pointer) { fraction ->
                android.os.Handler(android.os.Looper.getMainLooper()).post { progress = fraction }
            }
            filePath = file.absolutePath
        } catch (failure: Throwable) {
            if (isCancellation(failure)) throw failure
            error = failure.message ?: "The episode couldn't be downloaded."
        }
    }
    DisposableEffect(Unit) { onDispose { graph.pattie.endPointerPlayback() } }

    TriScreen(
        title = pointer.title,
        inSheet = true,
        leading = { ToolbarTextButton("Done", onClick = onClose) },
        background = colors.mediaCanvas,
    ) {
        // The media stage is black in both schemes, so its text uses the dark palette.
        CompositionLocalProvider(LocalTriColors provides TriColors.dark) { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val path = filePath
            when {
                path != null -> {
                    val player = remember(path) {
                        ExoPlayer.Builder(context).build().apply {
                            setAudioAttributes(
                                AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
                                true,
                            )
                            setMediaItem(MediaItem.fromUri(android.net.Uri.fromFile(java.io.File(path))))
                            prepare()
                            playWhenReady = true
                        }
                    }
                    DisposableEffect(player) { onDispose { player.release() } }
                    AndroidView(
                        factory = { ctx ->
                            PlayerView(ctx).apply {
                                layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                                this.player = player
                                setShowNextButton(false)
                                setShowPreviousButton(false)
                                contentDescription = pointer.title
                            }
                        },
                        modifier = Modifier.fillMaxSize(),
                    )
                }
                error != null -> TriPlaceholder(
                    Icons.Filled.WifiOff, "Couldn't load the episode", message = error, actionTitle = "Try again",
                ) { attempt++ }
                else -> Column(
                    Modifier.padding(TriSpace.x4),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
                ) {
                    LinearProgressIndicator(
                        progress = { progress.toFloat() },
                        color = colors.sunrise,
                        trackColor = colors.inkOnDark.copy(alpha = 0.2f),
                        modifier = Modifier.width(220.dp),
                    )
                    Text(
                        if (progress > 0) "Downloading ${(progress * 100).toInt()}%" else "Starting the episode…",
                        style = TriType.small.copy(fontFeatureSettings = "tnum"),
                        color = colors.inkOnDark.copy(alpha = 0.75f),
                    )
                    Text(
                        "Saved after the first play, so it works offline next time.",
                        style = TriType.micro,
                        color = colors.inkOnDark.copy(alpha = 0.5f),
                        textAlign = TextAlign.Center,
                    )
                }
            }
        } }
    }
}
