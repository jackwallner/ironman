package com.jackwallner.ironsplits.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jackwallner.ironsplits.model.RaceResult

@Composable
fun IronSplitsApp(viewModel: IronSplitsViewModel = viewModel()) {
    val state by viewModel.state.collectAsState()
    Surface(color = MaterialTheme.colorScheme.background) {
        Scaffold(
            bottomBar = {
                if (state.selectedResult == null && !(state.profile != null && state.tab == AppTab.EXPLORE)) {
                    IronBottomBar(state.tab, viewModel::selectTab)
                }
            },
        ) { innerPadding ->
            AppContent(state, viewModel, innerPadding)
        }
    }
}

@Composable
private fun AppContent(state: AppUiState, viewModel: IronSplitsViewModel, innerPadding: PaddingValues) {
    Box(Modifier.fillMaxSize().padding(innerPadding)) {
        when {
            state.selectedResult != null -> RaceDetailScreen(state, viewModel)
            state.tab == AppTab.EXPLORE && state.profile != null -> AthletePreviewScreen(state, viewModel)
            else -> when (state.tab) {
                AppTab.LOCKER -> LockerScreen(state, viewModel)
                AppTab.EXPLORE -> ExploreScreen(state, viewModel)
                AppTab.TIPS -> TipsScreen(state, viewModel)
                AppTab.RACE_BOOK -> RaceBookScreen(state, viewModel)
                AppTab.SETTINGS -> SettingsScreen(state, viewModel)
            }
        }
    }
}

@Composable
private fun IronBottomBar(selected: AppTab, onSelect: (AppTab) -> Unit) {
    val tabs = listOf(
        Triple(AppTab.LOCKER, Icons.Default.Home, "Locker"),
        Triple(AppTab.EXPLORE, Icons.Default.Explore, "Explore"),
        Triple(AppTab.TIPS, Icons.Default.Lightbulb, "Tips"),
        Triple(AppTab.RACE_BOOK, Icons.AutoMirrored.Filled.MenuBook, "Race Book"),
        Triple(AppTab.SETTINGS, Icons.Default.Settings, "Settings"),
    )
    NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
        tabs.forEach { (tab, image, label) ->
            NavigationBarItem(
                selected = selected == tab,
                onClick = { onSelect(tab) },
                icon = { Icon(image, contentDescription = label) },
                label = { Text(label, maxLines = 1) },
            )
        }
    }
}

@Composable
fun ScreenTitle(title: String, subtitle: String? = null, modifier: Modifier = Modifier) {
    androidx.compose.foundation.layout.Column(modifier) {
        Text(title, style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onSurface)
        if (subtitle != null) {
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun MessageBanner(message: String?, onDismiss: () -> Unit) {
    if (message.isNullOrBlank()) return
    androidx.compose.material3.Card(
        colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        androidx.compose.foundation.layout.Row(
            modifier = Modifier.padding(horizontal = Space.page, vertical = Space.card),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Text(message, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            androidx.compose.material3.TextButton(onClick = onDismiss) { Text("Dismiss") }
        }
    }
}
