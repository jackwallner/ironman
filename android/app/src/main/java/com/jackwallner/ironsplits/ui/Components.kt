package com.jackwallner.ironsplits.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.ironsplits.data.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceResult

object Space {
    val page = 20.dp
    val card = 16.dp
    val section = 20.dp
    val row = 12.dp
    val control = 12.dp
    val small = 8.dp
    val tapTarget = 48.dp
    val cardRadius = 12.dp
    val badgeRadius = 8.dp
}

@Composable
fun PageColumn(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) { content() }
}

@Composable
fun ContentCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Space.cardRadius),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            Modifier.fillMaxWidth().padding(Space.card),
            verticalArrangement = Arrangement.spacedBy(Space.row),
        ) { content() }
    }
}

@Composable
fun SectionHeading(title: String, detail: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, style = MaterialTheme.typography.titleLarge)
        if (detail != null) Text(detail, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun QuietLabel(text: String, modifier: Modifier = Modifier) {
    Text(text, modifier, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
fun TimeValue(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier,
        style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Monospace),
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface,
        maxLines = 1,
    )
}

@Composable
fun StatePill(text: String, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(Space.badgeRadius),
        color = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Text(text, Modifier.padding(horizontal = Space.small, vertical = 4.dp), style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
fun AthleteRaceCard(result: RaceResult, allResults: List<RaceResult>, onClick: () -> Unit) {
    androidx.compose.material3.Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().heightIn(min = Space.tapTarget),
        shape = RoundedCornerShape(Space.cardRadius),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(Space.card),
            horizontalArrangement = Arrangement.spacedBy(Space.row),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("${result.year} ${result.raceName}", style = MaterialTheme.typography.titleMedium)
                Text(formatDate(result.eventDate), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(horizontalArrangement = Arrangement.spacedBy(Space.small), verticalAlignment = Alignment.CenterVertically) {
                    StatePill(result.kind.label)
                    result.ageGroup?.let { StatePill(it) }
                    if (RaceAnalytics.isPersonalBest(result, com.jackwallner.ironsplits.model.Discipline.FINISH, allResults)) {
                        StatePill("Best finish")
                    }
                }
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                TimeValue(formatTime(result.finish))
                result.finishRankOverall?.let {
                    QuietLabel("Overall #$it")
                }
            }
        }
    }
}

@Composable
fun StatValue(label: String, value: String, modifier: Modifier = Modifier, valueFontSize: androidx.compose.ui.unit.TextUnit = 24.sp) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(value, style = MaterialTheme.typography.headlineMedium.copy(fontFamily = FontFamily.Monospace, fontSize = valueFontSize))
        QuietLabel(label)
    }
}

@Composable
fun SpacerRow() {
    Spacer(Modifier.width(Space.small))
}

@Composable
fun AccentRule(modifier: Modifier = Modifier) {
    Spacer(modifier.fillMaxWidth().height(4.dp).background(MaterialTheme.colorScheme.secondary, CircleShape))
}
