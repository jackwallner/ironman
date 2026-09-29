package com.jackwallner.ironsplits.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.data.IronSplitsLegal
import com.jackwallner.ironsplits.data.ReviewPromptTracker
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.theme.CardShape
import com.jackwallner.ironsplits.ui.theme.TitleAlignment
import com.jackwallner.ironsplits.ui.theme.ToolbarTextButton
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriAlert
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriNavBar
import com.jackwallner.ironsplits.ui.theme.TriPrimaryButton
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriTextButton
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding

enum class ReviewOutcome { NOT_NOW, FEEDBACK_DRAFT_OPENED, ENJOYED }

/** The enjoyment check before the store review, with a private feedback path. */
@Composable
fun ReviewPromptSheet(presentation: ReviewPromptTracker.Presentation?, onFinish: (ReviewOutcome) -> Unit) {
    var shown by remember { mutableStateOf(presentation) }
    if (presentation != null) shown = presentation
    var feedback by remember(presentation) { mutableStateOf(presentation == ReviewPromptTracker.Presentation.FEEDBACK_ONLY) }
    val graph = LocalGraph.current
    fun notNow() {
        graph.review.markShown()
        onFinish(ReviewOutcome.NOT_NOW)
    }
    TriSheet(visible = presentation != null, onDismiss = ::notNow, fitContent = !feedback) {
        if (shown == null) return@TriSheet
        Column {
            TriNavBar(
                title = if (feedback) "Help us improve" else "Enjoying IM Tri Tracker?",
                inSheet = true,
                titleAlignment = TitleAlignment.CENTER,
                leading = { ToolbarTextButton("Not now", onClick = ::notNow) },
            )
            if (feedback) FeedbackContent(onFinish) else EnjoymentContent(onYes = { onFinish(ReviewOutcome.ENJOYED) }, onNo = { feedback = true })
        }
    }
}

@Composable
private fun EnjoymentContent(onYes: () -> Unit, onNo: () -> Unit) {
    val colors = Tri.colors
    Column(
        Modifier.fillMaxWidth().padding(horizontal = TriSpace.x6).padding(top = TriSpace.x5).padding(bottomContentPadding(TriSpace.x6)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(TriSpace.x5),
    ) {
        Box(Modifier.size(TriSpace.x10 + TriSpace.x6).background(colors.sunrise, CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.SportsScore, null, tint = colors.inkOnSunrise, modifier = Modifier.size(30.dp))
        }
        Text(
            "If IM Tri Tracker is keeping your race history straight, a quick rating on Google Play makes a real difference.",
            style = TriType.body,
            color = colors.inkSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = TriSpace.x2),
        )
        Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
            TriPrimaryButton("Yes, I'm enjoying it", shape = CircleShape, onClick = onYes)
            TriTextButton(
                "Not really",
                style = TriType.smallBold,
                color = colors.inkSecondary,
                haptic = false,
                centered = true,
                modifier = Modifier.fillMaxWidth(),
                onClick = onNo,
            )
        }
    }
}

@Composable
private fun FeedbackContent(onFinish: (ReviewOutcome) -> Unit) {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val colors = Tri.colors
    var text by remember { mutableStateOf("") }
    var mailFallback by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    fun send() {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        val uri = Uri.parse(
            "mailto:${IronSplitsLegal.FEEDBACK_EMAIL}?subject=${Uri.encode("IM Tri Tracker feedback")}&body=${Uri.encode(trimmed)}",
        )
        val intent = Intent(Intent.ACTION_SENDTO, uri)
        val opened = runCatching { context.startActivity(intent) }.isSuccess
        if (opened) {
            graph.review.markFeedbackDraftOpened()
            onFinish(ReviewOutcome.FEEDBACK_DRAFT_OPENED)
        } else {
            context.getSystemService(ClipboardManager::class.java)?.setPrimaryClip(ClipData.newPlainText("Feedback", trimmed))
            mailFallback = true
        }
    }

    Column(
        Modifier.fillMaxWidth().padding(horizontal = TriSpace.x6).padding(top = TriSpace.x5).padding(bottomContentPadding(TriSpace.x6)),
        verticalArrangement = Arrangement.spacedBy(TriSpace.x4),
    ) {
        Text("What would make IM Tri Tracker work better for you?", style = TriType.body, color = colors.inkSecondary)
        Box(
            Modifier.fillMaxWidth().heightIn(min = TriSpace.x10 * 3 + TriSpace.x4)
                .background(colors.surface, CardShape).border(TriGeo.hairline, colors.hairline, CardShape).padding(TriSpace.x3),
        ) {
            BasicTextField(
                value = text,
                onValueChange = { text = it },
                textStyle = TriType.body.copy(color = colors.ink),
                cursorBrush = SolidColor(colors.sunrise),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp).focusRequester(focus),
            )
        }
        Text(
            "Continues in your mail app with a draft. Your message is sent only if you send it there.",
            style = TriType.small,
            color = colors.inkTertiary,
        )
        TriPrimaryButton(
            "Continue in email",
            shape = CircleShape,
            enabled = text.isNotBlank(),
            modifier = Modifier.height(TriGeo.tapTarget + TriSpace.x1),
            onClick = ::send,
        )
    }
    if (mailFallback) {
        TriAlert(
            title = "Mail isn't available",
            message = "Your message was copied. Email it to ${IronSplitsLegal.FEEDBACK_EMAIL}.",
            confirmTitle = "OK",
            dismissTitle = null,
            onConfirm = { mailFallback = false },
            onDismiss = { mailFallback = false },
        )
    }
}
