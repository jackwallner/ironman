package com.jackwallner.ironsplits.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.data.RaceAnalytics
import com.jackwallner.ironsplits.data.SplitStanding
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult

@Composable
fun LockerScreen(state: AppUiState, viewModel: IronSplitsViewModel) {
    if (state.lockerAthlete == null) {
        SearchScreen(state, viewModel, isLocker = true)
    } else {
        LockerDashboard(state, viewModel)
    }
}

@Composable
fun ExploreScreen(state: AppUiState, viewModel: IronSplitsViewModel) {
    SearchScreen(state, viewModel, isLocker = false)
}

@Composable
private fun SearchScreen(state: AppUiState, viewModel: IronSplitsViewModel, isLocker: Boolean) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.small)) {
            ScreenTitle(
                if (isLocker) "Find your race history" else "Explore athletes",
                "Published full and half-distance triathlon results, ranked by split.",
            )
            Text(
                "Search by the name used at registration. You can add a city after a comma.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        OutlinedTextField(
            value = state.searchQuery,
            onValueChange = viewModel::onSearchQueryChanged,
            modifier = Modifier.fillMaxWidth().testTag("athlete-search-field"),
            label = { Text("Athlete name") },
            placeholder = { Text("First and last name") },
            singleLine = true,
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
        )
        Text(
            "Search sends your name and any optional city or state filter to the public timing service. Your Locker and notes stay on this device.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(
            onClick = viewModel::searchNow,
            enabled = state.searchQuery.trim().length >= 2 && !state.isSearching,
            modifier = Modifier.fillMaxWidth().height(Space.tapTarget).testTag("search-button"),
            shape = RoundedCornerShape(Space.cardRadius),
        ) {
            Text("Search published results")
        }

        if (state.isSearching) {
            ElevatedCard(colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Row(
                    Modifier.fillMaxWidth().padding(Space.card),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Space.row),
                ) {
                    CircularProgressIndicator()
                    Column(Modifier.weight(1f)) {
                        Text(if (state.isSubstringSearch) "Searching more broadly" else "Searching published results", fontWeight = FontWeight.SemiBold)
                        Text(
                            if (state.isSubstringSearch) "This can take up to 30 seconds. You can stop at any time."
                            else "Starting with a fast name-prefix search.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = viewModel::stopSearch) { Text("Stop") }
                }
            }
        }

        MessageBanner(state.searchError, viewModel::dismissMessage)

        if (state.isClaimingProfile) {
            ElevatedCard(colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Row(
                    Modifier.fillMaxWidth().padding(Space.card),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Space.row),
                ) {
                    CircularProgressIndicator()
                    Text("Loading your published results", style = MaterialTheme.typography.bodyLarge)
                }
            }
        }

        if (state.searchResults.isNotEmpty()) {
            SectionHeading("Matching athletes", "Choose the profile that matches your results.")
            state.searchResults.forEach { athlete ->
                AthleteChoiceCard(athlete) {
                    viewModel.openAthlete(athlete, saveToLocker = isLocker)
                }
            }
        } else if (state.slowSearchAvailable && !state.isSearching && state.searchQuery.trim().length >= 2) {
            ContentCard {
                Text("No results started with that name.", style = MaterialTheme.typography.titleMedium)
                Text(
                    "Search within names to find people whose first or last name contains your text. The timing service takes longer for this search.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedButton(onClick = viewModel::searchWithinName, modifier = Modifier.height(Space.tapTarget)) {
                    Text("Search within names")
                }
            }
        }

        if (isLocker && state.searchQuery.isBlank() && state.recentAthletes.isNotEmpty()) {
            SectionHeading("Recent Explore profiles")
            state.recentAthletes.forEach { athlete ->
                AthleteChoiceCard(athlete) { viewModel.openAthlete(athlete, saveToLocker = true) }
            }
        }

    }
}

