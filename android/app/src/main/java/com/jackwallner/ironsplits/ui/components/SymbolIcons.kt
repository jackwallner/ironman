package com.jackwallner.ironsplits.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.Backpack
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.QuestionMark
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.Thunderstorm
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.Waves
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.ui.graphics.vector.ImageVector

/** The hosted Ask Pattie tree names SF Symbols; these are their closest Material glyphs. */
fun symbolIcon(symbol: String): ImageVector = when (symbol) {
    "figure.mixed.cardio" -> Icons.Filled.Accessibility
    "stopwatch" -> Icons.Filled.Timer
    "medal.fill" -> Icons.Filled.EmojiEvents
    "flag.checkered" -> Icons.Filled.SportsScore
    "sunrise.fill" -> Icons.Filled.WbTwilight
    "figure.open.water.swim" -> Icons.Filled.Pool
    "water.waves" -> Icons.Filled.Waves
    "bag.fill" -> Icons.Filled.Backpack
    "arrow.triangle.2.circlepath" -> Icons.Filled.Autorenew
    "bicycle" -> Icons.AutoMirrored.Filled.DirectionsBike
    "wrench.and.screwdriver.fill" -> Icons.Filled.Build
    "cloud.rain.fill" -> Icons.Filled.Thunderstorm
    "shoeprints.fill" -> Icons.AutoMirrored.Filled.DirectionsWalk
    "figure.run" -> Icons.AutoMirrored.Filled.DirectionsRun
    "drop.fill" -> Icons.Filled.WaterDrop
    else -> Icons.Filled.QuestionMark
}
