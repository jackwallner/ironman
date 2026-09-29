package com.jackwallner.ironsplits.data

import android.app.Activity
import android.content.Context
import com.jackwallner.ironsplits.BuildConfig
import com.revenuecat.purchases.CacheFetchPolicy
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.paywalls.events.CustomPaywallImpressionParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

object IronSplitsLegal {
    const val TERMS_URL = "https://jackwallner.github.io/ironman/terms.html"
    const val PRIVACY_URL = "https://jackwallner.github.io/ironman/privacy-policy.html"
    const val SUPPORT_URL = "https://jackwallner.github.io/ironman/support.html"
    const val FEEDBACK_EMAIL = "jackwallner+tri@gmail.com"
    const val PLAY_LISTING_URL = "https://play.google.com/store/apps/details?id=com.jackwallner.ironman"
}

/** The one plan the paywall draws: the lifetime Race Book unlock. */
data class PlanOption(val id: String, val displayName: String, val priceLabel: String, val pkg: Package?) {
    val isPurchasable: Boolean get() = pkg != null
}

enum class PaywallTrigger(val impressionId: String, val title: String, val subtitle: String) {
    RACE_BOOK_COMPARE(
        "ironsplits_paywall_race_book_compare",
        "Compare your races",
        "See exactly where one like-for-like race gained or lost time against another.",
    ),
    RACE_BOOK_EXPORT(
        "ironsplits_paywall_race_book_export",
        "Share your Race Book",
        "Create a polished race-history PDF or image with official splits, career stats and optional notes.",
    ),
    UPGRADE(
        "ironsplits_paywall_upgrade",
        "Unlock Race Book",
        "Compare like-for-like races and create unlimited PDF or image exports with one lifetime purchase.",
    ),
}

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED }

data class StoreState(
    val isPro: Boolean = false,
    val planOptions: List<PlanOption> = emptyList(),
    val isLoadingProducts: Boolean = false,
    val lastError: String? = null,
    val restoreError: String? = null,
    val offeringId: String? = null,
)

/**
 * RevenueCat, behind the single Race Book gate. Debug builds use the Test
 * Store key; release builds use the Play key. Neither ever runs on the other.
 */
class StoreService(private val context: Context, private val diagnostics: ConversionDiagnostics) {
    private val _state = MutableStateFlow(StoreState())
    val state: StateFlow<StoreState> = _state.asStateFlow()
    private var isConfigured = false
    private var forcePro = false
    private var paywallImpressionsThisSession = mutableSetOf<String>()

    val current: StoreState get() = _state.value

    /** Debug-only hook: open the paid boundary for local screenshots and tests. */
    fun forceProForDebug() {
        if (!BuildConfig.DEBUG) return
        forcePro = true
        _state.update { it.copy(isPro = true) }
    }

    suspend fun start() {
        if (forcePro) return
        if (!configureIfNeeded()) return
        updateCustomerStatus(CacheFetchPolicy.FETCH_CURRENT)
        fetchProducts()
    }

    suspend fun fetchProducts() {
        if (!configureIfNeeded()) {
            _state.update { it.copy(lastError = "Purchases aren't available in this build.") }
            return
        }
        _state.update { it.copy(isLoadingProducts = true) }
        try {
            val offerings = Purchases.sharedInstance.awaitOfferings()
            val offering: Offering? = offerings.getOffering("default") ?: offerings.current
            val lifetime = offering?.availablePackages?.filter { it.isLifetime }.orEmpty()
            _state.update {
                it.copy(
                    planOptions = lifetime.map { pkg ->
                        PlanOption(pkg.product.id, "Race Book", pkg.product.price.formatted, pkg)
                    },
                    offeringId = offering?.identifier,
                    lastError = null,
                    isLoadingProducts = false,
                )
            }
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            _state.update {
                it.copy(
                    isLoadingProducts = false,
                    lastError = "Couldn't load the Race Book unlock. Check your connection and try again.",
                )
            }
        }
    }

    val proPrice: String? get() = current.planOptions.firstOrNull()?.priceLabel

    fun directCtaLabel(): String = proPrice?.let { "Unlock Race Book for $it" } ?: "Unlock Race Book"

