package com.jackwallner.ironsplits.ui

import android.app.Activity
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.jackwallner.ironsplits.data.RaceAnalytics
import com.jackwallner.ironsplits.data.RaceBookExporter
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceResult
import java.io.File

private const val PRIVACY_URL = "https://jackwallner.github.io/ironman/privacy-policy.html"
private const val TERMS_URL = "https://jackwallner.github.io/ironman/terms/"

@Composable
fun RaceBookScreen(state: AppUiState, viewModel: IronSplitsViewModel) {
    LaunchedEffect(Unit) {
        viewModel.refreshEntitlement()
        viewModel.loadLifetimePrice()
    }
    if (!state.isPro) {
        RaceBookPaywall(state, viewModel)
    } else {
        RaceBookComparison(state, viewModel)
    }
}

@Composable
private fun RaceBookPaywall(state: AppUiState, viewModel: IronSplitsViewModel) {
    val context = LocalContext.current
    val activity = context as? Activity
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) {
        ScreenTitle("Race Book", "Compare your full- or half-distance races and share a polished report.")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(Space.cardRadius),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary),
        ) {
            Column(Modifier.fillMaxWidth().padding(Space.card), verticalArrangement = Arrangement.spacedBy(Space.row)) {
                Text("A closer look at your races", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onPrimary)
                Text(
                    "Compare like-for-like race splits, see where time changed, and export unlimited PDF or image reports.",
                    color = MaterialTheme.colorScheme.onPrimary,
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
        ContentCard {
            Text("One-time lifetime unlock", style = MaterialTheme.typography.titleLarge)
            Text(
                state.lifetimePrice ?: if (state.loadingPrice) "Loading regional price…" else "Price unavailable right now",
                style = MaterialTheme.typography.headlineMedium,
            )
            Text("A single purchase. No subscription or per-export charge.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Button(
                onClick = { activity?.let(viewModel::buyRaceBook) },
                enabled = activity != null && !state.isPurchasing && state.lifetimePrice != null,
                modifier = Modifier.fillMaxWidth().height(Space.tapTarget).testTag("buy-race-book"),
            ) {
                if (state.isPurchasing) CircularProgressIndicator()
                else Text(if (state.lifetimePrice == null) "Purchase unavailable" else "Unlock Race Book")
            }
            TextButton(onClick = viewModel::restorePurchases, modifier = Modifier.height(Space.tapTarget)) {
                Text("Restore Purchases")
            }
            state.paywallMessage?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
        ContentCard {
            Text("The rest stays free", style = MaterialTheme.typography.titleMedium)
            Text("Search and save supported results, view every split, rank races, add notes, and browse every pointer without paying.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        state.restoreMessage?.let { MessageBanner(it, viewModel::dismissMessage) }
        PolicyLinks()
    }
}

@Composable
private fun RaceBookComparison(state: AppUiState, viewModel: IronSplitsViewModel) {
    val context = LocalContext.current
    val exporter = remember(context) { RaceBookExporter(context) }
    val kinds = RaceAnalytics.availableKinds(state.lockerResults)
    val kind = state.selectedKind ?: kinds.firstOrNull()
    val races = RaceAnalytics.comparable(state.lockerResults, kind).sortedBy { it.eventDate.orEmpty() }
    var firstId by remember(races) { mutableStateOf(races.firstOrNull()?.id) }
    var secondId by remember(races) { mutableStateOf(races.lastOrNull()?.id?.takeIf { it != firstId }) }
    val first = races.firstOrNull { it.id == firstId }
    val second = races.firstOrNull { it.id == secondId }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) {
        ScreenTitle("Race Book", "Compare races at the same distance.")
        if (kind != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(Space.small)) {
                kinds.forEach { distance ->
                    androidx.compose.material3.FilterChip(
                        selected = kind == distance,
                        onClick = { viewModel.selectKind(distance) },
                        label = { Text(distance.label) },
                        modifier = Modifier.height(Space.tapTarget),
                    )
                }
            }
        }
        if (races.size < 2) {
            ContentCard {
                Text("Add another ${kind?.fullLabel?.lowercase() ?: "supported"} finish to compare races.", style = MaterialTheme.typography.titleMedium)
                Text("The Race Book compares matching distances only, so every split stays meaningful.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            return@Column
        }

        RaceSelector("First race", first, races.filterNot { it.id == secondId }) { firstId = it.id }
        RaceSelector("Second race", second, races.filterNot { it.id == firstId }) { secondId = it.id }

        if (first != null && second != null && first.id != second.id) {
            RaceComparison(first, second)
            Row(horizontalArrangement = Arrangement.spacedBy(Space.row)) {
                OutlinedButton(
                    onClick = { shareFile(context as? Activity, exporter.pdf(state.lockerAthlete?.name.orEmpty(), first, second), "application/pdf") },
                    modifier = Modifier.weight(1f).height(Space.tapTarget).testTag("export-pdf"),
                ) {
                    Icon(Icons.Default.Share, contentDescription = null)
                    Spacer(Modifier.width(Space.small))
                    Text("Share PDF")
                }
                OutlinedButton(
                    onClick = { shareFile(context as? Activity, exporter.image(state.lockerAthlete?.name.orEmpty(), first, second), "image/png") },
                    modifier = Modifier.weight(1f).height(Space.tapTarget).testTag("export-image"),
                ) {
                    Icon(Icons.Default.Share, contentDescription = null)
                    Spacer(Modifier.width(Space.small))
                    Text("Share image")
                }
            }
        }
        PolicyLinks()
    }
}

@Composable
private fun RaceSelector(label: String, selected: RaceResult?, options: List<RaceResult>, onSelect: (RaceResult) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth().height(Space.tapTarget)) {
            Column(Modifier.fillMaxWidth()) {
                Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(selected?.let { "${it.year} ${it.raceName}" } ?: "Choose a race", style = MaterialTheme.typography.bodyLarge, maxLines = 1)
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { result ->
                DropdownMenuItem(
                    text = { Text("${result.year} ${result.raceName} · ${formatTime(result.finish)}") },
                    onClick = { onSelect(result); expanded = false },
                )
            }
        }
    }
}

@Composable
private fun RaceComparison(first: RaceResult, second: RaceResult) {
    ContentCard {
        SectionHeading("Split comparison", "${first.kind.fullLabel} races")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Split", style = MaterialTheme.typography.labelMedium)
            Text(first.year.toString(), style = MaterialTheme.typography.labelMedium)
            Text(second.year.toString(), style = MaterialTheme.typography.labelMedium)
        }
        (Discipline.raceLegs + Discipline.FINISH).forEach { discipline ->
            Row(
                Modifier.fillMaxWidth().padding(vertical = Space.small),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Space.small),
            ) {
                Text(discipline.label, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                Text(formatTime(first.seconds(discipline)), style = MaterialTheme.typography.bodyMedium.copy(fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace))
                Text(formatTime(second.seconds(discipline)), style = MaterialTheme.typography.bodyMedium.copy(fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace))
            }
        }
        val seconds = (second.finish ?: 0) - (first.finish ?: 0)
        Text(
            if (seconds < 0) "${formatTime(-seconds)} faster in ${second.year}" else "${formatTime(seconds)} slower in ${second.year}",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun PolicyLinks() {
    val context = LocalContext.current
    Row(horizontalArrangement = Arrangement.spacedBy(Space.row), verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = { openUrl(context, PRIVACY_URL) }, modifier = Modifier.height(Space.tapTarget)) { Text("Privacy") }
        TextButton(onClick = { openUrl(context, TERMS_URL) }, modifier = Modifier.height(Space.tapTarget)) { Text("Terms") }
    }
}

private fun openUrl(context: android.content.Context, url: String) {
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))) }
}

private fun shareFile(activity: Activity?, file: File, mimeType: String) {
    if (activity == null) return
    val uri = FileProvider.getUriForFile(activity, "com.jackwallner.ironman.files", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = mimeType
        putExtra(Intent.EXTRA_STREAM, uri)
        clipData = android.content.ClipData.newUri(activity.contentResolver, "Race Book", uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    activity.startActivity(Intent.createChooser(intent, "Share your Race Book"))
}
