package com.jackwallner.ironsplits.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** The header above an inset-grouped section: "2026", "Appearance". */
@Composable
fun GroupHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        title,
        style = TriType.cardTitle.copy(fontSize = 19.sp, lineHeight = 24.sp, fontWeight = FontWeight.SemiBold),
        color = Tri.colors.inkTertiary,
        modifier = modifier
            .padding(start = TriGeo.padPage + TriSpace.x1, end = TriGeo.padPage, top = TriSpace.x4, bottom = TriSpace.x2)
            .semantics { heading() },
    )
}

/**
 * An inset-grouped section: rows on one rounded surface, separated by
 * hairlines. The Compose counterpart of `List(.insetGrouped)`.
 */
@Composable
fun InsetGroup(
    modifier: Modifier = Modifier,
    background: Color = Tri.colors.surface,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .padding(horizontal = TriGeo.padPage)
            .fillMaxWidth()
            .clip(CardShape)
            .background(background),
        content = content,
    )
}

/** One row in an inset group, 44dp minimum, with an optional disclosure chevron. */
@Composable
fun GroupRow(
    modifier: Modifier = Modifier,
    showDivider: Boolean = false,
    chevron: Boolean = false,
    onClick: (() -> Unit)? = null,
    content: @Composable RowScope.() -> Unit,
) {
    val colors = Tri.colors
    Column(modifier.fillMaxWidth()) {
        Row(
            (if (onClick != null) Modifier.triPress(onClick = onClick) else Modifier)
                .fillMaxWidth()
                .heightIn(min = TriGeo.tapTarget)
                .padding(horizontal = TriGeo.padPage, vertical = TriSpace.x2 + TriSpace.x1),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, content = content)
            if (chevron) {
                Spacer(Modifier.width(TriSpace.x2))
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary.copy(alpha = 0.7f), modifier = Modifier.size(20.dp))
            }
        }
        if (showDivider) TriDivider(Modifier.padding(start = TriGeo.padPage))
    }
}

/** Small footnote text inside a group, the way iOS settings explain a control. */
@Composable
fun GroupFootnote(text: String, modifier: Modifier = Modifier, color: Color = Tri.colors.inkTertiary) {
    Box(modifier.fillMaxWidth().padding(horizontal = TriGeo.padPage, vertical = TriSpace.x2)) {
        Text(text, style = TriType.micro, color = color)
    }
}

@Composable
fun GroupSpacer() {
    Spacer(Modifier.heightIn(min = TriSpace.x2).padding(vertical = TriSpace.x1))
}
