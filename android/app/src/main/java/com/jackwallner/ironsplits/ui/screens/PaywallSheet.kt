package com.jackwallner.ironsplits.ui.screens

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CompareArrows
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.ironsplits.data.IronSplitsLegal
import com.jackwallner.ironsplits.data.PaywallTrigger
import com.jackwallner.ironsplits.data.PurchaseOutcome
import com.jackwallner.ironsplits.data.isCancellation
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.TimeFormat
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.icon
import com.jackwallner.ironsplits.ui.openUrl
import com.jackwallner.ironsplits.ui.theme.CardShape
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriTextButton
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import com.jackwallner.ironsplits.ui.theme.triCard
import com.jackwallner.ironsplits.ui.theme.triPress
import kotlinx.coroutines.launch

@Composable
fun PaywallSheet(trigger: PaywallTrigger?, onClose: () -> Unit) {
    var shown by remember { mutableStateOf<PaywallTrigger?>(null) }
    if (trigger != null) shown = trigger
    TriSheet(visible = trigger != null, onDismiss = onClose) {
        shown?.let { PaywallContent(it, onClose) }
    }
}

private fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}

/** The Race Book paywall. Purchases go through RevenueCat unchanged. */
@Composable
private fun PaywallContent(trigger: PaywallTrigger, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val colors = Tri.colors
    val scope = rememberCoroutineScope()
    val store by graph.store.state.collectAsState()
    var purchasing by remember { mutableStateOf(false) }
    var restoring by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var restoreMessage by remember { mutableStateOf<String?>(null) }
    var dismissed by remember { mutableStateOf(false) }

    fun dismissOnce() {
        if (dismissed) return
        dismissed = true
        onClose()
    }

    LaunchedEffect(Unit) {
        graph.store.trackPaywallImpression(trigger.impressionId)
        if (graph.store.current.planOptions.isEmpty()) graph.store.fetchProducts()
    }
    LaunchedEffect(store.isPro) { if (store.isPro) dismissOnce() }

    val plan = store.planOptions.firstOrNull()

    Box(Modifier.fillMaxSize().background(colors.canvas)) {
        when {
            store.isLoadingProducts && store.planOptions.isEmpty() -> Column(
                Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
            ) {
                CircularProgressIndicator(Modifier.size(24.dp), color = colors.sunrise, strokeWidth = 2.5.dp)
                Text("Loading plans…", style = TriType.small, color = colors.inkTertiary)
            }
            store.planOptions.isEmpty() -> Column(
                Modifier.align(Alignment.Center).padding(horizontal = TriSpace.x8),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
            ) {
                Icon(Icons.Filled.WifiOff, null, tint = colors.inkTertiary, modifier = Modifier.size(40.dp))
                Text("Couldn't Load Plans", style = TriType.cardTitle, color = colors.inkSecondary)
                Text(store.lastError ?: "Check your connection and try again.", style = TriType.small, color = colors.inkTertiary, textAlign = TextAlign.Center)
                TriTextButton("Try Again") { scope.launch { graph.store.fetchProducts() } }
            }
            else -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottomContentPadding(0.dp))) {
                Hero(trigger)
                Column(
                    Modifier.padding(horizontal = TriSpace.x5).padding(top = TriSpace.x4, bottom = TriSpace.x5),
                    verticalArrangement = Arrangement.spacedBy(TriSpace.x4),
                ) {
                    Features()
                    ProductPreview()
                    TrustRow()
                    if (plan != null) {
                        Row(Modifier.fillMaxWidth().heightIn(min = TriGeo.tapTarget), verticalAlignment = Alignment.CenterVertically) {
                            Text("One-time lifetime purchase", style = TriType.bodyBold, color = colors.ink, modifier = Modifier.weight(1f))
                            Text(plan.priceLabel, style = TriType.statMed, color = colors.ink)
                        }
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                        Box(
                            Modifier
                                .testTag("buy-race-book")
                                .triPress(enabled = !purchasing && plan?.isPurchasable == true, haptic = true) {
                                    val activity = context.findActivity() ?: return@triPress
                                    val option = plan ?: return@triPress
                                    errorMessage = null
                                    restoreMessage = null
                                    purchasing = true
                                    scope.launch {
                                        try {
                                            when (graph.store.purchase(activity, option)) {
                                                PurchaseOutcome.PURCHASED -> Unit
                                                PurchaseOutcome.PENDING -> restoreMessage =
                                                    "Purchase pending approval. Race Book unlocks automatically once it's approved."
                                                PurchaseOutcome.CANCELLED -> errorMessage = null
                                            }
                                        } catch (error: Throwable) {
                                            if (isCancellation(error)) throw error
                                            errorMessage = error.message ?: "Couldn't complete the purchase. Please try again."
                                        } finally {
                                            purchasing = false
                                        }
                                    }
                                }
                                .fillMaxWidth()
                                .height(TriGeo.tapTarget + TriSpace.x1)
                                .clip(CardShape)
                                .background(colors.sunrise),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(graph.store.directCtaLabel(), style = TriType.bodyBold, color = colors.inkOnSunrise, modifier = Modifier.alpha(if (purchasing) 0f else 1f))
                            if (purchasing) CircularProgressIndicator(Modifier.size(20.dp), color = colors.inkOnSunrise, strokeWidth = 2.dp)
                        }
                        if (plan != null) {
                            Text(
                                "${plan.priceLabel}. One-time purchase. Lifetime access, no subscription.",
                                style = TriType.micro.copy(letterSpacing = 0.2.sp),
                                color = colors.inkTertiary,
                                textAlign = TextAlign.Center,
                            )
                        }
                        errorMessage?.let { Text(it, style = TriType.small, color = colors.sunrise, textAlign = TextAlign.Center) }
                        restoreMessage?.let { Text(it, style = TriType.small, color = colors.inkSecondary, textAlign = TextAlign.Center) }
                        TriTextButton(
                            if (restoring) "Restoring…" else "Restore Purchases",
                            style = TriType.smallBold,
                            color = colors.inkSecondary,
                            enabled = !restoring && !purchasing,
                        ) {
                            errorMessage = null
                            restoreMessage = null
                            restoring = true
                            scope.launch {
                                graph.store.restorePurchases()
                                if (!graph.store.current.isPro) {
                                    restoreMessage = graph.store.current.restoreError ?: "No Race Book purchase was found for this Google account."
                                }
                                restoring = false
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                            TriTextButton("Terms", style = TriType.micro, color = colors.inkTertiary) { context.openUrl(IronSplitsLegal.TERMS_URL) }
                            TriTextButton("Privacy", style = TriType.micro, color = colors.inkTertiary) { context.openUrl(IronSplitsLegal.PRIVACY_URL) }
                        }
                    }
                }
            }
        }
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .padding(TriSpace.x4)
                .semantics { contentDescription = "Close" }
                .triPress(haptic = false) { dismissOnce() }
                .size(TriGeo.tapTarget)
                .clip(CircleShape)
                .background(colors.surface)
                .border(TriGeo.hairline, colors.hairline, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Close, null, tint = colors.inkSecondary, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun Hero(trigger: PaywallTrigger) {
    val colors = Tri.colors
    val icon = when (trigger) {
        PaywallTrigger.RACE_BOOK_COMPARE -> Icons.AutoMirrored.Filled.CompareArrows
        PaywallTrigger.RACE_BOOK_EXPORT -> Icons.Filled.IosShare
        PaywallTrigger.UPGRADE -> Icons.Filled.WorkspacePremium
    }
    Box(
        Modifier.fillMaxWidth().background(Brush.verticalGradient(listOf(colors.deep, colors.deep.copy(alpha = 0.88f)))),
    ) {
        val percentiles = listOf(94, 81, 67, 52, 38, 88, 73, 60, 45, 83, 70)
        Canvas(Modifier.matchParentSize().padding(horizontal = TriSpace.x6).padding(bottom = TriSpace.x3).alpha(0.16f)) {
            val barWidth = 12.dp.toPx()
            val gap = 8.dp.toPx()
            val total = percentiles.size * barWidth + (percentiles.size - 1) * gap
            var x = (size.width - total) / 2
            percentiles.forEach { p ->
                val height = p * 1.05f * density
                drawRoundRect(colors.inkOnDark, Offset(x, size.height - height), Size(barWidth, height), CornerRadius(8.dp.toPx()))
                x += barWidth + gap
            }
        }
        Column(
            Modifier.fillMaxWidth().padding(top = TriSpace.x10 + TriSpace.x6, bottom = TriSpace.x5),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
        ) {
            Box(Modifier.size(70.dp).background(colors.inkOnDark.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = colors.inkOnDark, modifier = Modifier.size(32.dp))
            }
            Text("RACE BOOK", style = TriType.micro.copy(letterSpacing = 2.5.sp), color = colors.inkOnDark.copy(alpha = 0.65f))
            Text(trigger.title, style = TriType.athleteName, color = colors.inkOnDark, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = TriSpace.x4))
            Text(
                trigger.subtitle,
                style = TriType.small,
                color = colors.inkOnDark.copy(alpha = 0.85f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = TriSpace.x6),
            )
        }
    }
}

@Composable
private fun Features() {
    val colors = Tri.colors
    Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
        listOf(
            Icons.AutoMirrored.Filled.CompareArrows to "Compare like-for-like races leg by leg",
            Icons.Filled.Description to "Unlimited PDF and image exports, with optional race notes",
        ).forEach { (icon, title) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                Icon(icon, null, tint = colors.sunrise, modifier = Modifier.width(TriSpace.x6).size(18.dp))
                Text(title, style = TriType.body, color = colors.ink)
            }
        }
    }
}

