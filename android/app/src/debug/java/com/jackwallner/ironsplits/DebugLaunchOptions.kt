package com.jackwallner.ironsplits

import android.content.Intent
import androidx.activity.ComponentActivity
import com.jackwallner.ironsplits.data.AppearancePreference

/**
 * Debug-only launch extras for tests and screenshots, the Android side of the
 * iOS `-ResetLocker`, `-SeedScreenshotData`, `-PattieMode` and `FORCE_PRO`
 * switches. None of this is compiled into a release build.
 *
 *     adb shell am start -n com.jackwallner.ironman/com.jackwallner.ironsplits.MainActivity \
 *         --ez resetLocker true --ez seedScreenshotData true --es appearance dark
 */
object DebugLaunchOptions {
    fun apply(activity: ComponentActivity, graph: AppGraph, intent: Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getBoolean("uiTest")) graph.review.isAutomationRun = true
        if (extras.getBoolean("resetLocker")) {
            graph.locker.replaceForTesting(null, emptyList())
            graph.settings.reset()
            graph.feedConfig.clear()
            graph.askLibrary.clear()
            graph.pointerLibrary.clear()
            graph.fieldCache.clear()
            graph.pattie.resetForTesting(enabled = extras.getBoolean("pattieMode"))
        }
        if (extras.getBoolean("seedScreenshotData")) {
            graph.locker.replaceForTesting(ScreenshotFixtures.athlete, ScreenshotFixtures.results)
            graph.fieldCache.store(ScreenshotFixtures.field, ScreenshotFixtures.EVENT_ID)
            graph.settings.saveRecentAthletes(listOf(ScreenshotFixtures.exploreAthlete))
            graph.seededCareers[ScreenshotFixtures.exploreAthlete.id] = ScreenshotFixtures.exploreResults
        }
        if (extras.getBoolean("forcePro")) graph.store.forceProForDebug()
        extras.getString("appearance")?.let { graph.settings.appearance = AppearancePreference.fromRaw(it) }
        extras.getString("tipsMode")?.let { graph.settings.tipsMode = it }
    }
}
