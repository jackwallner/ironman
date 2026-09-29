package com.jackwallner.ironsplits.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.AppGraph
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.RaceNote
import com.jackwallner.ironsplits.data.isCancellation
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.FieldPlacement
import com.jackwallner.ironsplits.model.Ordinal
import com.jackwallner.ironsplits.model.PaceFormat
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceDate
import com.jackwallner.ironsplits.model.RaceResult
import com.jackwallner.ironsplits.model.TimeFormat
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.PercentileBar
import com.jackwallner.ironsplits.ui.components.SmallSpinner
import com.jackwallner.ironsplits.ui.components.SplitBar
import com.jackwallner.ironsplits.ui.components.icon
import com.jackwallner.ironsplits.ui.nav.LocalNavigator
import com.jackwallner.ironsplits.ui.nav.ScreenModel
import com.jackwallner.ironsplits.ui.nav.rememberRetained
import com.jackwallner.ironsplits.ui.theme.ChipRow
import com.jackwallner.ironsplits.ui.theme.Haptics
import com.jackwallner.ironsplits.ui.theme.StatTile
import com.jackwallner.ironsplits.ui.theme.TitleAlignment
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriBadge
import com.jackwallner.ironsplits.ui.theme.TriCardColumn
import com.jackwallner.ironsplits.ui.theme.TriChip
import com.jackwallner.ironsplits.ui.theme.TriDivider
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSectionHeader
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriTextButton
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import kotlinx.coroutines.launch

private enum class FieldState { IDLE, LOADING, LOADED, FAILED, UNAVAILABLE }

private enum class FieldScope(val title: String) { DIVISION("Division"), GENDER("Gender"), OVERALL("Overall") }

private class RaceDetailModel(private val graph: AppGraph, private val result: RaceResult) : ScreenModel() {
    var field by mutableStateOf<List<RaceResult>>(emptyList())
    var fieldState by mutableStateOf(FieldState.IDLE)
    var fieldScope by mutableStateOf(FieldScope.OVERALL)
    private var started = false

    fun start() {
        if (started) return
        started = true
        load()
    }

    fun load() {
        if (fieldState == FieldState.LOADED || fieldState == FieldState.UNAVAILABLE) return
        if (result.eventId.isEmpty()) {
            fieldState = FieldState.UNAVAILABLE
            return
        }
        graph.fieldCache.results(result.eventId)?.let {
            field = it
            fieldState = FieldState.LOADED
            return
        }
        fieldState = FieldState.LOADING
        scope.launch {
            try {
                val loaded = graph.api.results(result.eventId)
                field = loaded
                graph.fieldCache.store(loaded, result.eventId)
                fieldState = FieldState.LOADED
            } catch (error: Throwable) {
                if (isCancellation(error)) throw error
                android.util.Log.w("IronSplits", "Field load failed for ${result.eventId}", error)
                fieldState = FieldState.FAILED
            }
        }
    }
}

/** One race in full: splits, ranks, where each leg landed in the field, and notes. */
@Composable
fun RaceDetailScreen(result: RaceResult, contextResults: List<RaceResult>? = null, isReadOnly: Boolean = false) {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val colors = Tri.colors
    val lockerState by graph.locker.state.collectAsState()
    val settings by graph.settings.state.collectAsState()
    val notesMap by graph.notes.notes.collectAsState()
    val career = contextResults ?: lockerState.results
    val model = rememberRetained("race-detail-${result.id}") { RaceDetailModel(graph, result) }
    var editingNote by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (graph.review.isPositiveMoment(result, isReadOnly, career)) graph.review.recordPositiveMoment(result.id)
        if (!isReadOnly) {
            val moment = when {
                !result.isComplete -> PattieMode.Moment.DID_NOT_FINISH
                result.raceName.contains("World Championship", ignoreCase = true) -> PattieMode.Moment.WORLD_CHAMPIONSHIP
                Discipline.rankable.any { RaceAnalytics.isPersonalBest(result, it, career) } -> PattieMode.Moment.PERSONAL_BEST
                else -> PattieMode.Moment.RACE_OPENED
            }
            graph.pattie.fire(moment)
        }
        if (result.isComplete) model.start()
    }
    DisposableEffect(Unit) { onDispose { if (navigator.lastWasPop) graph.pattie.react(PattieMode.Action.BACK) } }

    TriScreen(title = result.raceName, onBack = { navigator.pop() }, titleAlignment = TitleAlignment.START) {
        Column(
            Modifier.fillMaxSize().testTag("race-detail").verticalScroll(rememberScrollState()).padding(bottomContentPadding()),
            verticalArrangement = Arrangement.spacedBy(TriGeo.padSection),
        ) {
            Hero(result)
            SplitsCard(result, career, settings.units)
            if (result.isComplete) FieldCard(result, model)
            if (!isReadOnly) NotesCard(notesMap[result.id] ?: RaceNote(result.id)) {
                editingNote = true
            }
        }
    }

    RaceNoteEditorSheet(
        visible = editingNote,
        initial = notesMap[result.id] ?: RaceNote(result.id),
        raceName = result.raceName,
        onClose = { editingNote = false },
    ) { updated ->
        graph.notes.save(updated)
        Haptics.success()
        graph.pattie.fire(PattieMode.Moment.NOTE_SAVED)
    }
}

