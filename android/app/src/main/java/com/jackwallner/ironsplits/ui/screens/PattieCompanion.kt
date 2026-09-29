package com.jackwallner.ironsplits.ui.screens

import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.Waves
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.PattiePetState
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.theme.CardShape
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.triPress
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

private val AVATAR_WIDTH = 80.dp
private val AVATAR_HEIGHT = 120.dp
private val FRAME_WIDTH = AVATAR_WIDTH + 16.dp
private val FRAME_HEIGHT = AVATAR_HEIGHT + 8.dp
private const val IDLE_SCALE = 0.45f

private fun PattiePetState.accessory(): ImageVector? = when (this) {
    PattiePetState.IDLE -> null
    PattiePetState.COACH -> Icons.Filled.Search
    PattiePetState.CELEBRATE -> Icons.Filled.AutoAwesome
    PattiePetState.ENCOURAGE, PattiePetState.RECOVERY -> Icons.Filled.Favorite
    PattiePetState.SHOES, PattiePetState.WARMUP -> Icons.AutoMirrored.Filled.DirectionsWalk
    PattiePetState.SWIM -> Icons.Filled.Waves
    PattiePetState.BIKE -> Icons.AutoMirrored.Filled.DirectionsBike
    PattiePetState.RUN -> Icons.AutoMirrored.Filled.DirectionsRun
    PattiePetState.TRANSITION -> Icons.Filled.Autorenew
    PattiePetState.FINISH -> Icons.Filled.SportsScore
    PattiePetState.DANCE -> Icons.Filled.MusicNote
    PattiePetState.HYDRATE -> Icons.Filled.WaterDrop
    PattiePetState.STRETCH -> Icons.Filled.Accessibility
}

/**
 * Pattie's companion: a small pet in the corner, and a tip bubble only when
 * she has something useful to say. Never modal, never blocks content.
 */
@Composable
fun PattieCompanion(modifier: Modifier = Modifier) {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val colors = Tri.colors
    val line by graph.pattie.current.collectAsState()
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    var idleIndex by remember { mutableIntStateOf(0) }
    var idleState by remember { mutableStateOf(PattiePetState.WARMUP) }
    var elapsed by remember { mutableDoubleStateOf(0.0) }
    val current = line
    val petState = current?.petState ?: idleState
    val scale by animateFloatAsState(
        if (current == null) IDLE_SCALE else 1f,
        spring(dampingRatio = 0.82f, stiffness = Spring.StiffnessLow),
        label = "pet",
    )

    // The idle pet steps through a finite cycle of poses.
    LaunchedEffect(reduceMotion) {
        if (reduceMotion) return@LaunchedEffect
        while (isActive) {
            val next = PattiePetState.motionState(idleIndex)
            idleState = next
            idleIndex++
            delay((maxOf(1.2, next.motionProfile.duration * 2.5) * 1000).toLong())
        }
    }
    // A speaking pet moves continuously; the loop restarts with each line.
    LaunchedEffect(current?.presentationId, reduceMotion) {
        elapsed = 0.0
        if (current == null || reduceMotion) return@LaunchedEffect
        val start = withFrameNanos { it }
        while (isActive) {
            withFrameNanos { now -> elapsed = (now - start) / 1_000_000_000.0 }
        }
    }
    // Dismiss after enough reading time, never mid-sentence.
    LaunchedEffect(current?.presentationId) {
        val shown = current ?: return@LaunchedEffect
        val accessibility = context.getSystemService(AccessibilityManager::class.java)
        while (accessibility?.isTouchExplorationEnabled == true) delay(500)
        val minimum = if (shown.isGiantCatchphrase) 4.5 else 4.0
        delay((maxOf(minimum, 1.5 + shown.text.length / 16.0) * 1000).toLong())
        while (graph.voice.isPlaying(shown.voice)) delay(200)
        if (graph.pattie.current.value?.presentationId == shown.presentationId) graph.pattie.dismiss()
    }

    val frame = petState.animationFrame(if (current == null || reduceMotion) 0.0 else elapsed)
    Row(modifier.padding(horizontal = TriSpace.x4), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
        Box(
            Modifier
                .testTag("pattie-avatar")
                .semantics {
                    contentDescription = if (current == null) "Pattie, hear a tip" else "Pattie, replay the tip"
                    stateDescription = petState.accessibilityName
                }
                .size(FRAME_WIDTH * scale, FRAME_HEIGHT * scale)
                .triPress(haptic = false) { if (current == null) graph.pattie.demo() else graph.pattie.replayVoice() },
        ) {
            Image(
                painterResource(frame.imageRes),
                null,
                contentScale = ContentScale.Fit,
                alignment = Alignment.BottomCenter,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .size(AVATAR_WIDTH * scale, AVATAR_HEIGHT * scale)
                    .graphicsLayer {
                        translationX = (4.dp.toPx() * scale * frame.horizontalShift).toFloat()
                        translationY = (-4.dp.toPx() * scale * frame.verticalLift).toFloat()
                        rotationZ = frame.rotationDegrees.toFloat()
                        scaleX = frame.scale.toFloat()
                        scaleY = frame.scale.toFloat()
                        transformOrigin = TransformOrigin(0.5f, 1f)
                    },
            )
            petState.accessory()?.let { icon ->
                val phase = if (current == null || reduceMotion) 0.0 else kotlin.math.sin(elapsed * 2 * Math.PI / 0.9)
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = (20.dp + 4.dp * phase.toFloat()) * scale, y = ((-20).dp - 2.dp * (phase.toFloat() + 1)) * scale)
                        .graphicsLayer { rotationZ = (5 * phase).toFloat() }
                        .size(TriSpace.x8 * scale)
                        .background(colors.sunrise, CircleShape)
                        .border(TriGeo.hairline, colors.deep, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(icon, null, tint = colors.deep, modifier = Modifier.size(14.dp * scale))
                }
            }
        }
        AnimatedVisibility(
            visible = current != null,
            enter = slideInHorizontally { -it / 3 } + fadeIn(),
            exit = slideOutHorizontally { -it / 3 } + fadeOut(),
        ) {
            val shown = current ?: return@AnimatedVisibility
            Row(
                Modifier
                    .widthIn(max = 320.dp)
                    .shadow(if (colors.isDark) 16.dp else 12.dp, CardShape, ambientColor = colors.shadow, spotColor = colors.shadow)
                    .background(colors.surface, CardShape)
                    .border(TriGeo.hairline, colors.sunrise.copy(alpha = 0.45f), CardShape)
                    .padding(start = TriSpace.x4, top = TriSpace.x2, bottom = TriSpace.x2),
                verticalAlignment = Alignment.Top,
            ) {
                Text(
                    shown.text,
                    style = if (shown.isGiantCatchphrase) TriType.pageTitle else TriType.body,
                    color = colors.ink,
                    modifier = Modifier
                        .weight(1f, fill = false)
                        .padding(vertical = TriSpace.x2)
                        .testTag("pattie-bubble")
                        .semantics { contentDescription = "Pattie says: ${shown.text}" }
                        .triPress(haptic = false) { graph.pattie.dismiss() },
                )
                Box(
                    Modifier.size(TriGeo.tapTarget).semantics { contentDescription = "Dismiss Pattie" }
                        .triPress(haptic = false) { graph.pattie.dismiss() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Close, null, tint = colors.inkTertiary, modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}
