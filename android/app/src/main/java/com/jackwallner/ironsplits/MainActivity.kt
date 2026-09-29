package com.jackwallner.ironsplits

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalView
import com.jackwallner.ironsplits.data.AppearancePreference
import com.jackwallner.ironsplits.ui.LocalGraph
import com.jackwallner.ironsplits.ui.RootScreen
import com.jackwallner.ironsplits.ui.theme.Haptics
import com.jackwallner.ironsplits.ui.theme.TriTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val graph = (application as IronSplitsApplication).graph
        DebugLaunchOptions.apply(this, graph, intent)
        setContent {
            val settings by graph.settings.state.collectAsState()
            val dark = when (settings.appearance) {
                AppearancePreference.SYSTEM -> isSystemInDarkTheme()
                AppearancePreference.LIGHT -> false
                AppearancePreference.DARK -> true
            }
            // Every navigation bar is navy, so status bar content stays light in both schemes.
            LaunchedEffect(dark) {
                enableEdgeToEdge(
                    statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
                    navigationBarStyle = if (dark) SystemBarStyle.dark(Color.TRANSPARENT)
                    else SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
                )
            }
            val view = LocalView.current
            DisposableEffect(view) {
                Haptics.attach(view)
                onDispose { Haptics.attach(null) }
            }
            LaunchedEffect(settings.hapticsEnabled) { Haptics.enabled = settings.hapticsEnabled }
            LaunchedEffect(Unit) {
                graph.store.start()
                graph.feedConfig.refreshIfStale()
            }
            CompositionLocalProvider(LocalGraph provides graph) {
                TriTheme(dark) { RootScreen() }
            }
        }
    }

    override fun onStop() {
        super.onStop()
        (application as IronSplitsApplication).graph.voice.stop()
    }
}
