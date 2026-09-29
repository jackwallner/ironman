package com.jackwallner.ironsplits.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CompareArrows
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.FindInPage
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.PaywallTrigger
import com.jackwallner.ironsplits.data.RaceBookExporter
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.PersonalBest
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceBookAnalytics
import com.jackwallner.ironsplits.model.RaceBookOptions
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.TimeFormat
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.components.SmallSpinner
import com.jackwallner.ironsplits.ui.components.icon
import com.jackwallner.ironsplits.ui.nav.LocalNavigator
import com.jackwallner.ironsplits.ui.nav.Route
import com.jackwallner.ironsplits.ui.shareFile
import com.jackwallner.ironsplits.ui.theme.ChipRow
import com.jackwallner.ironsplits.ui.theme.Haptics
import com.jackwallner.ironsplits.ui.theme.IconCircle
import com.jackwallner.ironsplits.ui.theme.StatTile
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriCardColumn
import com.jackwallner.ironsplits.ui.theme.TriChip
import com.jackwallner.ironsplits.ui.theme.TriDivider
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriPlaceholder
import com.jackwallner.ironsplits.ui.theme.TriPrimaryButton
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSectionHeader
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriSwitch
import com.jackwallner.ironsplits.ui.theme.TriTextButton
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import com.jackwallner.ironsplits.ui.theme.triPress
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The Race Book: a free preview of bests and progression, with comparison
 * and export behind the one lifetime unlock.
 */
