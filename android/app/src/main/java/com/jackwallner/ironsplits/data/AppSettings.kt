package com.jackwallner.ironsplits.data

import android.content.Context
import com.jackwallner.ironsplits.model.Athlete
import com.jackwallner.ironsplits.model.RaceKind
import com.jackwallner.ironsplits.model.UnitPreference
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray

enum class AppearancePreference(val rawValue: String, val title: String) {
    SYSTEM("system", "System"), LIGHT("light", "Light"), DARK("dark", "Dark");

    companion object {
        fun fromRaw(raw: String?) = entries.firstOrNull { it.rawValue == raw } ?: SYSTEM
    }
}

data class SettingsState(
    val units: UnitPreference,
    val preferredKind: RaceKind?,
    val appearance: AppearancePreference,
    val hapticsEnabled: Boolean,
    val hasCompletedOnboarding: Boolean,
    val tipsMode: String,
)

/** Preferences that are not the locker itself. */
class AppSettings(context: Context) {
    private val defaults = context.getSharedPreferences("settings", Context.MODE_PRIVATE)
    private val _state = MutableStateFlow(read())
    val state: StateFlow<SettingsState> = _state.asStateFlow()

    val current: SettingsState get() = _state.value

    var units: UnitPreference
        get() = current.units
        set(value) = write { putString(UNITS, value.rawValue) }

    /** Last distance looked at, so a leaderboard opens where it was left. */
    var preferredKind: RaceKind?
        get() = current.preferredKind
        set(value) = write { putString(PREFERRED_KIND, value?.rawValue.orEmpty()) }

    var appearance: AppearancePreference
        get() = current.appearance
        set(value) = write { putString(APPEARANCE, value.rawValue) }

    var hapticsEnabled: Boolean
        get() = current.hapticsEnabled
        set(value) = write { putBoolean(HAPTICS, value) }

    var hasCompletedOnboarding: Boolean
        get() = current.hasCompletedOnboarding
        set(value) = write { putBoolean(ONBOARDED, value) }

    var tipsMode: String
        get() = current.tipsMode
        set(value) = write { putString(TIPS_MODE, value) }

    fun recentAthletes(): List<Athlete> =
        runCatching { Codec.athletes(JSONArray(defaults.getString(RECENTS, "[]"))) }.getOrDefault(emptyList()).take(3)

    fun saveRecentAthletes(athletes: List<Athlete>) {
        val array = JSONArray()
        athletes.take(3).forEach { array.put(Codec.athlete(it)) }
        defaults.edit().putString(RECENTS, array.toString()).apply()
    }

    fun reset() {
        defaults.edit().clear().apply()
        _state.value = read()
    }

    private fun write(block: android.content.SharedPreferences.Editor.() -> Unit) {
        defaults.edit().apply(block).apply()
        _state.value = read()
    }

    private fun read() = SettingsState(
        units = UnitPreference.fromRaw(defaults.getString(UNITS, null)) ?: UnitPreference.deviceDefault,
        preferredKind = RaceKind.fromRaw(defaults.getString(PREFERRED_KIND, null)),
        appearance = AppearancePreference.fromRaw(defaults.getString(APPEARANCE, null)),
        hapticsEnabled = defaults.getBoolean(HAPTICS, true),
        hasCompletedOnboarding = defaults.getBoolean(ONBOARDED, false),
        tipsMode = defaults.getString(TIPS_MODE, "ask") ?: "ask",
    )

    private companion object {
        const val UNITS = "settings.units"
        const val PREFERRED_KIND = "settings.preferredKind"
        const val APPEARANCE = "settings.appearance"
        const val HAPTICS = "settings.haptics.enabled"
        const val ONBOARDED = "settings.hasCompletedOnboarding"
        const val TIPS_MODE = "pointers.mode"
        const val RECENTS = "explore.recentAthletes"
    }
}
