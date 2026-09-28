package com.jackwallner.ironsplits

import android.app.Application
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration

class IronSplitsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val key = BuildConfig.REVENUECAT_API_KEY
        if (key.isBlank()) return
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        Purchases.configure(PurchasesConfiguration.Builder(this, key).build())
    }
}
