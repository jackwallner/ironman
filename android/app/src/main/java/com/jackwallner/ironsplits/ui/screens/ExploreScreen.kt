package com.jackwallner.ironsplits.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.WifiOff
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.ironsplits.AppGraph
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.ResultsApi
import com.jackwallner.ironsplits.data.isCancellation
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.LoadingState
import com.jackwallner.ironsplits.ui.components.RaceRow
import com.jackwallner.ironsplits.ui.components.SplitLegend
import com.jackwallner.ironsplits.ui.nav.LocalNavigator
import com.jackwallner.ironsplits.ui.nav.Route
import com.jackwallner.ironsplits.ui.nav.ScreenModel
import com.jackwallner.ironsplits.ui.nav.rememberRetained
import com.jackwallner.ironsplits.ui.theme.CardShape
import com.jackwallner.ironsplits.ui.theme.ChipRow
import com.jackwallner.ironsplits.ui.theme.IconCircle
import com.jackwallner.ironsplits.ui.theme.StatTile
import com.jackwallner.ironsplits.ui.theme.TitleAlignment
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriChip
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriPlaceholder
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSectionHeader
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import com.jackwallner.ironsplits.ui.theme.triCard
import com.jackwallner.ironsplits.ui.theme.triOutlined
import com.jackwallner.ironsplits.ui.theme.triPress
import kotlinx.coroutines.launch

/** A read-only way to browse another athlete's history. Never touches the Locker. */
@Composable
fun ExploreScreen() {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val colors = Tri.colors
    var showingSearch by remember { mutableStateOf(false) }
    var recents by remember { mutableStateOf(graph.settings.recentAthletes()) }

    LaunchedEffect(Unit) { graph.pattie.fire(PattieMode.Moment.SEARCHING) }

    fun select(athlete: Athlete) {
        recents = (listOf(athlete) + recents.filter { it.id != athlete.id }).take(3)
        graph.settings.saveRecentAthletes(recents)
        navigator.push(Route.ExploreAthlete(athlete))
        graph.pattie.react(PattieMode.Action.SELECTION)
    }

    TriScreen(title = "Explore") {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                .padding(horizontal = TriGeo.padPage).padding(top = TriSpace.x4).padding(bottomContentPadding()),
            verticalArrangement = Arrangement.spacedBy(TriSpace.x6),
        ) {
            Column(Modifier.fillMaxWidth().triCard(TriSpace.x4), verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                Row(horizontalArrangement = Arrangement.spacedBy(TriSpace.x3), verticalAlignment = Alignment.Top) {
                    IconCircle(Icons.Filled.People, colors.sunrise, size = TriSpace.x10, iconSize = 22.dp)
                    Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                        Text("EXPLORE RACERS", style = TriType.sectionTitle.copy(letterSpacing = 1.2.sp), color = colors.sunrise)
                        Text("See the story behind the splits", style = TriType.pageTitle, color = colors.ink)
                    }
                }
                Text(
                    "Search the official results index for another athlete and browse a focused full and half-distance race history. Your Locker stays exactly as it is.",
                    style = TriType.body,
                    color = colors.inkSecondary,
                )
            }
            Row(
                Modifier
                    .semantics { contentDescription = "Find a racer. Search official results without changing Locker" }
                    .triPress {
                        graph.pattie.react(PattieMode.Action.SELECTION)
                        showingSearch = true
                    }
                    .fillMaxWidth()
                    .heightIn(min = TriGeo.tapTarget)
                    .clip(CardShape)
                    .background(colors.deep)
                    .padding(horizontal = TriSpace.x4, vertical = TriSpace.x3),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
            ) {
                Icon(Icons.Filled.Search, null, tint = colors.inkOnDark, modifier = Modifier.width(TriSpace.x8).size(20.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                    Text("Find a racer", style = TriType.bodyBold, color = colors.inkOnDark)
                    Text("Open their career without changing Locker", style = TriType.small, color = colors.inkOnDark.copy(alpha = 0.72f))
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkOnDark.copy(alpha = 0.8f))
            }
            if (recents.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                    TriSectionHeader("Recently explored")
                    recents.forEach { athlete ->
                        ExploreAthleteRow(athlete) {
                            graph.pattie.react(PattieMode.Action.SELECTION)
                            navigator.push(Route.ExploreAthlete(athlete))
                        }
                    }
                }
            }
        }
    }

    TriSheet(visible = showingSearch, onDismiss = { showingSearch = false }) {
        AthleteSearchScreen(SearchPurpose.EXPLORE, onClose = { showingSearch = false }, onSelect = ::select)
    }
}

