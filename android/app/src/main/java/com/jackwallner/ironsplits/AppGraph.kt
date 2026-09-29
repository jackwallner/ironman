package com.jackwallner.ironsplits

import android.content.Context
import com.jackwallner.ironsplits.data.AppSettings
import com.jackwallner.ironsplits.data.AskPattieLibrary
import com.jackwallner.ironsplits.data.ConversionDiagnostics
import com.jackwallner.ironsplits.data.FeedConfigLoader
import com.jackwallner.ironsplits.data.LockerStore
import com.jackwallner.ironsplits.data.PattieMode
import com.jackwallner.ironsplits.data.PattieVoice
import com.jackwallner.ironsplits.data.PattieVoiceLibrary
import com.jackwallner.ironsplits.data.PointerLibrary
import com.jackwallner.ironsplits.data.PointerMediaCache
import com.jackwallner.ironsplits.data.RaceFieldCache
import com.jackwallner.ironsplits.data.RaceNotesStore
import com.jackwallner.ironsplits.data.ResultsApi
import com.jackwallner.ironsplits.data.ReviewPromptTracker
import com.jackwallner.ironsplits.data.StoreService
import com.jackwallner.ironsplits.ui.theme.Haptics
import kotlinx.coroutines.MainScope

/** Every long-lived object the screens share, built once per process. */
class AppGraph(context: Context) {
    val appContext: Context = context.applicationContext
    val scope = MainScope()
    val settings = AppSettings(appContext)
    val feedConfig = FeedConfigLoader(appContext)
    val api = ResultsApi(feedConfig)
    val locker = LockerStore(appContext, api, feedConfig, scope)
    val notes = RaceNotesStore(appContext)
    val fieldCache = RaceFieldCache()
    val askLibrary = AskPattieLibrary(appContext)
    val pointerLibrary = PointerLibrary(appContext)
    val mediaCache = PointerMediaCache(appContext, scope)
    val voice = PattieVoice(appContext)
    private val modeTips by lazy { PattieVoiceLibrary.modeTips(askLibrary.bundled()) }
    val pattie = PattieMode(appContext, voice, { modeTips }, { Haptics.soft() })
    val review = ReviewPromptTracker(appContext)
    val diagnostics = ConversionDiagnostics(appContext)
    val store = StoreService(appContext, diagnostics)
    /** Debug fixtures only: careers served without the network. Always empty in release. */
    val seededCareers = mutableMapOf<String, List<com.jackwallner.ironsplits.model.RaceResult>>()
}
