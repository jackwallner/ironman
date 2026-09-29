package com.jackwallner.ironsplits.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.PersonAddAlt1
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.ironsplits.data.LoadState
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.relativeTime
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.model.SplitStanding
import com.jackwallner.ironsplits.model.TimeFormat
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.LoadingState
import com.jackwallner.ironsplits.ui.components.RaceRow
import com.jackwallner.ironsplits.ui.components.SplitLegend
import com.jackwallner.ironsplits.ui.nav.LocalNavigator
import com.jackwallner.ironsplits.ui.nav.Route
import com.jackwallner.ironsplits.ui.theme.ChipRow
import com.jackwallner.ironsplits.ui.theme.GroupHeader
import com.jackwallner.ironsplits.ui.theme.GroupRow
import com.jackwallner.ironsplits.ui.theme.IconCircle
import com.jackwallner.ironsplits.ui.theme.InsetGroup
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
import com.jackwallner.ironsplits.ui.theme.triPress
import kotlinx.coroutines.launch

/** Every race the athlete has done, newest first, or their split rankings. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LockerScreen() {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val colors = Tri.colors
    val scope = rememberCoroutineScope()
    val lockerState by graph.locker.state.collectAsState()
    val settings by graph.settings.state.collectAsState()
    val notes by graph.notes.notes.collectAsState()

    var showingAthleteSearch by remember { mutableStateOf(false) }
    var showingAddRegistration by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    var kindFilter by rememberSaveable { mutableStateOf<RaceKind?>(null) }
    var showingRankings by rememberSaveable { mutableStateOf(false) }
    var rankingDiscipline by rememberSaveable { mutableStateOf(Discipline.FINISH) }
    var raceSearch by rememberSaveable { mutableStateOf("") }
    var refreshing by remember { mutableStateOf(false) }

    val availableKinds = lockerState.availableKinds
    val results = lockerState.results

    LaunchedEffect(Unit) { graph.pattie.fire(PattieMode.Moment.WELCOME) }
    LaunchedEffect(lockerState.athlete?.id) {
        val preferred = settings.preferredKind
        kindFilter = if (preferred != null && preferred in availableKinds) preferred else null
    }
    LaunchedEffect(availableKinds) {
        val current = kindFilter
        if (current != null && current !in availableKinds) kindFilter = if (showingRankings) availableKinds.firstOrNull() else null
    }

    fun refresh() {
        graph.pattie.react(PattieMode.Action.REFRESH)
        graph.locker.refresh(force = true)
    }

    TriScreen(
        title = "Locker",
        titleAlignment = TitleAlignment.START,
        trailing = {
            Box {
                Row(
                    Modifier.clip(CircleShape).background(colors.toolbarCircle).padding(start = TriSpace.x4, end = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "Change",
                        style = TriType.smallBold.copy(fontSize = 15.sp),
                        color = colors.toolbarContent,
                        modifier = Modifier
                            .semantics { contentDescription = "Change athlete" }
                            .triPress(haptic = false) {
                                graph.pattie.react(PattieMode.Action.SELECTION)
                                showingAthleteSearch = true
                            }
                            .heightIn(min = TriGeo.tapTarget)
                            .padding(end = TriSpace.x3)
                            .wrapContentHeight(),
                    )
                    Box(
                        Modifier
                            .semantics { contentDescription = "More locker actions" }
                            .triPress { menuOpen = true }
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(colors.deep),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Filled.MoreHoriz, null, tint = colors.inkOnDark, modifier = Modifier.size(20.dp))
                    }
                }
                DropdownMenu(
                    expanded = menuOpen,
                    onDismissRequest = { menuOpen = false },
                    containerColor = colors.surface,
                ) {
                    DropdownMenuItem(
                        text = { Text("Add another registration", style = TriType.body, color = colors.ink) },
                        leadingIcon = { Icon(Icons.Filled.PersonAddAlt1, null, tint = colors.ink) },
                        onClick = {
                            menuOpen = false
                            showingAddRegistration = true
                        },
                    )
                    DropdownMenuItem(
                        text = { Text("Refresh results", style = TriType.body, color = colors.ink) },
                        leadingIcon = { Icon(Icons.Filled.Refresh, null, tint = colors.ink) },
                        onClick = {
                            menuOpen = false
                            refresh()
                        },
                    )
                }
            }
        },
    ) {
        val state = lockerState.loadState
        when {
            state == LoadState.Loading && results.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                LoadingState("Pulling your results…")
            }
            state is LoadState.Failed && results.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                TriPlaceholder(Icons.Filled.WifiOff, "Couldn't load your races", message = state.message, actionTitle = "Try again") { refresh() }
            }
            results.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                TriPlaceholder(
                    Icons.Filled.SportsScore,
                    "No results yet",
                    message = "We couldn't find any published results under this athlete. If you registered under a different name, pick the right one.",
                    actionTitle = "Change athlete",
                ) {
                    graph.pattie.react(PattieMode.Action.SELECTION)
                    showingAthleteSearch = true
                }
            }
            else -> PullToRefreshBox(
                isRefreshing = refreshing,
                onRefresh = {
                    refreshing = true
                    scope.launch {
                        graph.locker.refresh(force = true).join()
                        refreshing = false
                        graph.pattie.fire(PattieMode.Moment.REFRESHED)
                    }
                },
                modifier = Modifier.fillMaxSize(),
            ) {
                val search = raceSearch.trim()
                val rankingKind = kindFilter ?: settings.preferredKind?.takeIf { it in availableKinds } ?: availableKinds.firstOrNull()
                val standings = remember(results, rankingDiscipline, rankingKind, search) {
                    RaceAnalytics.standings(results, rankingDiscipline, rankingKind)
                        .filter { search.isEmpty() || it.result.raceName.contains(search, ignoreCase = true) }
                }
                val groups = remember(results, kindFilter, search) {
                    results.filter { kindFilter == null || it.kind == kindFilter }
                        .filter { search.isEmpty() || it.raceName.contains(search, ignoreCase = true) }
                        .groupBy { it.year }
                        .toSortedMap(compareByDescending { it })
                        .toList()
                }
                val personalBests = remember(results) { personalBestMap(results) }
                LazyColumn(
                    state = rememberLazyListState(),
                    contentPadding = bottomContentPadding(),
                    modifier = Modifier.fillMaxSize().testTag("locker-list"),
                ) {
                    item("search") {
                        RaceSearchField(raceSearch, { raceSearch = it })
                    }
                    item("header") {
                        LockerHeader(lockerState.athlete, results, lockerState.lastRefreshed)
                    }
                    lockerState.refreshWarning?.let { warning ->
                        item("warning") {
                            InsetGroup(Modifier.padding(top = TriSpace.x4)) {
                                GroupRow {
                                    Icon(Icons.Filled.Info, null, tint = colors.inkSecondary, modifier = Modifier.size(18.dp))
                                    Spacer(Modifier.width(TriSpace.x2))
                                    Text(warning, style = TriType.small, color = colors.inkSecondary)
                                }
                            }
                        }
                    }
                    if (availableKinds.size > 1) {
                        item("kinds") {
                            ChipRow(Modifier.padding(top = TriSpace.x5), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = TriGeo.padPage)) {
                                if (!showingRankings) {
                                    TriChip("All", kindFilter == null) {
                                        kindFilter = null
                                        graph.settings.preferredKind = null
                                        graph.pattie.react(PattieMode.Action.FILTER)
                                    }
                                }
                                availableKinds.forEach { kind ->
                                    TriChip(kind.longTitle, kindFilter == kind) {
                                        kindFilter = kind
                                        graph.settings.preferredKind = kind
                                        graph.pattie.react(PattieMode.Action.FILTER)
                                    }
                                }
                            }
                        }
                    }
                    item("mode") {
                        Row(
                            Modifier.padding(horizontal = TriGeo.padPage).padding(top = TriSpace.x5),
                            horizontalArrangement = Arrangement.spacedBy(TriSpace.x2),
                        ) {
                            TriChip("Races", !showingRankings) { showingRankings = false }
                            TriChip("Rankings", showingRankings) {
                                if (kindFilter == null) {
                                    kindFilter = settings.preferredKind?.takeIf { it in availableKinds } ?: availableKinds.firstOrNull()
                                }
                                showingRankings = true
                            }
                        }
                    }
                    if (showingRankings) {
                        item("ranking-picker") {
                            ChipRow(Modifier.padding(top = TriSpace.x3), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = TriGeo.padPage)) {
                                Discipline.rankable.forEach { discipline ->
                                    TriChip(discipline.shortTitle, rankingDiscipline == discipline) {
                                        rankingDiscipline = discipline
                                        graph.pattie.react(PattieMode.Action.FILTER)
                                    }
                                }
                            }
                        }
                        item("ranking-header") {
                            TriSectionHeader(
                                "${rankingDiscipline.title} rankings",
                                trailing = rankingKind?.longTitle,
                                modifier = Modifier.padding(horizontal = TriGeo.padPage + TriSpace.x1).padding(top = TriSpace.x4, bottom = TriSpace.x2),
                            )
                        }
                        item("rankings") {
                            InsetGroup {
                                if (standings.isEmpty()) {
                                    GroupRow {
                                        Text("Finish a race at this distance to see your split rankings.", style = TriType.small, color = colors.inkTertiary)
                                    }
                                } else {
                                    standings.forEachIndexed { index, standing ->
                                        GroupRow(showDivider = index < standings.lastIndex, chevron = true, onClick = {
                                            navigator.push(Route.RaceDetail(standing.result))
                                        }) {
                                            SplitStandingRow(standing)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        groups.forEach { (year, raceResults) ->
                            item("year-$year") {
                                Column {
                                    GroupHeader(if (year > 0) year.toString() else "Undated")
                                    InsetGroup {
                                        raceResults.forEachIndexed { index, result ->
                                            GroupRow(showDivider = index < raceResults.lastIndex, chevron = true, onClick = {
                                                navigator.push(Route.RaceDetail(result))
                                            }) {
                                                RaceRow(
                                                    result,
                                                    personalBestLegs = personalBests[result.id].orEmpty(),
                                                    hasNote = notes[result.id]?.isEmpty == false,
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        item("add-registration") {
                            InsetGroup(Modifier.padding(top = TriSpace.x6)) {
                                GroupRow(onClick = { showingAddRegistration = true }) { AddRegistrationCard() }
                            }
                        }
                        item("legend") {
                            SplitLegend(Modifier.padding(top = TriSpace.x6, bottom = TriSpace.x2))
                        }
                    }
                }
            }
        }
    }

    TriSheet(visible = showingAthleteSearch, onDismiss = { showingAthleteSearch = false }) {
        AthleteSearchScreen(SearchPurpose.CHANGE, onClose = { showingAthleteSearch = false })
    }
    TriSheet(visible = showingAddRegistration, onDismiss = { showingAddRegistration = false }) {
        AthleteSearchScreen(SearchPurpose.ADD_REGISTRATION, onClose = { showingAddRegistration = false })
    }
}

/** For each race, the legs where it holds the best time among two or more. */
private fun personalBestMap(results: List<RaceResult>): Map<String, Set<Discipline>> {
    val map = mutableMapOf<String, MutableSet<Discipline>>()
    for (kind in RaceAnalytics.availableKinds(results)) {
        for (discipline in Discipline.rankable) {
            val ranked = RaceAnalytics.standings(results, discipline, kind)
            if (ranked.size <= 1) continue
            val best = ranked.first().seconds
            ranked.filter { it.seconds == best }.forEach { map.getOrPut(it.result.id) { mutableSetOf() }.add(discipline) }
        }
    }
    return map
}