@Composable
private fun Hero(result: RaceResult) {
    val colors = Tri.colors
    val onDark = colors.inkOnDark
    Column(
        Modifier.fillMaxWidth().background(colors.deep).padding(horizontal = TriGeo.padCard, vertical = TriSpace.x5),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Text(result.raceName, style = TriType.pageTitle, color = onDark, textAlign = TextAlign.Center)
        Text(result.eventDate?.let(RaceDate::long) ?: result.year.toString(), style = TriType.small, color = onDark.copy(alpha = 0.7f))
        Text(
            if (result.isComplete) TimeFormat.hms(result.finish) else result.statusLabel.orEmpty(),
            style = TriType.statHero,
            color = if (result.isComplete) onDark else colors.sunrise,
        )
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
            val badge = onDark.copy(alpha = 0.85f)
            TriBadge(result.kind.longTitle, badge)
            result.ageGroup?.let { TriBadge(it, badge) }
            result.bib?.let { TriBadge("Bib $it", badge) }
        }
        if (result.isComplete) {
            val caption = onDark.copy(alpha = 0.6f)
            Row(Modifier.fillMaxWidth().padding(top = TriSpace.x1), horizontalArrangement = Arrangement.Center) {
                StatTile(Ordinal.text(result.finishRankGroup) ?: "--", "Division", onDark, caption)
                StatTile(Ordinal.text(result.finishRankGender) ?: "--", "Gender", onDark, caption)
                StatTile(Ordinal.text(result.finishRankOverall) ?: "--", "Overall", onDark, caption)
            }
        }
    }
}

@Composable
private fun SplitsCard(result: RaceResult, career: List<RaceResult>, units: com.jackwallner.ironsplits.model.UnitPreference) {
    TriCardColumn(Modifier.padding(horizontal = TriGeo.padPage)) {
        TriSectionHeader("Splits")
        if (result.isComplete) SplitBar(result, height = 12.dp)
        Column {
            Discipline.legs.forEachIndexed { index, leg ->
                val seconds = result.seconds(leg)
                SplitRow(
                    discipline = leg,
                    seconds = seconds,
                    pace = PaceFormat.text(leg, seconds, result.distanceKm(leg), units),
                    overallRank = result.overallRank(leg),
                    divisionRank = result.divisionRank(leg),
                    isPersonalBest = leg in Discipline.rankable && RaceAnalytics.isPersonalBest(result, leg, career),
                )
                if (index < Discipline.legs.lastIndex) TriDivider()
            }
        }
    }
}

@Composable
private fun SplitRow(discipline: Discipline, seconds: Int?, pace: String?, overallRank: Int?, divisionRank: Int?, isPersonalBest: Boolean) {
    val colors = Tri.colors
    val rankText = when {
        divisionRank != null -> "${Ordinal.text(divisionRank)} in division"
        overallRank != null -> "${Ordinal.text(overallRank)} overall"
        else -> null
    }
    val description = listOfNotNull(discipline.title, TimeFormat.spoken(seconds), rankText, if (isPersonalBest) "Personal best" else null)
        .joinToString(", ")
    Row(
        Modifier.fillMaxWidth().padding(vertical = TriSpace.x3).clearAndSetSemantics { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(discipline.icon, null, tint = colors.color(discipline), modifier = Modifier.width(24.dp).size(18.dp))
        Spacer(Modifier.width(TriSpace.x3))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                Text(discipline.title, style = TriType.bodyBold, color = colors.ink)
                if (isPersonalBest) TriBadge("PB", colors.sunrise, filled = true)
            }
            if (pace != null) Text(pace, style = TriType.small, color = colors.inkTertiary)
        }
        Spacer(Modifier.width(TriSpace.x2))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(TimeFormat.hms(seconds), style = TriType.statMed, color = colors.ink, maxLines = 1)
            if (rankText != null) Text(rankText, style = TriType.small, color = colors.inkTertiary)
        }
    }
}

