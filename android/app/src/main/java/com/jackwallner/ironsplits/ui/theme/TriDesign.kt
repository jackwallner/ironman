package com.jackwallner.ironsplits.ui.theme

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.ironsplits.model.Discipline

private fun rgb(r: Double, g: Double, b: Double) = Color(r.toFloat(), g.toFloat(), b.toFloat())

/**
 * The colour system, one token per role, resolved per scheme. A view names a
 * token, never a literal colour. Values match `TriDesign.swift` exactly.
 */
@Immutable
data class TriColors(
    val isDark: Boolean,
    val canvas: Color,
    val surface: Color,
    val surfaceAlt: Color,
    val surfaceSunk: Color,
    val hairline: Color,
    val divider: Color,
    val ink: Color,
    val inkSecondary: Color,
    val inkTertiary: Color,
    val inkOnDark: Color,
    val inkOnSunrise: Color,
    val mediaCanvas: Color,
    val deep: Color,
    val finish: Color,
    val sunrise: Color,
    val positive: Color,
    val negative: Color,
    val swim: Color,
    val bike: Color,
    val run: Color,
    val transition: Color,
    val shadow: Color,
    /** The circular toolbar button on the navy bar. */
    val toolbarCircle: Color,
    /** Text on the toolbar glass: navy on the pale light-mode glass, white in dark. */
    val toolbarContent: Color,
    /** The floating tab bar capsule and its selected pill. */
    val tabBar: Color,
    val tabSelection: Color,
    private val fastFill: Color,
    private val midFill: Color,
    private val slowFill: Color,
    private val fastText: Color,
    private val midText: Color,
    private val slowText: Color,
) {
    fun color(discipline: Discipline): Color = when (discipline) {
        Discipline.SWIM -> swim
        Discipline.BIKE -> bike
        Discipline.RUN -> run
        Discipline.T1, Discipline.T2, Discipline.TRANSITIONS -> transition
        Discipline.FINISH -> finish
    }

    /** Fill for a percentile bar, 0 (slow) to 100 (fast). */
    fun percentileFill(p: Int): Color = ramp(p, fastFill, midFill, slowFill)

    /** Text keeps contrast at the 50th percentile, where the fill ramp goes neutral. */
    fun percentileText(p: Int): Color = ramp(p, fastText, midText, slowText)

    private fun ramp(p: Int, fast: Color, mid: Color, slow: Color): Color {
        val t = (p / 100f).coerceIn(0f, 1f)
        return if (t < 0.5f) lerp(slow, mid, t * 2) else lerp(mid, fast, (t - 0.5f) * 2)
    }

    companion object {
        val light = TriColors(
            isDark = false,
            canvas = rgb(0.949, 0.953, 0.961),
            surface = rgb(1.0, 1.0, 1.0),
            surfaceAlt = rgb(0.965, 0.968, 0.976),
            surfaceSunk = rgb(0.906, 0.918, 0.933),
            hairline = rgb(0.827, 0.839, 0.859),
            divider = rgb(0.886, 0.898, 0.914),
            ink = rgb(0.075, 0.098, 0.129),
            inkSecondary = rgb(0.259, 0.290, 0.333),
            inkTertiary = rgb(0.380, 0.410, 0.460),
            inkOnDark = Color.White,
            inkOnSunrise = Color.White,
            mediaCanvas = Color.Black,
            deep = rgb(0.020, 0.094, 0.208),
            finish = rgb(0.122, 0.396, 0.729),
            sunrise = rgb(0.780, 0.200, 0.165),
            positive = rgb(0.160, 0.440, 0.170),
            negative = rgb(0.741, 0.161, 0.161),
            swim = rgb(0.122, 0.396, 0.729),
            bike = rgb(0.361, 0.706, 0.145),
            run = rgb(0.780, 0.200, 0.165),
            transition = rgb(0.549, 0.573, 0.612),
            shadow = Color.Black,
            toolbarCircle = Color(0xFF9DBDEB),
            toolbarContent = rgb(0.020, 0.094, 0.208),
            tabBar = Color(0xF7FBFBFD),
            tabSelection = Color(0x1A131921),
            fastFill = rgb(0.780, 0.200, 0.165),
            midFill = rgb(0.741, 0.753, 0.780),
            slowFill = rgb(0.122, 0.396, 0.729),
            fastText = rgb(0.620, 0.122, 0.098),
            midText = rgb(0.267, 0.290, 0.333),
            slowText = rgb(0.086, 0.282, 0.600),
        )

        val dark = TriColors(
            isDark = true,
            canvas = rgb(0.043, 0.059, 0.078),
            surface = rgb(0.086, 0.110, 0.141),
            surfaceAlt = rgb(0.110, 0.137, 0.176),
            surfaceSunk = rgb(0.055, 0.075, 0.098),
            hairline = rgb(0.169, 0.204, 0.251),
            divider = rgb(0.133, 0.165, 0.204),
            ink = rgb(0.949, 0.961, 0.973),
            inkSecondary = rgb(0.678, 0.722, 0.769),
            inkTertiary = rgb(0.482, 0.529, 0.588),
            inkOnDark = Color.White,
            inkOnSunrise = rgb(0.075, 0.098, 0.129),
            mediaCanvas = Color.Black,
            deep = rgb(0.028, 0.125, 0.278),
            finish = rgb(0.278, 0.627, 0.969),
            sunrise = rgb(0.965, 0.365, 0.310),
            positive = rgb(0.467, 0.820, 0.235),
            negative = rgb(1.0, 0.412, 0.380),
            swim = rgb(0.278, 0.627, 0.969),
            bike = rgb(0.510, 0.839, 0.235),
            run = rgb(0.965, 0.365, 0.310),
            transition = rgb(0.478, 0.518, 0.573),
            shadow = Color.Black,
            toolbarCircle = Color(0xFF12305C),
            toolbarContent = Color.White,
            tabBar = Color(0xF21A1F27),
            tabSelection = Color(0x26FFFFFF),
            fastFill = rgb(0.965, 0.365, 0.310),
            midFill = rgb(0.267, 0.310, 0.365),
            slowFill = rgb(0.278, 0.627, 0.969),
            fastText = rgb(0.965, 0.365, 0.310),
            midText = rgb(0.729, 0.769, 0.812),
            slowText = rgb(0.451, 0.651, 0.925),
        )
    }
}

