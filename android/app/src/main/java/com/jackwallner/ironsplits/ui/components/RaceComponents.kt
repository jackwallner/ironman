package com.jackwallner.ironsplits.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.automirrored.filled.StickyNote2
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.Ordinal
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceDate
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.model.TimeFormat
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriBadge
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType

val Discipline.icon: ImageVector
    get() = when (this) {
        Discipline.SWIM -> Icons.Filled.Pool
        Discipline.BIKE -> Icons.AutoMirrored.Filled.DirectionsBike
        Discipline.RUN -> Icons.AutoMirrored.Filled.DirectionsRun
        Discipline.T1, Discipline.T2, Discipline.TRANSITIONS -> Icons.Filled.SwapVert
        Discipline.FINISH -> Icons.Filled.SportsScore
    }

/**
 * How a finish time divided across the legs. Transitions get a floor so the
 * bar keeps five segments and still matches its legend.
 */
@Composable
fun SplitBar(result: RaceResult, modifier: Modifier = Modifier, height: Dp = 10.dp) {
    val colors = Tri.colors
    val raw = RaceAnalytics.legShares(result)
    if (raw.isEmpty()) return
    val lifted = raw.map { it.discipline to maxOf(it.share, 0.012) }
    val total = lifted.sumOf { it.second }
    val description = raw.joinToString(", ") { "${it.discipline.title} ${TimeFormat.spoken(it.seconds)}" }
    Canvas(
        modifier.fillMaxWidth().height(height).clip(CircleShape)
            .clearAndSetSemantics { contentDescription = description },
    ) {
        val gap = 1.dp.toPx()
        var x = 0f
        lifted.forEach { (discipline, share) ->
            val width = maxOf(1f, size.width * (share / total).toFloat())
            drawRect(colors.color(discipline), topLeft = Offset(x, 0f), size = Size(maxOf(0f, width - gap), size.height))
            x += width
        }
    }
}

@Composable
fun PercentileBar(percentile: Int, modifier: Modifier = Modifier, height: Dp = TriGeo.barTrack) {
    val colors = Tri.colors
    Canvas(modifier.fillMaxWidth().height(height)) {
        val radius = CornerRadius(size.height / 2, size.height / 2)
        drawRoundRect(colors.surfaceSunk, cornerRadius = radius)
        val width = maxOf(size.height, size.width * percentile / 100f)
        drawRoundRect(colors.percentileFill(percentile), size = Size(width, size.height), cornerRadius = radius)
    }
}

/** A row in the locker: race, date, finish time, split bar and PB badges. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RaceRow(result: RaceResult, modifier: Modifier = Modifier, personalBestLegs: Set<Discipline> = emptySet(), hasNote: Boolean = false) {
    val colors = Tri.colors
    val date = RaceDate.text(result)
    val finish = if (result.isComplete) TimeFormat.spoken(result.finish) else when {
        result.disqualified -> "Disqualified"
        result.didNotStart -> "Did not start"
        else -> "Did not finish"
    }
    val parts = mutableListOf(result.raceName, date, finish)
    if (result.ageGroup != null && result.finishRankGroup != null) {
        parts += "${Ordinal.text(result.finishRankGroup)} in ${result.ageGroup}"
    }
    val pbLegs = Discipline.rankable.filter { it in personalBestLegs }
    if (pbLegs.isNotEmpty()) parts += "Personal best: " + pbLegs.joinToString(", ") { it.title }
    if (hasNote) parts += "Has race notes"

    Column(
        modifier.fillMaxWidth().heightIn(min = TriGeo.tapTarget).padding(vertical = TriSpace.x1)
            .clearAndSetSemantics { contentDescription = parts.joinToString(", ") },
        verticalArrangement = Arrangement.spacedBy(TriSpace.x2),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                Text(result.raceName, style = TriType.cardTitle, color = colors.ink)
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(TriSpace.x2),
                    verticalArrangement = Arrangement.spacedBy(TriSpace.x1),
                    itemVerticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(date, style = TriType.small, color = colors.inkTertiary, maxLines = 1)
                    TriBadge(result.kind.title, colors.inkTertiary)
                    result.bib?.let { Text("Bib $it", style = TriType.small, color = colors.inkTertiary, maxLines = 1) }
                    if (hasNote) {
                        Icon(Icons.AutoMirrored.Filled.StickyNote2, null, tint = colors.inkTertiary, modifier = Modifier.size(12.dp))
                    }
                }
            }
            Spacer(Modifier.width(TriSpace.x2))
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                Text(
                    if (result.isComplete) TimeFormat.hms(result.finish) else result.statusLabel.orEmpty(),
                    style = TriType.statLarge,
                    color = if (result.isComplete) colors.ink else colors.negative,
                    maxLines = 1,
                )
                if (result.ageGroup != null && result.finishRankGroup != null) {
                    Text("${result.ageGroup} #${result.finishRankGroup}", style = TriType.small, color = colors.inkTertiary)
                }
            }
        }
        if (result.isComplete) {
            SplitBar(result)
            if (pbLegs.isNotEmpty()) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(TriSpace.x1), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                    pbLegs.forEach { TriBadge("PB ${it.shortTitle}", colors.sunrise, filled = true) }
                }
            }
        }
    }
}

/** Legend for the split bar's colours. */
@Composable
fun SplitLegend(modifier: Modifier = Modifier) {
    val colors = Tri.colors
    Row(
        modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
            .clearAndSetSemantics { contentDescription = "Split colors: swim, T1, bike, T2, run" },
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3, Alignment.CenterHorizontally),
    ) {
        Discipline.legs.forEach { leg ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                Box(Modifier.size(7.dp).background(colors.color(leg), CircleShape))
                Text(leg.title, style = TriType.micro, color = colors.inkTertiary)
            }
        }
    }
}

/** Centered spinner with a caption, for first loads. */
@Composable
fun LoadingState(caption: String?, modifier: Modifier = Modifier) {
    val colors = Tri.colors
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
        androidx.compose.material3.CircularProgressIndicator(Modifier.size(24.dp), color = colors.deep.takeIf { !colors.isDark } ?: colors.inkSecondary, strokeWidth = 2.5.dp)
        if (caption != null) Text(caption, style = TriType.small, color = colors.inkTertiary, textAlign = TextAlign.Center)
    }
}

@Composable
fun SmallSpinner(modifier: Modifier = Modifier) {
    val colors = Tri.colors
    androidx.compose.material3.CircularProgressIndicator(
        modifier.size(18.dp),
        color = if (colors.isDark) colors.inkSecondary else colors.deep,
        strokeWidth = 2.dp,
    )
}
