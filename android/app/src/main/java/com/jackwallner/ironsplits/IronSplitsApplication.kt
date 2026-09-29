package com.jackwallner.ironsplits

import android.app.Application
import android.net.http.HttpResponseCache
import java.io.File

class IronSplitsApplication : Application() {
    lateinit var graph: AppGraph
        private set

    override fun onCreate() {
        super.onCreate()
        // The proxy's answers for past races never change; a local HTTP cache
        // makes coming back to a screen instant instead of another round trip.
        runCatching { HttpResponseCache.install(File(cacheDir, "http"), 20L * 1024 * 1024) }
        graph = AppGraph(this)
        graph.review.recordAppLaunch()
        graph.diagnostics.recordAppOpen()
    }
}