@Composable
fun RaceBookScreen() {
    val graph = LocalGraph.current
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val colors = Tri.colors
    val scope = rememberCoroutineScope()
    val locker by graph.locker.state.collectAsState()
    val store by graph.store.state.collectAsState()
    val notes by graph.notes.notes.collectAsState()
    val settings by graph.settings.state.collectAsState()
    val results = locker.results
    val availableKinds = locker.availableKinds
    val unlocked = store.isPro

    var selectedKind by rememberSaveable { mutableStateOf<RaceKind?>(null) }
    var customizing by rememberSaveable { mutableStateOf(false) }
    var discipline by rememberSaveable { mutableStateOf(Discipline.FINISH) }
    var progressionRace by rememberSaveable { mutableStateOf<String?>(null) }
    var showAllProgression by rememberSaveable { mutableStateOf(false) }
    var options by remember { mutableStateOf(RaceBookOptions()) }
    var optionsInitialized by remember { mutableStateOf(false) }
    var paywall by remember { mutableStateOf<PaywallTrigger?>(null) }
    var building by remember { mutableStateOf(false) }
    var generation by remember { mutableIntStateOf(0) }
    var pdf by remember { mutableStateOf<File?>(null) }
    var image by remember { mutableStateOf<File?>(null) }
    var exportError by remember { mutableStateOf<String?>(null) }
    var previewing by remember { mutableStateOf(false) }
    var raceMenuOpen by remember { mutableStateOf(false) }

    fun invalidateExports() {
        generation++
        building = false
        pdf?.delete()
        image?.delete()
        pdf = null
        image = null
        exportError = null
    }

    LaunchedEffect(Unit) { graph.pattie.fire(PattieMode.Moment.RESUME) }
    LaunchedEffect(availableKinds) {
        if (availableKinds.isEmpty()) {
            selectedKind = null
        } else if (selectedKind !in availableKinds) {
            selectedKind = settings.preferredKind?.takeIf { it in availableKinds } ?: availableKinds.first()
            graph.settings.preferredKind = selectedKind
        }
        val available = availableKinds.toSet()
        if (available.isNotEmpty()) {
            options = if (!optionsInitialized) {
                optionsInitialized = true
                options.copy(kinds = available)
            } else {
                val kept = options.kinds.intersect(available)
                options.copy(kinds = kept.ifEmpty { available })
            }
        }
    }
    LaunchedEffect(results, notes) { invalidateExports() }

    val activeKind = selectedKind ?: availableKinds.firstOrNull()
    val comparable = remember(results, activeKind) { RaceBookAnalytics.comparableRaces(results, activeKind) }
    val bests = remember(results, activeKind) { activeKind?.let { RaceBookAnalytics.bests(results, it) }.orEmpty() }
    val progression = remember(results, discipline, activeKind) {
        activeKind?.let { RaceBookAnalytics.progression(results, discipline, it) }.orEmpty()
    }
    val repeatedCourses = remember(progression) {
        progression.groupBy { it.result.raceName }.filterValues { it.size > 1 }.keys.sorted()
    }
    val points = progressionRace?.let { name -> progression.filter { it.result.raceName == name } } ?: progression
    val visiblePoints = if (showAllProgression || progressionRace != null) points else points.takeLast(4)

    fun buildExports() {
        val athlete = locker.athlete ?: return
        if (building) return
        Haptics.medium()
        pdf?.delete()
        image?.delete()
        pdf = null
        image = null
        building = true
        generation++
        val gen = generation
        val snapshotResults = results
        val snapshotNotes = notes
        val snapshotOptions = options
        scope.launch {
            val built = withContext(Dispatchers.Default) {
                RaceBookExporter.pdf(context, athlete, snapshotResults, snapshotNotes, snapshotOptions) to
                    RaceBookExporter.image(context, athlete, snapshotResults, snapshotOptions)
            }
            if (gen != generation) return@launch
            pdf = built.first
            image = built.second
            exportError = if (built.first == null && built.second == null) {
                "The export could not be created. Check available storage and try again."
            } else {
                null
            }
            building = false
            graph.pattie.fire(PattieMode.Moment.RESUME_EXPORTED)
            if (built.first != null || built.second != null) Haptics.success()
        }
    }

    TriScreen(title = "Race Book") {
        if (results.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                TriPlaceholder(
                    Icons.AutoMirrored.Filled.MenuBook,
                    "Your Race Book is waiting",
                    message = "Claim an athlete to preview personal bests, progression, comparison and export tools.",
                )
            }
            return@TriScreen
        }
        Column(
            Modifier.fillMaxSize().testTag("race-book").verticalScroll(rememberScrollState())
                .padding(horizontal = TriGeo.padPage).padding(top = TriSpace.x4).padding(bottomContentPadding()),
            verticalArrangement = Arrangement.spacedBy(TriSpace.x6),
        ) {
            TriCardColumn(spacing = TriSpace.x2) {
                Row(horizontalArrangement = Arrangement.spacedBy(TriSpace.x3), verticalAlignment = Alignment.Top) {
                    IconCircle(Icons.AutoMirrored.Filled.MenuBook, colors.sunrise)
                    Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                        Text("RACE BOOK", style = TriType.micro.copy(letterSpacing = 1.2.sp), color = colors.sunrise)
                        Text("Make your history tell a story", style = TriType.pageTitle, color = colors.ink)
                    }
                }
                Text(
                    "See the best of your career, where your time is moving, and what each race contributed. Compare and export with one lifetime unlock.",
                    style = TriType.body,
                    color = colors.inkSecondary,
                )
                Text(
                    if (unlocked) "Race Book unlocked" else "Preview included. No subscription.",
                    style = TriType.smallBold,
                    color = if (unlocked) colors.positive else colors.inkTertiary,
                )
            }

            val summary = remember(results) { RaceAnalytics.summary(results) }
            TriCardColumn(padding = TriSpace.x3) {
                TriSectionHeader("Career at a glance")
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    StatTile("${summary.finishes}", "Finishes")
                    StatTile("${summary.podiums}", "Podiums", colors.sunrise)
                    StatTile("${summary.starts}", "Starts")
                }
                summary.years?.let { years ->
                    Text(
                        if (years.first == years.last) "${years.first}" else "${years.first} to ${years.last}",
                        style = TriType.small,
                        color = colors.inkTertiary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            if (availableKinds.size > 1) {
                Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                    TriSectionHeader("Compare by distance")
                    ChipRow {
                        availableKinds.forEach { kind ->
                            TriChip(kind.longTitle, activeKind == kind) {
                                selectedKind = kind
                                graph.settings.preferredKind = kind
                                discipline = Discipline.FINISH
                                progressionRace = null
                                showAllProgression = false
                                invalidateExports()
                                graph.pattie.react(PattieMode.Action.FILTER)
                            }
                        }
                    }
                }
            }

            TriCardColumn(padding = TriSpace.x3) {
                TriSectionHeader("Personal bests", trailing = activeKind?.longTitle)
                if (bests.isEmpty()) {
                    Text("No complete splits are available for this distance yet.", style = TriType.small, color = colors.inkTertiary)
                } else {
                    bests.forEach { best ->
                        BestRow(best) { navigator.push(Route.RaceDetail(best.result)) }
                    }
                }
            }

            TriCardColumn(padding = TriSpace.x3) {
                TriSectionHeader("Progression", trailing = activeKind?.longTitle)
                ChipRow {
                    Discipline.rankable.forEach { d ->
                        TriChip(d.shortTitle, discipline == d) {
                            discipline = d
                            graph.pattie.react(PattieMode.Action.FILTER)
                        }
                    }
                }
                if (repeatedCourses.isNotEmpty()) {
                    Box {
                        TriTextButton(
                            progressionRace ?: "All courses",
                            style = TriType.smallBold,
                            icon = Icons.Filled.FilterList,
                            modifier = Modifier.semantics { contentDescription = "Progression race filter" },
                        ) { raceMenuOpen = true }
                        DropdownMenu(expanded = raceMenuOpen, onDismissRequest = { raceMenuOpen = false }, containerColor = colors.surface) {
                            DropdownMenuItem(text = { Text("All courses", color = colors.ink) }, onClick = {
                                progressionRace = null
                                raceMenuOpen = false
                            })
                            repeatedCourses.forEach { name ->
                                DropdownMenuItem(text = { Text(name, color = colors.ink) }, onClick = {
                                    progressionRace = name
                                    raceMenuOpen = false
                                })
                            }
                        }
                    }
                }
                if (points.size > 1) {
                    Text(
                        when {
                            progressionRace != null -> "Same event, oldest to newest."
                            repeatedCourses.isEmpty() -> "Courses vary. A like-for-like event comparison will appear after another finish at the same race."
                            else -> "Courses vary. Choose a repeat event above for a like-for-like view."
                        },
                        style = TriType.micro,
                        color = colors.inkTertiary,
                    )
                    Column {
                        visiblePoints.forEachIndexed { index, point ->
                            Row(Modifier.heightIn(min = TriGeo.tapTarget), verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    if (point.result.year > 0) "${point.result.year}" else "--",
                                    style = TriType.statSmall,
                                    color = colors.inkSecondary,
                                    modifier = Modifier.widthIn(min = TriSpace.x10),
                                )
                                Spacer(Modifier.width(TriSpace.x3))
                                Text(point.result.raceName, style = TriType.small, color = colors.ink, maxLines = 2, modifier = Modifier.weight(1f))
                                Spacer(Modifier.width(TriSpace.x2))
                                Text(TimeFormat.hms(point.seconds), style = TriType.statMed, color = colors.ink)
                            }
                            if (index < visiblePoints.lastIndex) TriDivider()
                        }
                    }
                    if (points.size > 4) {
                        TriTextButton(
                            if (showAllProgression) "Show fewer races" else "Show all ${points.size} races",
                            style = TriType.smallBold,
                        ) { showAllProgression = !showAllProgression }
                    }
                } else {
                    Text("Add another complete race at this distance to see progression over time.", style = TriType.small, color = colors.inkTertiary)
                }
            }

            TriCardColumn(padding = TriSpace.x3) {
                TriSectionHeader("Compare races")
                Text(
                    if (comparable.size >= 2) "Put two ${activeKind?.longTitle?.lowercase() ?: "like-for-like"} finishes side by side and see every leg's gain or loss."
                    else "You need two complete races at the same distance before comparison is available.",
                    style = TriType.body,
                    color = colors.inkSecondary,
                )
                if (comparable.size >= 2) {
                    if (unlocked) {
                        ActionRow("Compare two races", "Time gained or lost by leg", Icons.AutoMirrored.Filled.CompareArrows) {
                            navigator.push(Route.RaceCompare(activeKind))
                        }
                    } else {
                        ActionRow("Unlock race comparison", "One lifetime purchase, no subscription", Icons.Filled.Lock) {
                            paywall = PaywallTrigger.RACE_BOOK_COMPARE
                        }
                    }
                }
            }

            TriCardColumn(padding = TriSpace.x3) {
                TriSectionHeader("Build your Race Book")
                Text(
                    "Build a polished full report or one-page PDF, plus a tall shareable image. Everything is generated on this phone.",
                    style = TriType.body,
                    color = colors.inkSecondary,
                )
                TriPrimaryButton(
                    title = if (unlocked) (if (exportError == null) "Build PDF and image" else "Try export again") else "Unlock to export",
                    icon = if (unlocked) Icons.Filled.IosShare else Icons.Filled.Lock,
                    isBusy = building,
                    modifier = Modifier.testTag("race-book-export"),
                ) {
                    if (unlocked) buildExports() else paywall = PaywallTrigger.RACE_BOOK_EXPORT
                }
                if (building) {
                    Row(
                        Modifier.heightIn(min = TriGeo.tapTarget).semantics(mergeDescendants = true) {},
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(TriSpace.x2),
                    ) {
                        SmallSpinner()
                        Text("Building both files on this phone...", style = TriType.small, color = colors.inkSecondary)
                    }
                }
                exportError?.let { error ->
                    Row(horizontalArrangement = Arrangement.spacedBy(TriSpace.x2)) {
                        Icon(Icons.Filled.Warning, null, tint = colors.negative, modifier = Modifier.size(16.dp))
                        Text(error, style = TriType.small, color = colors.negative)
                    }
                }
                pdf?.let { file ->
                    ActionRow("View PDF", "Read it here before sharing", Icons.Filled.FindInPage) { previewing = true }
                    TriTextButton("Share PDF", icon = Icons.Filled.Description, modifier = Modifier.fillMaxWidth()) {
                        context.shareFile(file, "application/pdf", "Share your Race Book")
                        graph.pattie.react(PattieMode.Action.EXPORT)
                    }
                }
                image?.let { file ->
                    TriTextButton("Share image", icon = Icons.Filled.Photo, modifier = Modifier.fillMaxWidth()) {
                        context.shareFile(file, "image/png", "Share your Race Book")
                        graph.pattie.react(PattieMode.Action.EXPORT)
                    }
                }
                Text(
                    if (unlocked) "Unlimited exports are included with Race Book." else "Your results remain free. Compare and export are the only Race Book actions.",
                    style = TriType.micro,
                    color = colors.inkTertiary,
                )
            }

            if (unlocked) {
                Row(
                    Modifier
                        .semantics { stateDescription = if (customizing) "Expanded" else "Collapsed" }
                        .triPress(haptic = false) {
                            Haptics.selection()
                            customizing = !customizing
                        }
                        .fillMaxWidth()
                        .heightIn(min = TriGeo.tapTarget),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Customize export", style = TriType.bodyBold, color = colors.ink, modifier = Modifier.weight(1f))
                    Icon(
                        if (customizing) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
                        null,
                        tint = colors.inkSecondary,
                    )
                }
                AnimatedVisibility(customizing, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                    IncludeCard(options, availableKinds) { next ->
                        if (next != options) {
                            options = next
                            invalidateExports()
                        }
                    }
                }
            }
            Text(
                "Official times are shown as published by the event timer. Race notes stay on this phone and are included only when you choose to export.",
                style = TriType.micro,
                color = colors.inkTertiary,
                modifier = Modifier.padding(horizontal = TriSpace.x1),
            )
        }
    }

    PaywallSheet(paywall) { paywall = null }
    RaceBookPdfPreviewSheet(visible = previewing, file = pdf) { previewing = false }
}

