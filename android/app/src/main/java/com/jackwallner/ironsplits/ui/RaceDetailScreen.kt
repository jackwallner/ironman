package com.jackwallner.ironsplits.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.data.FieldPlacement
import com.jackwallner.ironsplits.data.RaceAnalytics
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceResult

@Composable
fun RaceDetailScreen(state: AppUiState, viewModel: IronSplitsViewModel) {
    val result = state.selectedResult ?: return
    val allResults = if (state.detailOrigin == AppTab.EXPLORE) state.profileResults else state.lockerResults
    BackHandler { viewModel.closeRace() }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.small)) {
            IconButton(onClick = viewModel::closeRace, modifier = Modifier.height(Space.tapTarget).width(Space.tapTarget)) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            Column(Modifier.weight(1f)) {
                Text("${result.year} ${result.raceName}", style = MaterialTheme.typography.headlineMedium)
                Text(formatDate(result.eventDate), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(Space.cardRadius),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary),
        ) {
            Column(Modifier.fillMaxWidth().padding(Space.card), verticalArrangement = Arrangement.spacedBy(Space.row)) {
                Text("FINISH", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.78f))
                TimeValue(formatTime(result.finish), Modifier,)
                Text(result.athleteName, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(Space.small)) {
                    result.bib?.let { StatePill("Bib $it") }
                    result.ageGroup?.let { StatePill(it) }
                    StatePill(result.kind.fullLabel)
                }
            }
        }

        if (result.didNotStart || result.didNotFinish || result.disqualified || !result.isFinisher) {
            StatePill(
                when {
                    result.didNotStart -> "Did not start"
                    result.disqualified -> "Disqualified"
                    result.didNotFinish -> "Did not finish"
                    else -> "Finish status unavailable"
                },
            )
        }

        ContentCard {
            SectionHeading("Split breakdown", "Ranks are shown when the timer published them.")
            Discipline.raceLegs.forEach { discipline ->
                SplitDetailRow(
                    result = result,
                    discipline = discipline,
                    placement = if (state.loadingField) null else RaceAnalytics.placement(result, discipline, state.fieldResults),
                    isPersonalBest = RaceAnalytics.isPersonalBest(result, discipline, allResults),
                )
            }
            SplitDetailRow(
                result = result,
                discipline = Discipline.FINISH,
                placement = if (state.loadingField) null else RaceAnalytics.placement(result, Discipline.FINISH, state.fieldResults),
                isPersonalBest = RaceAnalytics.isPersonalBest(result, Discipline.FINISH, allResults),
            )
        }

        if (state.loadingField) {
            Text("Loading field context", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        ContentCard {
            SectionHeading("Race notes", "Notes are stored only on this device.")
            OutlinedTextField(
                value = state.raceNote,
                onValueChange = viewModel::saveRaceNote,
                modifier = Modifier.fillMaxWidth().testTag("race-note-field"),
                placeholder = { Text("Conditions, gear, nutrition, or what you would change") },
                minLines = 3,
                maxLines = 6,
                supportingText = { Text("${state.raceNote.length}/2000") },
            )
        }
        Text(
            "Results are shown as published by the event timer. Field context is calculated from available finishers in the same event.",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SplitDetailRow(
    result: RaceResult,
    discipline: Discipline,
    placement: FieldPlacement?,
    isPersonalBest: Boolean,
) {
    val seconds = result.seconds(discipline)
    if (seconds == null || seconds <= 0) return
    val overall = result.overallRank(discipline)
    val division = result.divisionRank(discipline)
    Row(
        Modifier.fillMaxWidth().padding(vertical = Space.small),
        horizontalArrangement = Arrangement.spacedBy(Space.row),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(Space.small), verticalAlignment = Alignment.CenterVertically) {
                Text(discipline.label, style = MaterialTheme.typography.titleMedium)
                if (isPersonalBest) StatePill("PB")
            }
            val context = buildList {
                if (overall != null) add("Overall #$overall")
                if (division != null) add("Division #$division")
                if (placement != null) add("${placement.percentile}% of ${placement.fieldSize} finishers")
            }.joinToString(" · ")
            if (context.isNotBlank()) Text(context, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        TimeValue(formatTime(seconds))
    }
}
