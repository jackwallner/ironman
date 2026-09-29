package com.jackwallner.ironsplits.ui.screens

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CompareArrows
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.model.RaceBookAnalytics
import com.jackwallner.ironsplits.model.RaceBookLegDelta
import com.jackwallner.ironsplits.model.RaceDate
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.model.TimeFormat
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.icon
import com.jackwallner.ironsplits.ui.nav.LocalNavigator
import com.jackwallner.ironsplits.ui.theme.ChipRow
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriCardColumn
import com.jackwallner.ironsplits.ui.theme.TriChip
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriPlaceholder
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSectionHeader
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import com.jackwallner.ironsplits.ui.theme.triCard
import com.jackwallner.ironsplits.ui.theme.triPress
import java.time.LocalDate

private fun sortDate(result: RaceResult): LocalDate = result.eventDate ?: LocalDate.of(maxOf(result.year, 1), 1, 1)

/** Like-for-like comparison: both selectors draw from one distance, leg by leg. */
@Composable
fun RaceCompareScreen(initialKind: RaceKind?) {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val colors = Tri.colors
    val locker by graph.locker.state.collectAsState()
    val availableKinds = locker.availableKinds
    var selectedKind by rememberSaveable { mutableStateOf(initialKind) }
    var baselineId by rememberSaveable { mutableStateOf<String?>(null) }
    var comparisonId by rememberSaveable { mutableStateOf<String?>(null) }

    val activeKind = selectedKind ?: availableKinds.firstOrNull()
    val races = RaceBookAnalytics.comparableRaces(locker.results, activeKind)

    fun syncRaces() {
        val ids = races.map { it.id }.toSet()
        if (baselineId != null && baselineId !in ids) baselineId = null
        if (comparisonId != null && comparisonId !in ids) comparisonId = null
        if (races.size < 2) return
        if (baselineId == null) baselineId = races[1].id
        if (comparisonId == null || comparisonId == baselineId) comparisonId = races[0].id
        if (baselineId == comparisonId) comparisonId = races.firstOrNull { it.id != baselineId }?.id
    }

    LaunchedEffect(activeKind, locker.results) {
        if (selectedKind == null || selectedKind !in availableKinds) selectedKind = availableKinds.firstOrNull()
        syncRaces()
    }

    val baseline = races.firstOrNull { it.id == baselineId }
    val comparison = races.firstOrNull { it.id == comparisonId }
    val pair = if (baseline != null && comparison != null) {
        if (sortDate(baseline) <= sortDate(comparison)) baseline to comparison else comparison to baseline
    } else null
    val deltas = pair?.let { RaceBookAnalytics.deltas(it.first, it.second) }.orEmpty()

    fun select(id: String, isBaseline: Boolean) {
        if (isBaseline) baselineId = id else comparisonId = id
        val b = races.firstOrNull { it.id == baselineId } ?: return
        val c = races.firstOrNull { it.id == comparisonId } ?: return
        if (sortDate(b) > sortDate(c)) {
            val swap = baselineId
            baselineId = comparisonId
            comparisonId = swap
        }
    }

    TriScreen(title = "Compare races", onBack = { navigator.pop() }) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                .padding(horizontal = TriGeo.padPage).padding(top = TriSpace.x4).padding(bottomContentPadding(TriSpace.x8)),
            verticalArrangement = Arrangement.spacedBy(TriSpace.x6),
        ) {
            Text(
                "Choose two finishes at the same distance. Each leg reads from the earlier race to the later race.",
                style = TriType.body,
                color = colors.inkSecondary,
            )
            if (availableKinds.size > 1) {
                Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                    TriSectionHeader("Distance")
                    ChipRow {
                        availableKinds.forEach { kind ->
                            TriChip(kind.longTitle, activeKind == kind) {
                                selectedKind = kind
                                graph.pattie.react(PattieMode.Action.FILTER)
                            }
                        }
                    }
                }
            }
            RaceSelector("Earlier race", activeKind, races, baselineId) {
                select(it, isBaseline = true)
                graph.pattie.react(PattieMode.Action.SELECTION)
            }
            RaceSelector("Later race", activeKind, races, comparisonId) {
                select(it, isBaseline = false)
                graph.pattie.react(PattieMode.Action.SELECTION)
            }
            if (pair != null) {
                TriCardColumn(padding = TriSpace.x3) {
                    TriSectionHeader("Time by leg")
                    Text("${pair.first.raceName} to ${pair.second.raceName}", style = TriType.small, color = colors.inkTertiary)
                    deltas.forEach { DeltaRow(it) }
                    if (deltas.isEmpty()) {
                        Text("These results do not have comparable positive split times yet.", style = TriType.small, color = colors.inkTertiary)
                    }
                }
            } else {
                Box(Modifier.fillMaxWidth().triCard(TriSpace.x3)) {
                    TriPlaceholder(
                        Icons.AutoMirrored.Filled.CompareArrows,
                        "Choose two finishes",
                        message = "The leg-by-leg comparison will appear here.",
                    )
                }
            }
        }
    }
}