@Composable
private fun IncludeCard(options: RaceBookOptions, availableKinds: List<RaceKind>, onChange: (RaceBookOptions) -> Unit) {
    val graph = LocalGraph.current
    TriCardColumn(padding = TriSpace.x3) {
        TriSectionHeader("Things to include")
        Text(
            "Shape the book around the parts of your career you will want on race morning and after the finish.",
            style = TriType.small,
            color = Tri.colors.inkTertiary,
        )
        Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            OptionToggle("Career overview", "Starts, finishes, podiums and years", options.includeCareerSummary) { onChange(options.copy(includeCareerSummary = it)) }
            OptionToggle("Podium highlights", "Your top-three race moments", options.includePodiumHighlights) { onChange(options.copy(includePodiumHighlights = it)) }
            OptionToggle("Personal bests", "Fastest finish and leg at each distance", options.includePersonalBests) { onChange(options.copy(includePersonalBests = it)) }
            OptionToggle("Progression", "First and latest finish by distance", options.includeProgression) { onChange(options.copy(includeProgression = it)) }
            OptionToggle("Race history", "A complete timeline of selected races", options.includeRaceHistory) { onChange(options.copy(includeRaceHistory = it)) }
            OptionToggle("Official splits", "Swim, T1, bike, T2 and run", options.includeSplits) { onChange(options.copy(includeSplits = it)) }
            OptionToggle("Placements", "Bib, age group and overall rank", options.includePlacements) { onChange(options.copy(includePlacements = it)) }
            OptionToggle("Race-day notes", "Optional in the PDF; never added to the share image", options.includeRaceNotes) { onChange(options.copy(includeRaceNotes = it)) }
            OptionToggle("Incomplete results", "Include DNF, DNS and DQ entries", options.includeIncomplete) { onChange(options.copy(includeIncomplete = it)) }
            TriDivider()
            OptionToggle("One-page PDF", "A condensed summary for quick sharing", options.onePage) { onChange(options.copy(onePage = it)) }
        }
        if (availableKinds.size > 1) {
            TriSectionHeader("Distances")
            ChipRow {
                availableKinds.forEach { kind ->
                    TriChip(kind.longTitle, kind in options.kinds) {
                        val kinds = options.kinds
                        if (kind in kinds) {
                            if (kinds.size > 1) onChange(options.copy(kinds = kinds - kind))
                        } else {
                            onChange(options.copy(kinds = kinds + kind))
                        }
                        graph.pattie.react(PattieMode.Action.SELECTION)
                    }
                }
            }
        }
    }
}