@Composable
private fun RaceSearchField(value: String, onValueChange: (String) -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier
            .padding(horizontal = TriGeo.padPage, vertical = TriSpace.x2)
            .padding(top = TriSpace.x2)
            .fillMaxWidth()
            .heightIn(min = TriGeo.tapTarget)
            .clip(CircleShape)
            .background(colors.surfaceAlt.takeIf { !colors.isDark } ?: colors.surface)
            .padding(start = TriSpace.x3),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Search, null, tint = colors.inkSecondary, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(TriSpace.x2))
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (value.isEmpty()) Text("Search races", style = TriType.field, color = colors.inkSecondary, maxLines = 1)
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                textStyle = TriType.field.copy(color = colors.ink),
                cursorBrush = SolidColor(colors.sunrise),
                keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, imeAction = ImeAction.Search),
                modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Search races" },
            )
        }
        if (value.isNotEmpty()) {
            Box(
                Modifier.size(TriGeo.tapTarget).triPress(haptic = true, label = "Clear race search") { onValueChange("") },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Cancel, "Clear race search", tint = colors.inkTertiary, modifier = Modifier.size(18.dp))
            }
        } else {
            Spacer(Modifier.width(TriSpace.x3))
        }
    }
}

/** Career summary above the race list, on the navy brand colour. */
@Composable
private fun LockerHeader(athlete: Athlete?, results: List<RaceResult>, lastRefreshed: Long?) {
    val colors = Tri.colors
    val summary = remember(results) { RaceAnalytics.summary(results) }
    Column(
        Modifier
            .padding(horizontal = TriGeo.padPage)
            .fillMaxWidth()
            .clip(com.jackwallner.ironsplits.ui.theme.CardShape)
            .background(colors.deep)
            .padding(TriGeo.padCard),
        verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        if (athlete != null) {
            Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                Text(athlete.name, style = TriType.athleteName, color = colors.inkOnDark, modifier = Modifier.testTag("locker-athlete-name"))
                athlete.location?.let { Text(it, style = TriType.small, color = colors.inkOnDark.copy(alpha = 0.7f)) }
            }
        }
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = TriSpace.x1),
            horizontalArrangement = Arrangement.spacedBy(TriSpace.x6),
        ) {
            val caption = colors.inkOnDark.copy(alpha = 0.6f)
            StatTile("${summary.finishes}", "Finishes", colors.inkOnDark, caption)
            if (summary.fullDistance > 0) StatTile("${summary.fullDistance}", "Full", colors.inkOnDark, caption)
            if (summary.halfDistance > 0) StatTile("${summary.halfDistance}", "Half", colors.inkOnDark, caption)
            if (summary.podiums > 0) StatTile("${summary.podiums}", "Podiums", colors.sunrise, caption)
        }
        summary.years?.let {
            Text("Racing since ${it.first}", style = TriType.micro, color = colors.inkOnDark.copy(alpha = 0.6f))
        }
        lastRefreshed?.let {
            Text("Updated ${relativeTime(it)}", style = TriType.micro, color = colors.inkOnDark.copy(alpha = 0.6f))
        }
    }
}

