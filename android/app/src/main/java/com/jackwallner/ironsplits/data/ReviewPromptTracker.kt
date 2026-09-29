package com.jackwallner.ironsplits.data

import android.content.Context
import com.jackwallner.ironsplits.model.Discipline
import com.jackwallner.ironsplits.model.RaceAnalytics
import com.jackwallner.ironsplits.model.RaceResult
import java.time.LocalDate
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Launches, positive moments and review-prompt eligibility. The enjoyment
 * pre-filter keeps unhappy users off the public store listing.
 */
class ReviewPromptTracker(context: Context) {
    private val defaults = context.getSharedPreferences("reviewPrompt", Context.MODE_PRIVATE)
    private val _positiveMoments = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val positiveMoments: SharedFlow<Unit> = _positiveMoments.asSharedFlow()

    /** Manual presentation from Settings bypasses the passive gates. */
    enum class Presentation { ENJOYMENT, FEEDBACK_ONLY }
    private val _requests = MutableSharedFlow<Presentation>(extraBufferCapacity = 1)
    val requests: SharedFlow<Presentation> = _requests.asSharedFlow()

    var isAutomationRun = false

    fun requestEnjoymentPrompt() {
        _requests.tryEmit(Presentation.ENJOYMENT)
    }

    fun requestFeedback() {
        _requests.tryEmit(Presentation.FEEDBACK_ONLY)
    }

    fun isPositiveMoment(result: RaceResult, isReadOnly: Boolean, within: List<RaceResult>): Boolean {
        if (isReadOnly || !result.isComplete) return false
        return Discipline.rankable.any { RaceAnalytics.isPersonalBest(result, it, within) }
    }

    fun recordAppLaunch(now: Long = System.currentTimeMillis()) {
        val day = LocalDate.now().toString()
        if (defaults.getString(LAST_USE_DAY, null) != day) {
            defaults.edit().putString(LAST_USE_DAY, day).putInt(DISTINCT_DAYS, defaults.getInt(DISTINCT_DAYS, 0) + 1).apply()
        }
        val editor = defaults.edit()
        if (!defaults.contains(FIRST_OPEN)) editor.putLong(FIRST_OPEN, now)
        editor.putInt(LAUNCH_COUNT, defaults.getInt(LAUNCH_COUNT, 0) + 1).apply()
    }

    fun recordPositiveMoment(identifier: String?) {
        if (identifier != null) {
            val ids = defaults.getString(MOMENT_IDS, "").orEmpty().split('\n').filter { it.isNotEmpty() }
            if (identifier in ids) return
            defaults.edit().putString(MOMENT_IDS, (ids + identifier).takeLast(100).joinToString("\n")).apply()
        }
        defaults.edit()
            .putInt(MOMENT_COUNT, defaults.getInt(MOMENT_COUNT, 0) + 1)
            .putBoolean(PENDING_MOMENT, true)
            .apply()
        _positiveMoments.tryEmit(Unit)
    }

    private fun passivePromptAllowed(now: Long): Boolean {
        if (defaults.getString(OUTCOME, null) != null) return false
        if (!defaults.contains(LAST_SHOWN)) return true
        val days = if (defaults.getBoolean(SOFT_DEFER, false)) SOFT_DEFER_COOLDOWN_DAYS else COOLDOWN_DAYS
        return now - defaults.getLong(LAST_SHOWN, 0) >= days * DAY_MS
    }

    fun shouldShowAfterPositiveMoment(hasCompletedOnboarding: Boolean, now: Long = System.currentTimeMillis()): Boolean {
        if (!defaults.getBoolean(PENDING_MOMENT, false)) return false
        if (isAutomationRun || !hasCompletedOnboarding || !passivePromptAllowed(now)) return false
        if (defaults.getInt(LAUNCH_COUNT, 0) < 5) return false
        if (defaults.getInt(MOMENT_COUNT, 0) < 3) return false
        if (defaults.getInt(DISTINCT_DAYS, 0) < 3) return false
        val first = defaults.getLong(FIRST_OPEN, 0)
        if (first == 0L) return false
        return now - first >= 7 * DAY_MS
    }

