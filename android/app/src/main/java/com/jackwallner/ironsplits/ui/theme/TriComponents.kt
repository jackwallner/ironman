package com.jackwallner.ironsplits.ui.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val CardShape = RoundedCornerShape(TriGeo.radiusCard)
val InnerShape = RoundedCornerShape(TriGeo.radiusInner)

/**
 * The app's one button behaviour: everything tappable dips to 0.97 and dims
 * on press, with a light haptic unless the action fires its own.
 */
fun Modifier.triPress(
    enabled: Boolean = true,
    haptic: Boolean = true,
    role: Role = Role.Button,
    label: String? = null,
    onClick: () -> Unit,
): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    val pressed = source.pressed()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, spring(dampingRatio = 0.7f, stiffness = 900f), label = "press")
    val alpha by animateFloatAsState(if (pressed) 0.72f else 1f, spring(dampingRatio = 0.7f, stiffness = 900f), label = "dim")
    this
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
            this.alpha = if (enabled) alpha else 0.5f
        }
        .clickable(
            interactionSource = source,
            indication = null,
            enabled = enabled,
            role = role,
            onClickLabel = label,
        ) {
            if (haptic) Haptics.tap()
            onClick()
        }
}

/** The standard card: surface, hairline, one radius, one elevation. */
@Composable
fun Modifier.triCard(padding: Dp = TriGeo.padCard): Modifier {
    val colors = Tri.colors
    return this
        .shadow(if (colors.isDark) 3.dp else 2.dp, CardShape, ambientColor = colors.shadow, spotColor = colors.shadow)
        .background(colors.surface, CardShape)
        .border(TriGeo.hairline, colors.hairline, CardShape)
        .padding(padding)
}

/** Hairline-bordered surface with no elevation, used for flat rows. */
@Composable
fun Modifier.triOutlined(padding: Dp = TriSpace.x3): Modifier {
    val colors = Tri.colors
    return this
        .background(colors.surface, CardShape)
        .border(TriGeo.hairline, colors.hairline, CardShape)
        .padding(padding)
}

@Composable
fun TriCardColumn(
    modifier: Modifier = Modifier,
    padding: Dp = TriGeo.padCard,
    spacing: Dp = TriSpace.x3,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier.fillMaxWidth().triCard(padding), verticalArrangement = Arrangement.spacedBy(spacing), content = content)
}

/** Small uppercase label that heads a section, with an optional trailing note. */
@Composable
fun TriSectionHeader(title: String, trailing: String? = null, modifier: Modifier = Modifier, color: Color = Tri.colors.inkSecondary) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        Text(
            title.uppercase(),
            style = TriType.sectionTitle,
            color = color,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
        if (trailing != null) {
            Spacer(Modifier.weight(1f).widthIn(min = TriSpace.x2))
            Text(trailing, style = TriType.small, color = Tri.colors.inkTertiary, maxLines = 1)
        }
    }
}

/** Pill for age group, race kind, PB and DNF markers. */
@Composable
fun TriBadge(text: String, color: Color = Tri.colors.inkSecondary, filled: Boolean = false) {
    Text(
        text.uppercase(),
        style = TriType.micro.copy(letterSpacing = 0.5.sp),
        color = if (filled) Tri.colors.inkOnSunrise else color,
        maxLines = 1,
        modifier = Modifier
            .background(if (filled) color else color.copy(alpha = 0.14f), RoundedCornerShape(TriGeo.radiusBadge))
            .padding(horizontal = TriSpace.x2, vertical = TriSpace.x1),
    )
}

/** The one filter pill, 44dp tall. */
@Composable
fun TriChip(title: String, isSelected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = Tri.colors
    val background by animateColorAsState(if (isSelected) colors.deep else colors.surface, label = "chip")
    Box(
        modifier
            .semantics { selected = isSelected }
            .triPress(haptic = false, role = Role.Tab) {
                Haptics.selection()
                onClick()
            }
            .heightIn(min = TriGeo.tapTarget)
            .clip(CircleShape)
            .background(background)
            .then(if (isSelected) Modifier else Modifier.border(TriGeo.hairline, colors.hairline, CircleShape))
            .padding(horizontal = TriSpace.x4),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = TriType.smallBold, color = if (isSelected) colors.inkOnDark else colors.inkSecondary, maxLines = 1)
    }
}

/** A horizontally scrolling row of chips, the way every picker in the app is laid out. */
@Composable
fun ChipRow(modifier: Modifier = Modifier, contentPadding: PaddingValues = PaddingValues(0.dp), content: @Composable RowScope.() -> Unit) {
    Row(
        modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(contentPadding)
            .padding(vertical = TriSpace.x1),
        horizontalArrangement = Arrangement.spacedBy(TriSpace.x2),
        content = content,
    )
}

/** The single primary action shape. */
@Composable
fun TriPrimaryButton(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    isBusy: Boolean = false,
    enabled: Boolean = true,
    shape: androidx.compose.ui.graphics.Shape = CardShape,
    onClick: () -> Unit,
) {
    val colors = Tri.colors
    Row(
        modifier
            .triPress(enabled = enabled && !isBusy, haptic = false, label = title) {
                Haptics.medium()
                onClick()
            }
            .fillMaxWidth()
            .heightIn(min = TriGeo.tapTarget + TriSpace.x1)
            .clip(shape)
            .background(colors.sunrise)
            .padding(vertical = TriSpace.x2, horizontal = TriSpace.x4),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isBusy) {
            CircularProgressIndicator(Modifier.size(18.dp), color = colors.inkOnSunrise, strokeWidth = 2.dp)
            Spacer(Modifier.width(TriSpace.x2))
        } else if (icon != null) {
            Icon(icon, null, tint = colors.inkOnSunrise, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(TriSpace.x2))
        }
        Text(title, style = TriType.bodyBold, color = colors.inkOnSunrise, textAlign = TextAlign.Center)
    }
}

