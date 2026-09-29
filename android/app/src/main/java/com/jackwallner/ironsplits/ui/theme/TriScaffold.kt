package com.jackwallner.ironsplits.ui.theme

import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBackIos
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import kotlin.math.roundToInt

/** Space a scrolling screen leaves at the bottom so its last row clears the tab bar. */
val LocalBottomInset = compositionLocalOf { 0.dp }

enum class TitleAlignment { CENTER, START }

/**
 * A screen with the app's navy navigation bar. The bar extends behind the
 * status bar, and its title is the inline iOS style: 17sp semibold, white.
 */
@Composable
fun TriScreen(
    title: String,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    titleAlignment: TitleAlignment = TitleAlignment.CENTER,
    inSheet: Boolean = false,
    leading: (@Composable RowScope.() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
    titleContent: (@Composable () -> Unit)? = null,
    background: Color = Tri.colors.canvas,
    content: @Composable BoxScope.() -> Unit,
) {
    Column(modifier.fillMaxSize().background(background)) {
        TriNavBar(title, onBack, titleAlignment, inSheet, leading, trailing, titleContent)
        Box(Modifier.fillMaxWidth().weight(1f), content = content)
    }
}

@Composable
fun TriNavBar(
    title: String,
    onBack: (() -> Unit)? = null,
    titleAlignment: TitleAlignment = TitleAlignment.CENTER,
    inSheet: Boolean = false,
    leading: (@Composable RowScope.() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
    titleContent: (@Composable () -> Unit)? = null,
) {
    val colors = Tri.colors
    Column(Modifier.fillMaxWidth().background(colors.deep)) {
        if (!inSheet) Spacer(Modifier.statusBarsPadding())
        val centered = titleAlignment == TitleAlignment.CENTER || titleContent != null
        Layout(
            content = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (onBack != null) ToolbarBackButton(onBack)
                    leading?.invoke(this)
                }
                Box(contentAlignment = if (centered) Alignment.Center else Alignment.CenterStart) {
                    if (titleContent != null) titleContent() else NavTitle(title, if (centered) TextAlign.Center else TextAlign.Start)
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(TriSpace.x2),
                ) { trailing?.invoke(this) }
            },
            modifier = Modifier.fillMaxWidth().height(TriGeo.navBarHeight).padding(horizontal = TriSpace.x4),
        ) { measurables, constraints ->
            // Leading and trailing actions keep their natural size; the title
            // takes what is left, centred on the bar when it is a centred title.
            val loose = constraints.copy(minWidth = 0, minHeight = 0)
            val lead = measurables[0].measure(loose)
            val trail = measurables[2].measure(loose)
            val gap = TriSpace.x3.roundToPx()
            val width = constraints.maxWidth
            val height = constraints.maxHeight
            val side = maxOf(lead.width, trail.width)
            val titleWidth = if (centered) {
                width - 2 * (side + if (side > 0) gap else 0)
            } else {
                width - lead.width - trail.width - (if (lead.width > 0) gap else 0) - (if (trail.width > 0) gap else 0)
            }.coerceAtLeast(0)
            val titlePlaceable = measurables[1].measure(loose.copy(maxWidth = titleWidth))
            layout(width, height) {
                lead.placeRelative(0, (height - lead.height) / 2)
                trail.placeRelative(width - trail.width, (height - trail.height) / 2)
                val x = if (centered) (width - titlePlaceable.width) / 2 else lead.width + if (lead.width > 0) gap else 0
                titlePlaceable.placeRelative(x, (height - titlePlaceable.height) / 2)
            }
        }
    }
}

@Composable
private fun NavTitle(title: String, align: TextAlign) {
    Text(
        title,
        style = TriType.navTitle,
        color = Tri.colors.inkOnDark,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        textAlign = align,
        modifier = Modifier.semantics { heading() },
    )
}

/** The circular back button that sits on the navy bar. */
@Composable
fun ToolbarBackButton(onBack: () -> Unit) {
    ToolbarCircleButton(Icons.AutoMirrored.Filled.ArrowBackIos, "Back", iconOffset = 3.dp, onClick = onBack)
}

