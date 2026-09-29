package com.jackwallner.ironsplits.ui.screens

import android.text.format.Formatter
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.PersonAddAlt1
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.BuildConfig
import com.jackwallner.ironsplits.data.AppearancePreference
import com.jackwallner.ironsplits.data.IronSplitsLegal
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.PaywallTrigger
import com.jackwallner.ironsplits.model.RaceDate
import com.jackwallner.ironsplits.model.UnitPreference
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.openExternal
import com.jackwallner.ironsplits.ui.openUrl
import com.jackwallner.ironsplits.ui.shareText
import com.jackwallner.ironsplits.ui.theme.GroupFootnote
import com.jackwallner.ironsplits.ui.theme.GroupHeader
import com.jackwallner.ironsplits.ui.theme.GroupRow
import com.jackwallner.ironsplits.ui.theme.Haptics
import com.jackwallner.ironsplits.ui.theme.InsetGroup
import com.jackwallner.ironsplits.ui.theme.SegmentedControl
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriAlert
import com.jackwallner.ironsplits.ui.theme.TriDivider
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriSwitch
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen() {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val colors = Tri.colors
    val scope = rememberCoroutineScope()
    val locker by graph.locker.state.collectAsState()
    val settings by graph.settings.state.collectAsState()
    val store by graph.store.state.collectAsState()
    val notes by graph.notes.notes.collectAsState()
    val pattieEnabled by graph.pattie.enabled.collectAsState()
    val cacheVersion by graph.mediaCache.version.collectAsState()
    var cacheBytes by remember { mutableLongStateOf(0L) }
    var showingAthleteSearch by remember { mutableStateOf(false) }
    var showingAlternateSearch by remember { mutableStateOf(false) }
    var confirmingUnclaim by remember { mutableStateOf(false) }
    var paywall by remember { mutableStateOf<PaywallTrigger?>(null) }
    var unitsMenu by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { graph.pattie.fire(PattieMode.Moment.SETTINGS) }
    LaunchedEffect(cacheVersion) { cacheBytes = graph.mediaCache.cacheSize() }

    val exportableNotes = remember(locker.results, notes) {
        val records = locker.results.mapNotNull { result -> notes[result.id]?.takeIf { !it.isEmpty }?.let { result to it } }
        if (records.isEmpty()) null else buildString {
            append("IM Tri Tracker race notes\n\n")
            records.forEach { (result, note) ->
                append("${RaceDate.text(result)} · ${result.raceName}\n")
                note.fields.forEach { (label, value) -> value.trim().takeIf { it.isNotEmpty() }?.let { append("$label: $it\n") } }
                append("\n")
            }
        }.trimEnd('\n')
    }

    TriScreen(title = "Settings") {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottomContentPadding(TriSpace.x6))) {
            GroupHeader("Athlete")
            InsetGroup {
                locker.athlete?.let { athlete ->
                    GroupRow(showDivider = true) {
                        Column(verticalArrangement = Arrangement.spacedBy(TriSpace.x1)) {
                            Text(athlete.name, style = TriType.bodyBold, color = colors.ink)
                            if (athlete.subtitle.isNotEmpty()) Text(athlete.subtitle, style = TriType.small, color = colors.inkTertiary)
                        }
                    }
                }
                SettingsActionRow("Change athlete", divider = true) {
                    graph.pattie.react(PattieMode.Action.SELECTION)
                    showingAthleteSearch = true
                }
                SettingsActionRow("Find another registered name", icon = Icons.Filled.PersonAddAlt1, divider = false) {
                    graph.pattie.react(PattieMode.Action.SELECTION)
                    showingAlternateSearch = true
                }
                GroupFootnote("If one race was entered under a different name, search the official results database and add that registration to this profile.")
                TriDivider(Modifier.padding(start = TriGeo.padPage))
                SettingsActionRow("Refresh results", divider = true) {
                    graph.pattie.react(PattieMode.Action.REFRESH)
                    graph.locker.refresh(force = true)
                }
                SettingsActionRow("Remove my athlete", color = colors.negative) {
                    graph.pattie.react(PattieMode.Action.CHOICE)
                    confirmingUnclaim = true
                }
            }

            GroupHeader("Units")
            InsetGroup {
                Box {
                    GroupRow(onClick = { unitsMenu = true }) {
                        Text("Distance and pace", style = TriType.body, color = colors.ink, modifier = Modifier.weight(1f))
                        Text(settings.units.title, style = TriType.body, color = colors.inkTertiary)
                        Spacer(Modifier.width(TriSpace.x1))
                        Icon(Icons.Filled.UnfoldMore, null, tint = colors.inkTertiary, modifier = Modifier.size(16.dp))
                    }
                    DropdownMenu(expanded = unitsMenu, onDismissRequest = { unitsMenu = false }, containerColor = colors.surface) {
                        UnitPreference.entries.forEach { unit ->
                            DropdownMenuItem(text = { Text(unit.title, color = colors.ink) }, onClick = {
                                unitsMenu = false
                                if (graph.settings.units != unit) {
                                    graph.settings.units = unit
                                    graph.pattie.react(PattieMode.Action.SELECTION)
                                }
                            })
                        }
                    }
                }
            }

            GroupHeader("Race notes")
            InsetGroup {
                if (exportableNotes != null) {
                    SettingsActionRow("Export my race notes", icon = Icons.Filled.IosShare) {
                        context.shareText(exportableNotes, "IM Tri Tracker race notes")
                    }
                    GroupFootnote("Creates a text copy you can save or share. Notes stay on this phone unless you choose a destination.")
                } else {
                    GroupRow {
                        Text("Notes you add to race details will appear here for export.", style = TriType.small, color = colors.inkTertiary)
                    }
                }
            }

            GroupHeader("Appearance")
            InsetGroup {
                Box(Modifier.padding(horizontal = TriGeo.padPage, vertical = TriSpace.x3)) {
                    SegmentedControl(
                        options = AppearancePreference.entries,
                        selected = settings.appearance,
                        label = { it.title },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        graph.settings.appearance = it
                        graph.pattie.react(PattieMode.Action.SELECTION)
                    }
                }
            }

            GroupHeader("Interaction")
            InsetGroup {
                val setHaptics: (Boolean) -> Unit = {
                    graph.settings.hapticsEnabled = it
                    Haptics.enabled = it
                    if (it) Haptics.selection()
                }
                GroupRow(showDivider = true, onClick = { setHaptics(!settings.hapticsEnabled) }) {
                    Text("Haptics", style = TriType.body, color = colors.ink, modifier = Modifier.weight(1f))
                    TriSwitch(settings.hapticsEnabled, setHaptics, label = "Haptics")
                }
                GroupFootnote("Subtle taps and selection feedback throughout the app.")
            }

            GroupHeader("Race Book")
            InsetGroup {
                GroupRow(showDivider = true) {
                    Icon(
                        if (store.isPro) Icons.Filled.Verified else Icons.AutoMirrored.Filled.MenuBook,
                        null,
                        tint = if (store.isPro) colors.positive else colors.sunrise,
                        modifier = Modifier.size(22.dp),
                    )
                    Spacer(Modifier.width(TriSpace.x4))
                    Text(
                        if (store.isPro) "Race Book is unlocked" else "Unlock Race Book once",
                        style = TriType.body,
                        color = if (store.isPro) colors.positive else colors.sunrise,
                    )
                }
                GroupFootnote(
                    if (store.isPro) "Your comparison and unlimited export tools are ready."
                    else "Your complete results, splits, rankings and race details are free. Race Book adds like-for-like comparisons and beautiful unlimited PDF or image exports for one lifetime purchase.",
                )
                TriDivider(Modifier.padding(start = TriGeo.padPage))
                if (!store.isPro) SettingsActionRow("See Race Book", divider = true) { paywall = PaywallTrigger.RACE_BOOK_EXPORT }
                SettingsActionRow("Restore purchases") { scope.launch { graph.store.restorePurchases() } }
                store.restoreError?.let { GroupFootnote(it, color = colors.negative) }
                if (!store.isPro) GroupFootnote("Restore a purchase on a new device or after reinstalling.")
            }

            GroupHeader("Pattie Mode")
            InsetGroup {
                val setPattie: (Boolean) -> Unit = {
                    graph.pattie.isEnabled = it
                    Haptics.selection()
                    if (it) graph.pattie.demo()
                }
                GroupRow(showDivider = true, onClick = { setPattie(!pattieEnabled) }) {
                    Text("Pattie Mode", style = TriType.body, color = colors.ink, modifier = Modifier.weight(1f))
                    TriSwitch(pattieEnabled, setPattie, label = "Pattie Mode")
                }
                if (pattieEnabled) SettingsActionRow("Show me one now", divider = true) { graph.pattie.demo() }
                GroupFootnote("Pattie Mode keeps a small Pattie pet in the corner and brings up useful tips from her own recordings as you explore. Turn Pattie Mode off any time to hide her and stop her voice.")
            }

            GroupHeader("Downloads")
            InsetGroup {
                GroupRow(showDivider = true) {
                    Text("Saved episodes", style = TriType.body, color = colors.ink, modifier = Modifier.weight(1f))
                    Text(if (cacheBytes == 0L) "None" else Formatter.formatShortFileSize(context, cacheBytes), style = TriType.body, color = colors.inkTertiary)
                }
                SettingsActionRow("Clear downloaded episodes", color = if (cacheBytes == 0L) colors.inkTertiary else colors.negative, enabled = cacheBytes > 0, divider = true) {
                    scope.launch {
                        graph.mediaCache.clear()
                        Haptics.success()
                    }
                }
                GroupFootnote("Episodes are saved the first time you watch them so they play offline. Clearing them just means the next play downloads again.")
            }

            Spacer(Modifier.padding(top = TriSpace.x6))
            InsetGroup {
                GroupFootnote(
                    "IM Tri Tracker is an independent app. It is not affiliated with, endorsed by, or sponsored by any race organiser. Results are shown as published by each event's timer. IRONMAN® and 70.3® are registered trademarks of the World Triathlon Corporation, used here only to describe the races an athlete has entered.",
                    modifier = Modifier.padding(vertical = TriSpace.x1),
                )
            }

            GroupHeader("About")
            InsetGroup {
                SettingsActionRow("Rate or send feedback", divider = true) { graph.review.requestEnjoymentPrompt() }
                SettingsActionRow("Write a review on Google Play", divider = true) {
                    if (!context.openExternal("market://details?id=${context.packageName}")) context.openUrl(IronSplitsLegal.PLAY_LISTING_URL)
                }
                SettingsActionRow("Privacy policy", divider = true) { context.openUrl(IronSplitsLegal.PRIVACY_URL) }
                SettingsActionRow("Terms of use", divider = true) { context.openUrl(IronSplitsLegal.TERMS_URL) }
                GroupRow {
                    Text("Version", style = TriType.body, color = colors.ink, modifier = Modifier.weight(1f))
                    Text("${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", style = TriType.body, color = colors.inkTertiary)
                }
            }
            if (BuildConfig.DEBUG) {
                GroupHeader("Debug")
                InsetGroup {
                    GroupRow(showDivider = true) {
                        Text("Race Book access", style = TriType.body, color = colors.ink, modifier = Modifier.weight(1f))
                        Text(if (store.isPro) "Yes" else "No", style = TriType.body, color = colors.inkTertiary)
                    }
                    GroupFootnote("The free core never hides results. The Race Book gate only protects comparison and export actions.")
                }
            }
        }
    }

    TriSheet(visible = showingAthleteSearch, onDismiss = { showingAthleteSearch = false }) {
        AthleteSearchScreen(SearchPurpose.CHANGE, onClose = { showingAthleteSearch = false })
    }
    TriSheet(visible = showingAlternateSearch, onDismiss = { showingAlternateSearch = false }) {
        AthleteSearchScreen(SearchPurpose.ADD_REGISTRATION, onClose = { showingAlternateSearch = false })
    }
    PaywallSheet(paywall) { paywall = null }
    if (confirmingUnclaim) {
        TriAlert(
            title = "Remove your athlete?",
            message = "Your cached results are deleted from this phone. Your race notes are kept, and reappear if you claim the same athlete again.",
            confirmTitle = "Remove",
            destructive = true,
            onConfirm = {
                confirmingUnclaim = false
                graph.locker.unclaim()
            },
            onDismiss = { confirmingUnclaim = false },
        )
    }
}

@Composable
private fun SettingsActionRow(
    title: String,
    icon: ImageVector? = null,
    color: Color = Tri.colors.sunrise,
    enabled: Boolean = true,
    divider: Boolean = false,
    onClick: () -> Unit,
) {
    GroupRow(showDivider = divider, onClick = if (enabled) onClick else null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) {
                Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(TriSpace.x3))
            }
            Text(title, style = TriType.body, color = color)
        }
    }
}