/** A text-only action in the accent colour, 44dp tall. */
@Composable
fun TriTextButton(
    title: String,
    modifier: Modifier = Modifier,
    style: TextStyle = TriType.bodyBold,
    color: Color = Tri.colors.sunrise,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    haptic: Boolean = true,
    centered: Boolean = false,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .heightIn(min = TriGeo.tapTarget)
            .triPress(enabled = enabled, haptic = haptic, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = if (centered) Arrangement.spacedBy(TriSpace.x2, Alignment.CenterHorizontally) else Arrangement.spacedBy(TriSpace.x2),
    ) {
        if (icon != null) Icon(icon, null, tint = color, modifier = Modifier.size(18.dp))
        Text(title, style = style, color = color)
    }
}

/** Empty, error and loading placeholder with one consistent shape. */
@Composable
fun TriPlaceholder(
    icon: ImageVector,
    title: String,
    modifier: Modifier = Modifier,
    message: String? = null,
    actionTitle: String? = null,
    action: (() -> Unit)? = null,
) {
    val colors = Tri.colors
    Column(
        modifier.fillMaxWidth().padding(horizontal = TriSpace.x8, vertical = TriSpace.x8),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(TriSpace.x3),
    ) {
        Icon(icon, null, tint = colors.inkTertiary, modifier = Modifier.size(40.dp))
        Text(title, style = TriType.cardTitle, color = colors.inkSecondary, textAlign = TextAlign.Center)
        if (message != null) Text(message, style = TriType.small, color = colors.inkTertiary, textAlign = TextAlign.Center)
        if (actionTitle != null && action != null) {
            TriTextButton(actionTitle, Modifier.padding(top = TriSpace.x1), haptic = true, onClick = action)
        }
    }
}

/** Big number over a small caption. */
@Composable
fun StatTile(value: String, caption: String, tint: Color = Tri.colors.ink, captionColor: Color = Tri.colors.inkTertiary) {
    Column(
        Modifier
            .widthIn(min = TriSpace.x10 + TriSpace.x8)
            .semantics(mergeDescendants = true) { contentDescription = "$caption, $value" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(TriSpace.x1),
    ) {
        Text(value, style = TriType.statMed, color = tint, maxLines = 1)
        Text(
            caption.uppercase(),
            style = TriType.micro.copy(letterSpacing = 0.4.sp),
            color = captionColor,
            maxLines = 1,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
fun TriDivider(modifier: Modifier = Modifier, color: Color = Tri.colors.divider) {
    Box(modifier.fillMaxWidth().height(TriGeo.hairline.coerceAtLeast(0.5.dp)).background(color))
}

@Composable
fun TriSwitch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, modifier: Modifier = Modifier, label: String? = null) {
    val colors = Tri.colors
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        modifier = modifier.then(if (label != null) Modifier.semantics { contentDescription = label } else Modifier),
        colors = SwitchDefaults.colors(
            checkedThumbColor = Color.White,
            checkedTrackColor = colors.sunrise,
            checkedBorderColor = colors.sunrise,
            uncheckedThumbColor = Color.White,
            uncheckedTrackColor = colors.surfaceSunk,
            uncheckedBorderColor = colors.hairline,
        ),
    )
}

/** An iOS-style segmented control, used for Tips mode and Appearance. */
@Composable
fun <T> SegmentedControl(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    modifier: Modifier = Modifier,
    onDark: Boolean = false,
    onSelect: (T) -> Unit,
) {
    val colors = Tri.colors
    val track = if (onDark) Color.White.copy(alpha = 0.14f) else colors.surfaceSunk
    val thumb = if (onDark) Color.White.copy(alpha = 0.22f) else colors.surface
    val textOn = if (onDark) colors.inkOnDark else colors.ink
    val textOff = if (onDark) colors.inkOnDark.copy(alpha = 0.8f) else colors.inkSecondary
    Row(
        modifier.clip(CircleShape).background(track).padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            val background by animateColorAsState(if (isSelected) thumb else Color.Transparent, label = "segment")
            Box(
                Modifier
                    .weight(1f)
                    .heightIn(min = 36.dp)
                    .clip(CircleShape)
                    .background(background)
                    .semantics { this.selected = isSelected }
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        role = Role.Tab,
                    ) {
                        if (!isSelected) {
                            Haptics.selection()
                            onSelect(option)
                        }
                    }
                    .padding(horizontal = TriSpace.x3),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label(option),
                    style = if (isSelected) TriType.smallBold.copy(fontSize = 15.sp) else TriType.small.copy(fontSize = 15.sp),
                    color = if (isSelected) textOn else textOff,
                    maxLines = 1,
                )
            }
        }
    }
}

/** A circular icon badge, like the accent circles on intro cards. */
@Composable
fun IconCircle(icon: ImageVector, tint: Color, size: Dp = TriSpace.x8, iconSize: Dp = 18.dp) {
    Box(Modifier.size(size).background(tint.copy(alpha = 0.14f), CircleShape), contentAlignment = Alignment.Center) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(iconSize))
    }
}