/** SF-equivalent scale: three weights, every number tabular. */
object TriType {
    private const val TABULAR = "tnum"
    val athleteName = TextStyle(fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
    val pageTitle = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold)
    val sectionTitle = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.8.sp)
    val cardTitle = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold)
    val body = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.Normal)
    val bodyBold = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold)
    val field = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.Normal)
    val small = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.Normal)
    val smallBold = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold)
    val micro = TextStyle(fontSize = 11.sp, lineHeight = 13.sp, fontWeight = FontWeight.SemiBold)
    val tab = TextStyle(fontSize = 10.sp, lineHeight = 12.sp, fontWeight = FontWeight.Medium)
    val navTitle = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold)

    val statHero = TextStyle(fontSize = 34.sp, lineHeight = 41.sp, fontWeight = FontWeight.Bold, fontFeatureSettings = TABULAR)
    val statLarge = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold, fontFeatureSettings = TABULAR)
    val statMed = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold, fontFeatureSettings = TABULAR)
    val statSmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold, fontFeatureSettings = TABULAR)
}

/** One 4dp scale. Nothing takes an arbitrary padding. */
object TriSpace {
    val x1 = 4.dp
    val x2 = 8.dp
    val x3 = 12.dp
    val x4 = 16.dp
    val x5 = 20.dp
    val x6 = 24.dp
    val x8 = 32.dp
    val x10 = 40.dp
}

object TriGeo {
    val radiusCard = 12.dp
    val radiusInner = 8.dp
    val radiusBadge = 8.dp
    val hairline = 0.5.dp
    val barTrack = 6.dp
    val padInline = TriSpace.x3
    val padCard = TriSpace.x4
    val padPage = TriSpace.x4
    val padSection = TriSpace.x6
    /** The floor for anything a thumb has to hit. */
    val tapTarget = 44.dp
    val navBarHeight = 56.dp
    val tabBarHeight = 64.dp
}

val LocalTriColors = staticCompositionLocalOf { TriColors.light }

object Tri {
    val colors: TriColors @Composable get() = LocalTriColors.current
}

@Composable
fun TriTheme(dark: Boolean, content: @Composable () -> Unit) {
    val colors = if (dark) TriColors.dark else TriColors.light
    val material = if (dark) {
        darkColorScheme(
            primary = colors.sunrise, onPrimary = colors.inkOnSunrise, background = colors.canvas,
            surface = colors.surface, onSurface = colors.ink, onBackground = colors.ink,
            surfaceVariant = colors.surfaceAlt, onSurfaceVariant = colors.inkSecondary,
            outline = colors.hairline, error = colors.negative, surfaceContainerHigh = colors.surface,
            surfaceContainer = colors.surface, surfaceContainerHighest = colors.surfaceAlt,
        )
    } else {
        lightColorScheme(
            primary = colors.sunrise, onPrimary = colors.inkOnSunrise, background = colors.canvas,
            surface = colors.surface, onSurface = colors.ink, onBackground = colors.ink,
            surfaceVariant = colors.surfaceAlt, onSurfaceVariant = colors.inkSecondary,
            outline = colors.hairline, error = colors.negative, surfaceContainerHigh = colors.surface,
            surfaceContainer = colors.surface, surfaceContainerHighest = colors.surfaceAlt,
        )
    }
    MaterialTheme(colorScheme = material) {
        CompositionLocalProvider(LocalTriColors provides colors, content = content)
    }
}

/**
 * Feedback on actions that mean something: selection for a filter or tab,
 * tap for committing, success for an outcome.
 */
object Haptics {
    @Volatile var enabled: Boolean = true
    @Volatile private var view: View? = null

    fun attach(view: View?) {
        this.view = view
    }

    fun selection() = perform(HapticFeedbackConstants.CLOCK_TICK)
    fun tap() = perform(HapticFeedbackConstants.VIRTUAL_KEY)
    fun soft() = perform(HapticFeedbackConstants.CLOCK_TICK)
    fun medium() = perform(HapticFeedbackConstants.CONTEXT_CLICK)
    fun success() = perform(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
    fun warning() = perform(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS)

    private fun perform(constant: Int) {
        if (!enabled) return
        view?.performHapticFeedback(constant)
    }
}

/** Press state for the dip-and-dim style every tappable uses. */
@Composable
fun MutableInteractionSource.pressed(): Boolean = collectIsPressedAsState().value