    fun markShown(now: Long = System.currentTimeMillis()) {
        defaults.edit().putLong(LAST_SHOWN, now).putBoolean(SOFT_DEFER, false).putBoolean(PENDING_MOMENT, false).apply()
    }

    /** Liked the app, then the store's own prompt ran: keep the short cooldown. */
    fun markSoftDeferred(now: Long = System.currentTimeMillis()) {
        defaults.edit().putLong(LAST_SHOWN, now).putBoolean(SOFT_DEFER, true).putBoolean(PENDING_MOMENT, false).apply()
    }

    fun markOpenedWriteReview() {
        defaults.edit().putString(OUTCOME, "openedWriteReview").apply()
        markShown()
    }

    fun markFeedbackDraftOpened() {
        defaults.edit().putString(OUTCOME, "feedbackDraftOpened").apply()
        markShown()
    }

    private companion object {
        const val LAUNCH_COUNT = "reviewPrompt.appLaunchCount"
        const val FIRST_OPEN = "reviewPrompt.firstAppOpenDate"
        const val LAST_SHOWN = "reviewPrompt.lastShownDate"
        const val OUTCOME = "reviewPrompt.outcome"
        const val MOMENT_COUNT = "reviewPrompt.positiveMomentCount"
        const val MOMENT_IDS = "reviewPrompt.positiveMomentIDs"
        const val PENDING_MOMENT = "reviewPrompt.pendingPositiveMoment"
        const val SOFT_DEFER = "reviewPrompt.softDefer"
        const val DISTINCT_DAYS = "reviewPrompt.distinctUseDays"
        const val LAST_USE_DAY = "reviewPrompt.lastUseDay"
        const val COOLDOWN_DAYS = 120L
        const val SOFT_DEFER_COOLDOWN_DAYS = 30L
        const val DAY_MS = 86_400_000L
    }
}

/**
 * On-device record of how someone met the Race Book pitch before buying,
 * mirrored onto the RevenueCat customer as attributes. Counts, dates and
 * surface names only.
 */
class ConversionDiagnostics(context: Context) {
    private val defaults = context.getSharedPreferences("conv", Context.MODE_PRIVATE)

    fun recordAppOpen() {
        val editor = defaults.edit()
        if (!defaults.contains(INSTALLED_AT)) editor.putLong(INSTALLED_AT, System.currentTimeMillis())
        editor.putInt(APP_OPENS, defaults.getInt(APP_OPENS, 0) + 1).apply()
    }

    fun recordPitchView(impressionId: String) {
        val surface = impressionId.removePrefix(PREFIX)
        val editor = defaults.edit()
            .putInt(TOTAL_VIEWS, defaults.getInt(TOTAL_VIEWS, 0) + 1)
            .putInt(views(surface), defaults.getInt(views(surface), 0) + 1)
            .putString(LAST_SURFACE, surface)
        if (!defaults.contains(FIRST_SEEN)) {
            editor.putLong(FIRST_SEEN, System.currentTimeMillis())
            editor.putInt(OPENS_BEFORE_FIRST_PITCH, defaults.getInt(APP_OPENS, 0))
            if (defaults.contains(INSTALLED_AT)) {
                editor.putInt(DAYS_TO_FIRST_PITCH, daysSince(defaults.getLong(INSTALLED_AT, 0)))
            }
        }
        editor.apply()
    }

    fun recordConversion(plan: String, offeringId: String?) {
        if (defaults.contains(CONVERTED_ON)) return
        val editor = defaults.edit()
            .putString(CONVERTED_ON, defaults.getString(LAST_SURFACE, null) ?: "unknown")
            .putInt(VIEWS_AT_CONVERT, defaults.getInt(TOTAL_VIEWS, 0))
            .putString(CONVERTED_PLAN, plan)
            .putBoolean(CONVERTED_WITH_TRIAL, false)
            .putLong(CONVERTED_AT, System.currentTimeMillis())
        offeringId?.let { editor.putString(CONVERTED_OFFERING, it) }
        if (defaults.contains(FIRST_SEEN)) editor.putInt(DAYS_TO_CONVERT, daysSince(defaults.getLong(FIRST_SEEN, 0)))
        editor.apply()
    }

