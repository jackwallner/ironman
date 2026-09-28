package com.jackwallner.ironsplits.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val lightColors = lightColorScheme(
    primary = Color(0xFF112B43),
    onPrimary = Color(0xFFFFFFFF),
    secondary = Color(0xFFF07852),
    onSecondary = Color(0xFFFFFFFF),
    background = Color(0xFFF4F6F8),
    onBackground = Color(0xFF172A3A),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF172A3A),
    surfaceVariant = Color(0xFFEBF0F4),
    onSurfaceVariant = Color(0xFF506274),
    outline = Color(0xFFD4DDE5),
    error = Color(0xFFB33131),
)

private val darkColors = darkColorScheme(
    primary = Color(0xFF183B5C),
    onPrimary = Color(0xFFF9FBFD),
    secondary = Color(0xFFEF8967),
    onSecondary = Color(0xFF24140F),
    background = Color(0xFF0B1723),
    onBackground = Color(0xFFE6EDF3),
    surface = Color(0xFF142536),
    onSurface = Color(0xFFE6EDF3),
    surfaceVariant = Color(0xFF1D3144),
    onSurfaceVariant = Color(0xFFB3C1CE),
    outline = Color(0xFF344A5E),
    error = Color(0xFFFF8A80),
)

@Composable
fun IronSplitsTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) darkColors else lightColors,
        typography = MaterialTheme.typography.copy(
            headlineLarge = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Bold, fontSize = 28.sp, lineHeight = 34.sp),
            headlineMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Bold, fontSize = 22.sp, lineHeight = 28.sp),
            titleLarge = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 22.sp),
            titleMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, lineHeight = 20.sp),
            bodyLarge = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Normal, fontSize = 16.sp, lineHeight = 23.sp),
            bodyMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Normal, fontSize = 14.sp, lineHeight = 20.sp),
            labelLarge = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, lineHeight = 18.sp),
            labelMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, lineHeight = 16.sp),
        ),
        content = content,
    )
}