@Composable
private fun AddRegistrationCard() {
    val colors = Tri.colors
    Row(
        Modifier.padding(vertical = TriSpace.x1).semantics(mergeDescendants = true) {
            contentDescription = "Missing a race? Add another registration name to your career"
        },
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        IconCircle(Icons.Filled.PersonAddAlt1, colors.sunrise)
        Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text("Missing a race?", style = TriType.cardTitle, color = colors.ink)
            Text("Add another registration name to your career.", style = TriType.small, color = colors.inkTertiary)
        }
    }
}

@Composable
private fun SplitStandingRow(standing: SplitStanding) {
    val colors = Tri.colors
    val gap = if (standing.gapToBest == 0) "personal best" else "${TimeFormat.hms(standing.gapToBest)} behind best"
    Row(
        Modifier.heightIn(min = TriGeo.tapTarget).semantics(mergeDescendants = true) {
            contentDescription = "${standing.rank}, ${standing.result.raceName}, ${standing.result.year}, " +
                "${standing.discipline.title} ${TimeFormat.hms(standing.seconds)}, $gap"
        },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            standing.rank.toString(),
            style = TriType.statMed,
            color = if (standing.isPersonalBest) colors.sunrise else colors.inkSecondary,
            modifier = Modifier.widthIn(min = TriSpace.x8),
        )
        Spacer(Modifier.width(TriSpace.x3))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(standing.result.raceName, style = TriType.cardTitle, color = colors.ink)
            Text("${standing.result.year} · ${standing.result.kind.title}", style = TriType.small, color = colors.inkTertiary)
        }
        Spacer(Modifier.width(TriSpace.x2))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(TimeFormat.hms(standing.seconds), style = TriType.statMed, color = colors.ink)
            Text(
                if (standing.gapToBest == 0) "Personal best" else "+${TimeFormat.hms(standing.gapToBest)}",
                style = TriType.small,
                color = if (standing.gapToBest == 0) colors.sunrise else colors.inkTertiary,
            )
        }
    }
}