    val subscriberAttributes: Map<String, String>
        get() {
            val total = defaults.getInt(TOTAL_VIEWS, 0)
            if (total <= 0) return emptyMap()
            val attributes = mutableMapOf("pitch_views_total" to total.toString())
            defaults.all.forEach { (key, value) ->
                if (key.startsWith("conv.pitchViews.") && key != TOTAL_VIEWS && value is Int && value > 0) {
                    attributes["pitch_views_${key.removePrefix("conv.pitchViews.")}".take(40)] = value.toString()
                }
            }
            defaults.getString(LAST_SURFACE, null)?.let { attributes["pitch_last"] = it }
            if (defaults.contains(FIRST_SEEN)) {
                val first = defaults.getLong(FIRST_SEEN, 0)
                attributes["pitch_first_seen"] = java.time.Instant.ofEpochMilli(first).toString()
                attributes["days_since_first_pitch"] = daysSince(first).toString()
            }
            if (defaults.contains(DAYS_TO_FIRST_PITCH)) attributes["days_since_install"] = defaults.getInt(DAYS_TO_FIRST_PITCH, 0).toString()
            if (defaults.contains(OPENS_BEFORE_FIRST_PITCH)) {
                attributes["opens_before_first_pitch"] = defaults.getInt(OPENS_BEFORE_FIRST_PITCH, 0).toString()
            }
            defaults.getString(CONVERTED_ON, null)?.let { convertedOn ->
                attributes["converted_surface"] = convertedOn
                attributes["converted_at"] = java.time.Instant.ofEpochMilli(defaults.getLong(CONVERTED_AT, 0)).toString()
                attributes["pitch_views_at_convert"] = defaults.getInt(VIEWS_AT_CONVERT, 0).toString()
                attributes["days_to_convert"] = defaults.getInt(DAYS_TO_CONVERT, 0).toString()
                attributes["converted_plan"] = defaults.getString(CONVERTED_PLAN, null) ?: "unknown"
                attributes["converted_with_trial"] = if (defaults.getBoolean(CONVERTED_WITH_TRIAL, false)) "true" else "false"
                defaults.getString(CONVERTED_OFFERING, null)?.let { attributes["converted_offering"] = it }
            }
            return attributes
        }

    private fun daysSince(millis: Long): Int = maxOf(0, ((System.currentTimeMillis() - millis) / 86_400_000L).toInt())

    private fun views(surface: String) = "conv.pitchViews.$surface"

    private companion object {
        const val PREFIX = "ironsplits_paywall_"
        const val TOTAL_VIEWS = "conv.pitchViews.total"
        const val FIRST_SEEN = "conv.pitchFirstSeen"
        const val LAST_SURFACE = "conv.pitchLastSurface"
        const val INSTALLED_AT = "conv.installedAt"
        const val APP_OPENS = "conv.appOpens"
        const val OPENS_BEFORE_FIRST_PITCH = "conv.opensBeforeFirstPitch"
        const val DAYS_TO_FIRST_PITCH = "conv.daysToFirstPitch"
        const val CONVERTED_ON = "conv.convertedOn"
        const val CONVERTED_AT = "conv.convertedAt"
        const val VIEWS_AT_CONVERT = "conv.viewsAtConvert"
        const val DAYS_TO_CONVERT = "conv.daysToConvert"
        const val CONVERTED_PLAN = "conv.convertedPlan"
        const val CONVERTED_WITH_TRIAL = "conv.convertedWithTrial"
        const val CONVERTED_OFFERING = "conv.convertedOffering"
    }
}