@Composable
private fun OptionToggle(title: String, detail: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = TriGeo.tapTarget).triPress(haptic = false) { onChange(!checked) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(title, style = TriType.bodyBold, color = colors.ink, maxLines = 1)
            Text(detail, style = TriType.small, color = colors.inkTertiary)
        }
        Spacer(Modifier.width(TriSpace.x2))
        TriSwitch(checked, onChange, label = title)
    }
}

@Composable
private fun BestRow(best: PersonalBest, onClick: () -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier
            .semantics(mergeDescendants = true) {
                contentDescription = "Personal best, ${best.discipline.title}, ${TimeFormat.spoken(best.seconds)}, ${best.result.raceName}"
            }
            .triPress(onClick = onClick)
            .fillMaxWidth()
            .heightIn(min = TriGeo.tapTarget)
            .padding(vertical = TriSpace.x1),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Box(Modifier.width(TriSpace.x8).heightIn(min = TriGeo.tapTarget), contentAlignment = Alignment.Center) {
            Icon(best.discipline.icon, null, tint = colors.color(best.discipline), modifier = Modifier.size(22.dp))
        }
        Column(Modifier.weight(1f).padding(top = TriSpace.x1), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(best.discipline.title, style = TriType.bodyBold, color = colors.ink)
            Text(best.result.raceName, style = TriType.small, color = colors.inkTertiary)
        }
        Text(TimeFormat.hms(best.seconds), style = TriType.statMed, color = colors.ink, modifier = Modifier.padding(top = TriSpace.x1))
    }
}

@Composable
fun ActionRow(title: String, subtitle: String, icon: ImageVector, onClick: () -> Unit) {
    val colors = Tri.colors
    Row(
        Modifier
            .semantics(mergeDescendants = true) { contentDescription = "$title. $subtitle" }
            .triPress(onClick = onClick)
            .fillMaxWidth()
            .heightIn(min = TriGeo.tapTarget)
            .padding(vertical = TriSpace.x1),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Icon(icon, null, tint = colors.sunrise, modifier = Modifier.width(TriSpace.x8).size(22.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
            Text(title, style = TriType.bodyBold, color = colors.ink)
            Text(subtitle, style = TriType.small, color = colors.inkTertiary)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
    }
}