@Composable
fun ToolbarCircleButton(icon: ImageVector, label: String, iconOffset: androidx.compose.ui.unit.Dp = 0.dp, onClick: () -> Unit) {
    val colors = Tri.colors
    Box(
        Modifier
            .semantics { contentDescription = label }
            .triPress(haptic = true, onClick = onClick)
            .size(TriGeo.tapTarget)
            .clip(CircleShape)
            .background(colors.toolbarCircle),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = colors.inkOnDark, modifier = Modifier.size(18.dp).offset(x = iconOffset))
    }
}

/** A text action on the navy bar: Cancel, Done, Save. */
@Composable
fun ToolbarTextButton(title: String, bold: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val colors = Tri.colors
    Box(
        Modifier
            .triPress(enabled = enabled, haptic = true, onClick = onClick)
            .heightIn(min = TriGeo.tapTarget)
            .clip(CircleShape)
            .background(colors.toolbarCircle)
            .padding(horizontal = TriSpace.x4),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = if (bold) TriType.bodyBold else TriType.body, color = colors.toolbarContent, maxLines = 1)
    }
}

/**
 * A page sheet: slides up over everything, including the tab bar and
 * Pattie, with its own navigation bar. Back, the scrim, or dragging the bar
 * down dismisses it, unless [onRequestDismiss] vetoes that.
 */
@Composable
fun TriSheet(
    visible: Boolean,
    onDismiss: () -> Unit,
    onRequestDismiss: (() -> Unit)? = null,
    background: Color = Tri.colors.canvas,
    fitContent: Boolean = false,
    content: @Composable () -> Unit,
) {
    val state = remember { MutableTransitionState(false) }
    state.targetState = visible
    if (!state.currentState && !state.targetState && state.isIdle) return
    val requestDismiss = rememberUpdatedState(onRequestDismiss ?: onDismiss)
    val colors = Tri.colors
    Dialog(
        onDismissRequest = { requestDismiss.value() },
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        val view = LocalView.current
        LaunchedEffect(view) {
            (view.parent as? DialogWindowProvider)?.window?.let { window ->
                window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
                window.setWindowAnimations(0)
            }
        }
        var dragOffset by remember { mutableFloatStateOf(0f) }
        val density = LocalDensity.current
        Box(Modifier.fillMaxSize()) {
            AnimatedVisibility(state, enter = fadeIn(tween(250)), exit = fadeOut(tween(250))) {
                Box(
                    Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)).clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { requestDismiss.value() },
                )
            }
            AnimatedVisibility(
                state,
                enter = slideInVertically(tween(320)) { it },
                exit = slideOutVertically(tween(280)) { it },
                modifier = Modifier.fillMaxSize(),
            ) {
                BackHandler { requestDismiss.value() }
                val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + TriSpace.x2
                Column(
                    (if (fitContent) Modifier.fillMaxSize().wrapContentHeight(Alignment.Bottom) else Modifier.fillMaxSize())
                        .padding(top = top)
                        .offset { IntOffset(0, dragOffset.roundToInt().coerceAtLeast(0)) }
                        .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
                        .background(background)
                        .draggable(
                            orientation = Orientation.Vertical,
                            state = rememberDraggableState { delta -> dragOffset = (dragOffset + delta).coerceAtLeast(0f) },
                            onDragStopped = {
                                if (dragOffset > with(density) { 120.dp.toPx() }) requestDismiss.value()
                                dragOffset = 0f
                            },
                        )
                        .imePadding(),
                ) {
                    CompositionLocalProvider(
                        LocalBottomInset provides WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding(),
                    ) {
                        Box(if (fitContent) Modifier.fillMaxWidth() else Modifier.fillMaxSize()) { content() }
                    }
                }
            }
        }
    }
}

/** Bottom padding for a scrolling column: the tab bar (or nav bar) plus a margin. */
@Composable
fun bottomContentPadding(extra: androidx.compose.ui.unit.Dp = TriSpace.x4): PaddingValues =
    PaddingValues(bottom = LocalBottomInset.current + extra)

@Composable
fun Modifier.navigationBarsBottom(): Modifier = this.windowInsetsPadding(WindowInsets.navigationBars)