@Composable
private fun AthleteChoiceCard(athlete: Athlete, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().heightIn(min = Space.tapTarget).testTag("athlete-choice"),
        shape = RoundedCornerShape(Space.cardRadius),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(Space.card),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.row),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(athlete.name, style = MaterialTheme.typography.titleMedium)
                Text(
                    athleteLocation(athlete),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text("${athlete.resultCount} results", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun LockerDashboard(state: AppUiState, viewModel: IronSplitsViewModel) {
    val athlete = state.lockerAthlete ?: return
    val summary = RaceAnalytics.summary(state.lockerResults)
    val kinds = RaceAnalytics.availableKinds(state.lockerResults)
    val selectedKind = state.selectedKind ?: kinds.firstOrNull()
    val standings = RaceAnalytics.standings(state.lockerResults, state.selectedDiscipline, selectedKind)
    var showClearConfirmation by remember { mutableStateOf(false) }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) {
        item {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(Space.small)) {
                Column(Modifier.weight(1f)) {
                    Text(athlete.name, style = MaterialTheme.typography.headlineLarge, modifier = Modifier.testTag("locker-athlete-name"))
                    Text(athleteLocation(athlete), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                TextButton(onClick = { showClearConfirmation = true }, modifier = Modifier.height(Space.tapTarget)) {
                    Text("Change")
                }
            }
        }
        item { MessageBanner(state.statusMessage, viewModel::dismissMessage) }
        item {
            ContentCard {
                SectionHeading("Your career", "Published results from the timing service.")
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    SummaryValue("FINISHES", summary.finishes.toString())
                    SummaryValue("FULL", summary.fullDistance.toString())
                    SummaryValue("HALF", summary.halfDistance.toString())
                    SummaryValue("PODIUMS", summary.podiums.toString())
                }
                if (summary.firstYear != null && summary.lastYear != null) {
                    Text("${summary.firstYear}–${summary.lastYear}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(Space.row)) {
                SectionHeading("Split rankings", "Each distance is ranked on its own.")
                Row(horizontalArrangement = Arrangement.spacedBy(Space.small)) {
                    kinds.forEach { kind ->
                        FilterChip(
                            selected = selectedKind == kind,
                            onClick = { viewModel.selectKind(kind) },
                            label = { Text(kind.label) },
                            modifier = Modifier.height(Space.tapTarget),
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(Space.small)) {
                    Discipline.rankings.forEach { discipline ->
                        FilterChip(
                            selected = state.selectedDiscipline == discipline,
                            onClick = { viewModel.selectDiscipline(discipline) },
                            label = { Text(discipline.label) },
                            modifier = Modifier.height(Space.tapTarget),
                        )
                    }
                }
            }
        }
        if (standings.isEmpty()) {
            item {
                ContentCard {
                    Text("No ranked splits yet", style = MaterialTheme.typography.titleMedium)
                    Text("Completed full- and half-distance races appear here when the published result includes this split.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            items(standings, key = { it.result.id + it.discipline.name }) { standing ->
                RankingCard(standing) { viewModel.openRace(standing.result, AppTab.LOCKER) }
            }
        }
        if (state.loadingResults && state.lockerResults.isEmpty()) {
            item { CircularProgressIndicator() }
        }
        if (state.lockerResults.isEmpty() && !state.loadingResults) {
            item {
                ContentCard {
                    Text("No supported results were found", style = MaterialTheme.typography.titleMedium)
                    Text("This locker includes published full- and half-distance triathlon results only.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            Text(
                "Results are shown as published by each event timer. IM Iron Splits is independent and is not affiliated with or endorsed by race organizers or timing companies.",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }

    if (showClearConfirmation) {
        AlertDialog(
            onDismissRequest = { showClearConfirmation = false },
            title = { Text("Change locker athlete?") },
            text = { Text("This removes the saved athlete and cached results from this device. You can search for them again later.") },
            confirmButton = {
                TextButton(onClick = { viewModel.unclaimAthlete(); showClearConfirmation = false }) { Text("Remove athlete") }
            },
            dismissButton = { TextButton(onClick = { showClearConfirmation = false }) { Text("Keep locker") } },
        )
    }
}

@Composable
private fun SummaryValue(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(value, style = MaterialTheme.typography.titleLarge.copy(fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace))
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun RankingCard(standing: SplitStanding, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().heightIn(min = Space.tapTarget),
        shape = RoundedCornerShape(Space.cardRadius),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(Space.card),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.row),
        ) {
            Text("#${standing.rank}", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("${standing.result.year} ${standing.result.raceName}", style = MaterialTheme.typography.titleMedium)
                Text(formatGap(standing.gapToBest), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            TimeValue(formatTime(standing.seconds))
        }
    }
}

@Composable
fun AthletePreviewScreen(state: AppUiState, viewModel: IronSplitsViewModel) {
    val athlete = state.profile ?: return
    BackHandler { viewModel.closeProfile() }
    Column(Modifier.fillMaxSize().padding(horizontal = Space.page, vertical = Space.section)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = viewModel::closeProfile, modifier = Modifier.height(Space.tapTarget).width(Space.tapTarget)) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back to Explore")
            }
            ScreenTitle(athlete.name, athleteLocation(athlete))
        }
        Spacer(Modifier.height(Space.row))
        if (state.loadingResults) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.row)) {
                CircularProgressIndicator()
                Text("Loading published results")
            }
        } else {
            Button(
                onClick = viewModel::saveProfileToLocker,
                modifier = Modifier.fillMaxWidth().height(Space.tapTarget).testTag("save-to-locker"),
            ) { Text("Save to my Locker") }
            Spacer(Modifier.height(Space.row))
            PreviewResults(state.profileResults, state, viewModel, AppTab.EXPLORE)
        }
    }
}

@Composable
private fun PreviewResults(results: List<RaceResult>, state: AppUiState, viewModel: IronSplitsViewModel, origin: AppTab) {
    if (results.isEmpty()) {
        ContentCard {
            Text("No supported results found", style = MaterialTheme.typography.titleMedium)
            Text("Only published full- and half-distance triathlon results are shown.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(Space.row)) {
        items(results, key = RaceResult::id) { result ->
            AthleteRaceCard(result, results) { viewModel.openRace(result, origin) }
        }
    }
}
