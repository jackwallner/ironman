package com.jackwallner.ironsplits.billing

import android.app.Activity
import android.content.Context
import com.jackwallner.ironsplits.BuildConfig
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.getCustomerInfoWith
import com.revenuecat.purchases.getOfferingsWith
import com.revenuecat.purchases.purchaseWith
import com.revenuecat.purchases.restorePurchasesWith

class RevenueCatStore(context: Context) {
    val isConfigured: Boolean get() = BuildConfig.REVENUECAT_API_KEY.isNotBlank()

    fun loadLifetimePrice(onResult: (String?) -> Unit) {
        if (!isConfigured) {
            onResult(null)
            return
        }
        Purchases.sharedInstance.getOfferingsWith(
            onError = { onResult(null) },
            onSuccess = { offerings ->
                val lifetime = offerings.current?.availablePackages?.firstOrNull { it.packageType.name == "LIFETIME" }
                onResult(lifetime?.product?.price?.formatted)
            },
        )
    }

    fun refreshEntitlement(onResult: (Boolean) -> Unit) {
        if (!isConfigured) {
            onResult(false)
            return
        }
        Purchases.sharedInstance.getCustomerInfoWith(
            onError = { onResult(false) },
            onSuccess = { info -> onResult("pro" in info.entitlements.active) },
        )
    }

    fun purchaseLifetime(activity: Activity, onResult: (Boolean, String?) -> Unit) {
        if (!isConfigured) {
            onResult(false, "Purchases are not available in this build.")
            return
        }
        Purchases.sharedInstance.getOfferingsWith(
            onError = { error -> onResult(false, error.message) },
            onSuccess = { offerings ->
                val packageToBuy = offerings.current?.availablePackages
                    ?.firstOrNull { it.packageType.name == "LIFETIME" }
                if (packageToBuy == null) {
                    onResult(false, "Race Book is not available to purchase right now.")
                    return@getOfferingsWith
                }
                Purchases.sharedInstance.purchaseWith(
                    PurchaseParams.Builder(activity, packageToBuy).build(),
                    onError = { error, cancelled ->
                        if (!cancelled) onResult(false, error.message)
                    },
                    onSuccess = { _, info ->
                        onResult("pro" in info.entitlements.active, null)
                    },
                )
            },
        )
    }

    fun restore(onResult: (Boolean, String?) -> Unit) {
        if (!isConfigured) {
            onResult(false, "Purchases are not available in this build.")
            return
        }
        Purchases.sharedInstance.restorePurchasesWith(
            onError = { error -> onResult(false, error.message) },
            onSuccess = { info ->
                val unlocked = "pro" in info.entitlements.active
                onResult(unlocked, if (unlocked) null else "No Race Book purchase was found for this Play account.")
            },
        )
    }
}