@Composable
private fun ProductPreview() {
    val graph = LocalGraph.current
    val colors = Tri.colors
    val locker by graph.locker.state.collectAsState()
    val summary = RaceAnalytics.summary(locker.results)
    val bests = RaceAnalytics.personalBests(locker.results, locker.availableKinds.firstOrNull()).take(3)
    Column(
        Modifier.fillMaxWidth().triCard(TriSpace.x3).semantics(mergeDescendants = true) {
            contentDescription = "Race Book preview for ${locker.athlete?.name ?: "your career"}, ${summary.finishes} finishes and personal bests"
        },
        verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                Text("RACE BOOK PREVIEW", style = TriType.micro.copy(letterSpacing = 0.8.sp), color = colors.sunrise)
                Text(locker.athlete?.name ?: "Your race career", style = TriType.cardTitle, color = colors.ink)
            }
            Spacer(Modifier.width(TriSpace.x2))
            Text("${summary.finishes} finishes", style = TriType.smallBold, color = colors.inkSecondary)
        }
        if (bests.isEmpty()) {
            Text("A personal career summary, split bests and race comparisons in one shareable book.", style = TriType.small, color = colors.inkSecondary)
        } else {
            bests.forEach { best ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                    Icon(best.discipline.icon, null, tint = colors.color(best.discipline), modifier = Modifier.width(TriSpace.x6).size(18.dp))
                    Text(best.discipline.title, style = TriType.small, color = colors.inkSecondary, modifier = Modifier.weight(1f))
                    Text(TimeFormat.hms(best.seconds), style = TriType.statSmall, color = colors.ink)
                }
            }
        }
    }
}

@Composable
private fun TrustRow() {
    val colors = Tri.colors
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Bolt, null, tint = colors.inkTertiary, modifier = Modifier.size(13.dp))
        Spacer(Modifier.width(TriSpace.x1))
        Text("Official race results", style = TriType.smallBold, color = colors.inkTertiary)
        Text("  ·  ", style = TriType.smallBold, color = colors.inkTertiary)
        Icon(Icons.Filled.VerifiedUser, null, tint = colors.inkTertiary, modifier = Modifier.size(13.dp))
        Spacer(Modifier.width(TriSpace.x1))
        Text("No subscription", style = TriType.smallBold, color = colors.inkTertiary)
    }
}