@Composable
private fun ExploreAthleteRow(athlete: Athlete, onClick: () -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier.triPress(onClick = onClick).fillMaxWidth().heightIn(min = TriGeo.tapTarget).triOutlined(TriSpace.x3),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Box(Modifier.size(TriSpace.x10), contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.AccountCircle, null, tint = colors.deep.takeIf { !colors.isDark } ?: colors.finish, modifier = Modifier.size(32.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(athlete.name, style = TriType.cardTitle, color = colors.ink)
            athlete.location?.let { Text(it, style = TriType.small, color = colors.inkTertiary) }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
    }
}

private sealed interface ExploreLoad {
    data object Idle : ExploreLoad
    data object Loading : ExploreLoad
    data object Loaded : ExploreLoad
    data class Failed(val message: String) : ExploreLoad
}

private class ExploreAthleteModel(private val graph: AppGraph, private val athlete: Athlete) : ScreenModel() {
    var results by mutableStateOf<List<RaceResult>>(emptyList())
    var state by mutableStateOf<ExploreLoad>(ExploreLoad.Idle)
    var selectedKind by mutableStateOf<RaceKind?>(null)

    fun load(retry: Boolean = false) {
        if (state != ExploreLoad.Idle && !retry) return
        if (state == ExploreLoad.Loading) return
        state = ExploreLoad.Loading
        scope.launch {
            try {
                val loaded = graph.seededCareers[athlete.id] ?: graph.api.results(athlete.contactIds)
                results = loaded
                val kinds = RaceAnalytics.availableKinds(loaded)
                if (selectedKind !in kinds) selectedKind = kinds.firstOrNull()
                state = ExploreLoad.Loaded
            } catch (error: Throwable) {
                if (isCancellation(error)) {
                    state = ExploreLoad.Idle
                    throw error
                }
                state = ExploreLoad.Failed(ResultsApi.userFacingMessage(error))
            }
        }
    }
}

@Composable
fun ExploreAthleteScreen(athlete: Athlete) {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val colors = Tri.colors
    val model = rememberRetained("explore-${athlete.id}") { ExploreAthleteModel(graph, athlete) }
    LaunchedEffect(Unit) { model.load() }

    TriScreen(title = athlete.name, onBack = { navigator.pop() }, titleAlignment = TitleAlignment.CENTER) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                .padding(horizontal = TriGeo.padPage).padding(top = TriSpace.x4).padding(bottomContentPadding(TriSpace.x8)),
            verticalArrangement = Arrangement.spacedBy(TriSpace.x6),
        ) {
            ProfileHeader(athlete, model.results)
            val state = model.state
            when {
                state is ExploreLoad.Failed -> TriPlaceholder(
                    Icons.Filled.WifiOff, "Couldn't load this history", message = state.message, actionTitle = "Try again",
                ) { model.load(retry = true) }
                model.results.isEmpty() && (state == ExploreLoad.Loading || state == ExploreLoad.Idle) ->
                    LoadingState("Loading this career…", Modifier.fillMaxWidth().heightIn(min = 80.dp))
                model.results.isEmpty() -> TriPlaceholder(
                    Icons.Filled.SportsScore, "No supported results",
                    message = "This racer has no published full or half-distance results in the feed.",
                )
                else -> {
                    val kinds = RaceAnalytics.availableKinds(model.results)
                    val active = model.selectedKind ?: kinds.firstOrNull()
                    Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                        TriSectionHeader("Distance")
                        ChipRow {
                            kinds.forEach { kind -> TriChip(kind.longTitle, active == kind) { model.selectedKind = kind } }
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                        TriSectionHeader("Race history", trailing = active?.longTitle)
                        val visible = if (active == null) model.results else model.results.filter { it.kind == active }
                        visible.forEach { result ->
                            Box(
                                Modifier.triPress {
                                    navigator.push(Route.RaceDetail(result, context = model.results, readOnly = true))
                                }.triOutlined(TriSpace.x3),
                            ) {
                                RaceRow(result)
                            }
                        }
                        SplitLegend(Modifier.padding(top = TriSpace.x1))
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProfileHeader(athlete: Athlete, results: List<RaceResult>) {
    val colors = Tri.colors
    val summary = remember(results) { RaceAnalytics.summary(results) }
    val caption = colors.inkOnDark.copy(alpha = 0.6f)
    Column(
        Modifier.fillMaxWidth().clip(CardShape).background(colors.deep).padding(TriGeo.padCard),
        verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Text(athlete.name, style = TriType.athleteName, color = colors.inkOnDark)
        athlete.location?.let { Text(it, style = TriType.small, color = colors.inkOnDark.copy(alpha = 0.7f)) }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(TriSpace.x4), verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
            StatTile("${summary.finishes}", "Finishes", colors.inkOnDark, caption)
            if (summary.fullDistance > 0) StatTile("${summary.fullDistance}", "Full", colors.inkOnDark, caption)
            if (summary.halfDistance > 0) StatTile("${summary.halfDistance}", "Half", colors.inkOnDark, caption)
            if (summary.podiums > 0) StatTile("${summary.podiums}", "Podiums", colors.sunrise, caption)
        }
        summary.years?.let { Text("Racing since ${it.first}", style = TriType.micro, color = colors.inkOnDark.copy(alpha = 0.62f)) }
    }
}