private fun raceLabel(result: RaceResult) = "${RaceDate.text(result)}, ${result.raceName}"

@Composable
private fun RaceSelector(title: String, kind: RaceKind?, races: List<RaceResult>, selectedId: String?, onSelect: (String) -> Unit) {
    val colors = Tri.colors
    var open by androidx.compose.runtime.remember { mutableStateOf(false) }
    TriCardColumn(padding = TriSpace.x3, spacing = TriSpace.x2) {
        TriSectionHeader(title, trailing = kind?.longTitle)
        Box {
            Row(
                Modifier.semantics { contentDescription = "$title: ${races.firstOrNull { it.id == selectedId }?.let(::raceLabel) ?: "Choose a finish"}" }
                    .triPress(haptic = true) { open = true }
                    .fillMaxWidth()
                    .heightIn(min = TriGeo.tapTarget),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    races.firstOrNull { it.id == selectedId }?.let(::raceLabel) ?: "Choose a finish",
                    style = TriType.body,
                    color = colors.ink,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(TriSpace.x2))
                Icon(Icons.Filled.UnfoldMore, null, tint = colors.inkTertiary)
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }, containerColor = colors.surface) {
                races.forEach { race ->
                    DropdownMenuItem(
                        text = { Text(raceLabel(race), style = TriType.body, color = colors.ink) },
                        onClick = {
                            open = false
                            onSelect(race.id)
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun DeltaRow(delta: RaceBookLegDelta) {
    val colors = Tri.colors
    val change = if (delta.change == 0) "No change" else "${TimeFormat.hms(kotlin.math.abs(delta.change))} ${if (delta.improved) "faster" else "slower"}"
    val tint = when {
        delta.change < 0 -> colors.positive
        delta.change > 0 -> colors.negative
        else -> colors.inkSecondary
    }
    Row(
        Modifier.heightIn(min = TriGeo.tapTarget).padding(vertical = TriSpace.x1)
            .semantics(mergeDescendants = true) { contentDescription = "${delta.discipline.title}, $change" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Icon(delta.discipline.icon, null, tint = colors.color(delta.discipline), modifier = Modifier.width(TriSpace.x8).size(22.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(delta.discipline.title, style = TriType.bodyBold, color = colors.ink)
            Text(
                "${TimeFormat.hms(delta.earlierSeconds)}  to  ${TimeFormat.hms(delta.laterSeconds)}",
                style = TriType.small.copy(fontFeatureSettings = "tnum"),
                color = colors.inkTertiary,
            )
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(change, style = TriType.statSmall, color = tint)
            Text(
                if (delta.change == 0) "No change" else if (delta.improved) "Faster" else "Slower",
                style = TriType.micro,
                color = colors.inkTertiary,
            )
        }
    }
}
