package com.jackwallner.ironsplits

import android.content.Intent
import androidx.activity.ComponentActivity

/** Release builds ignore every launch option. The paid boundary cannot be opened here. */
object DebugLaunchOptions {
    @Suppress("UNUSED_PARAMETER")
    fun apply(activity: ComponentActivity, graph: AppGraph, intent: Intent?) = Unit
}