@Composable
private fun FieldCard(result: RaceResult, model: RaceDetailModel) {
    val colors = Tri.colors
    val available = remember(result) {
        val group = result.ageGroup
        val prefix = group?.uppercase()?.firstOrNull()
        when {
            group == null -> listOf(FieldScope.OVERALL)
            prefix == 'M' || prefix == 'F' -> listOf(FieldScope.DIVISION, FieldScope.GENDER, FieldScope.OVERALL)
            else -> listOf(FieldScope.DIVISION, FieldScope.OVERALL)
        }
    }
    val scoped = remember(model.field, model.fieldScope) {
        val group = result.ageGroup
        when (model.fieldScope) {
            FieldScope.DIVISION -> if (group == null) model.field else model.field.filter { it.ageGroup.equals(group, ignoreCase = true) }
            FieldScope.GENDER -> {
                val prefix = group?.uppercase()?.firstOrNull()
                if (prefix != 'M' && prefix != 'F') model.field
                else model.field.filter { it.ageGroup?.uppercase()?.startsWith(prefix) == true }
            }
            FieldScope.OVERALL -> model.field
        }
    }
    val placements: List<FieldPlacement> = remember(scoped) {
        Discipline.rankable.mapNotNull { RaceAnalytics.placement(result, it, scoped) }
    }
    TriCardColumn(Modifier.padding(horizontal = TriGeo.padPage)) {
        TriSectionHeader(
            "Against the field",
            trailing = if (model.fieldState == FieldState.LOADED) "${scoped.count { it.isComplete }} finishers" else null,
        )
        when (model.fieldState) {
            FieldState.IDLE, FieldState.LOADING -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                SmallSpinner()
                Text("Loading the field…", style = TriType.small, color = colors.inkTertiary)
            }
            FieldState.FAILED -> TriTextButton("Couldn't load the field. Try again.", style = TriType.small) { model.load() }
            FieldState.UNAVAILABLE -> Text(
                "Field results aren't available for this race. Your published splits are still shown above.",
                style = TriType.small,
                color = colors.inkSecondary,
            )
            FieldState.LOADED -> Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x3)) {
                if (available.size > 1) {
                    ChipRow {
                        available.forEach { scope ->
                            TriChip(scope.title, model.fieldScope == scope) { model.fieldScope = scope }
                        }
                    }
                }
                if (placements.isEmpty()) {
                    Text(
                        if (model.fieldScope == FieldScope.OVERALL) "There isn't enough comparable field data for these splits."
                        else "No comparable finishers were found in this ${model.fieldScope.title.lowercase()}. Try Overall.",
                        style = TriType.small,
                        color = colors.inkSecondary,
                        modifier = Modifier.heightIn(min = TriGeo.tapTarget),
                    )
                } else {
                    placements.forEach { PlacementRow(it) }
                }
            }
        }
    }
}

@Composable
private fun PlacementRow(placement: FieldPlacement) {
    val colors = Tri.colors
    Column(
        Modifier.clearAndSetSemantics {
            contentDescription = "${placement.discipline.title}, ${placement.percentile} percent, ${placement.rank} of ${placement.fieldSize} finishers"
        },
        verticalArrangement = Arrangement.spacedBy(TriSpace.x1),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(placement.discipline.title, style = TriType.smallBold, color = colors.ink, modifier = Modifier.weight(1f))
            Text("${placement.rank} of ${placement.fieldSize}", style = TriType.small, color = colors.inkTertiary, maxLines = 1)
            Text(
                "${placement.percentile}%",
                style = TriType.statSmall,
                color = colors.percentileText(placement.percentile),
                textAlign = TextAlign.End,
                modifier = Modifier.widthIn(min = TriSpace.x10),
            )
        }
        PercentileBar(placement.percentile)
    }
}

@Composable
private fun NotesCard(note: RaceNote, onEdit: () -> Unit) {
    val colors = Tri.colors
    TriCardColumn(Modifier.padding(horizontal = TriGeo.padPage)) {
        TriSectionHeader("Race notes")
        if (note.isEmpty) {
            TriTextButton("Add notes for this race", icon = Icons.Filled.AddCircle, onClick = onEdit)
        } else {
            note.fields.forEach { (label, value) ->
                val trimmed = value.trim()
                if (trimmed.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                        Text(label.uppercase(), style = TriType.micro, color = colors.inkTertiary)
                        Text(trimmed, style = TriType.body, color = colors.ink)
                    }
                }
            }
            TriTextButton("Edit", style = TriType.smallBold, onClick = onEdit)
        }
    }
}