    fun trackPaywallImpression(id: String) {
        if (forcePro || !configureIfNeeded()) return
        diagnostics.recordPitchView(id)
        syncConversionAttributes()
        runCatching {
            Purchases.sharedInstance.trackCustomPaywallImpression(CustomPaywallImpressionParams(id))
        }
    }

    private fun syncConversionAttributes() {
        if (!configureIfNeeded()) return
        val attributes = diagnostics.subscriberAttributes.toMutableMap()
        if (attributes.isEmpty()) return
        current.offeringId?.let { attributes["offering_id"] = it }
        runCatching { Purchases.sharedInstance.setAttributes(attributes) }
    }

    /** Throws with a user-facing message; cancellation is an outcome, not an error. */
    suspend fun purchase(activity: Activity, plan: PlanOption): PurchaseOutcome {
        val pkg = plan.pkg ?: throw IllegalStateException("Race Book isn't available to purchase right now.")
        if (!configureIfNeeded()) throw IllegalStateException("Purchases aren't available in this build.")
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            apply(result.customerInfo)
            if (result.customerInfo.hasProEntitlement) {
                diagnostics.recordConversion(pkg.product.id, current.offeringId)
                syncConversionAttributes()
                PurchaseOutcome.PURCHASED
            } else {
                PurchaseOutcome.PENDING
            }
        } catch (error: PurchasesTransactionException) {
            if (error.userCancelled) return PurchaseOutcome.CANCELLED
            val message = "Couldn't complete the purchase. Please try again."
            _state.update { it.copy(lastError = message) }
            throw IllegalStateException(message)
        }
    }

    suspend fun restorePurchases() {
        _state.update { it.copy(restoreError = null) }
        if (!configureIfNeeded()) {
            _state.update { it.copy(restoreError = "Purchases aren't available in this build.") }
            return
        }
        try {
            val info = Purchases.sharedInstance.awaitRestore()
            apply(info)
            _state.update {
                it.copy(restoreError = if (it.isPro) null else "No Race Book purchase was found for this Google account.")
            }
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            _state.update { it.copy(restoreError = "Couldn't restore purchases. Try again.") }
        }
    }

    private suspend fun updateCustomerStatus(policy: CacheFetchPolicy) {
        runCatching { Purchases.sharedInstance.awaitCustomerInfo(policy) }
            .onSuccess(::apply)
            .onFailure { error ->
                if (isCancellation(error)) throw error
                _state.update {
                    it.copy(lastError = "Couldn't refresh your Race Book purchase status. Check your connection and try again.")
                }
            }
    }

    private fun apply(info: CustomerInfo) {
        if (forcePro) return
        _state.update { it.copy(isPro = info.hasProEntitlement) }
    }

    private fun configureIfNeeded(): Boolean {
        if (isConfigured) return true
        val key = BuildConfig.REVENUECAT_API_KEY
        if (key.isBlank()) return false
        // Never the production Play key in a debug build, and never a test key in release.
        if (BuildConfig.DEBUG && key.startsWith("goog_")) return false
        if (!BuildConfig.DEBUG && !key.startsWith("goog_")) return false
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        Purchases.configure(PurchasesConfiguration.Builder(context, key).build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { apply(it) }
        isConfigured = true
        return true
    }

    private val Package.isLifetime: Boolean
        get() = packageType == PackageType.LIFETIME || product.id.substringBefore(":") == LIFETIME_PRODUCT

    private val CustomerInfo.hasProEntitlement: Boolean
        get() {
            val active = entitlements.active
            if (ENTITLEMENTS.any { active[it]?.isActive == true }) return true
            // If the dashboard mapping is ever missing, ownership of the lifetime product still counts.
            if (nonSubscriptionTransactions.any { it.productIdentifier == LIFETIME_PRODUCT }) return true
            return activeSubscriptions.any { it.substringBefore(":") in LEGACY_SUBSCRIPTIONS }
        }

    private companion object {
        const val LIFETIME_PRODUCT = "com.jackwallner.ironman.pro"
        val LEGACY_SUBSCRIPTIONS = setOf("com.jackwallner.ironman.pro.yearly", "com.jackwallner.ironman.pro.monthly")
        val ENTITLEMENTS = listOf("pro", "Iron Splits+", "Ironman App Pro")
    }
}
