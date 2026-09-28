package com.jackwallner.ironsplits.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag

private const val PRIVACY_URL = "https://jackwallner.github.io/ironman/privacy-policy.html"
private const val TERMS_URL = "https://jackwallner.github.io/ironman/terms/"
private const val SUPPORT_URL = "https://jackwallner.github.io/ironman/support.html"

@Composable
fun SettingsScreen(state: AppUiState, viewModel: IronSplitsViewModel) {
    val context = LocalContext.current
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Space.page, vertical = Space.section),
        verticalArrangement = Arrangement.spacedBy(Space.section),
    ) {
        ScreenTitle("Settings", "Your data and purchase options.")
        ContentCard {
            SectionHeading("Your data")
            Text("Your claimed athlete, recent Explore profiles, and race notes are stored on this device. IM Iron Splits has no account system.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("A name search and public athlete or event IDs are sent to the timing service to retrieve published results.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        ContentCard {
            SectionHeading("Race Book purchase")
            Text("Race Book is the only paid feature. It is a one-time lifetime purchase through Google Play.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Button(
                onClick = viewModel::restorePurchases,
                modifier = Modifier.fillMaxWidth().height(Space.tapTarget).testTag("restore-purchases"),
            ) { Text("Restore Purchases") }
            state.restoreMessage?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
        }
        ContentCard {
            SectionHeading("About IM Iron Splits")
            Text(
                "IM Iron Splits is an independent results app. It is not affiliated with, endorsed by, or sponsored by any race organizer or timing company.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text("Results are shown as published by each event timer.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(
                "For general race and fitness information only. IM Iron Splits is not a medical device and does not diagnose, treat, cure, or prevent any medical condition.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text("Version ${com.jackwallner.ironsplits.BuildConfig.VERSION_NAME}", style = MaterialTheme.typography.labelMedium)
        }
        ContentCard {
            SectionHeading("Help and policies")
            TextButton(onClick = { openExternal(context, SUPPORT_URL) }, modifier = Modifier.height(Space.tapTarget)) { Text("Support") }
            TextButton(onClick = { openExternal(context, PRIVACY_URL) }, modifier = Modifier.height(Space.tapTarget)) { Text("Privacy Policy") }
            TextButton(onClick = { openExternal(context, TERMS_URL) }, modifier = Modifier.height(Space.tapTarget)) { Text("Terms of Use") }
        }
    }
}

private fun openExternal(context: android.content.Context, value: String) {
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(value))) }
}
