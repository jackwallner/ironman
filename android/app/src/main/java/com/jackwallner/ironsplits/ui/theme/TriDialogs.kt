package com.jackwallner.ironsplits.ui.theme

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable

/** A confirmation dialog with one confirming action, destructive when it removes something. */
@Composable
fun TriAlert(
    title: String,
    message: String?,
    confirmTitle: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    dismissTitle: String? = "Cancel",
    destructive: Boolean = false,
) {
    val colors = Tri.colors
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        titleContentColor = colors.ink,
        textContentColor = colors.inkSecondary,
        title = { Text(title, style = TriType.cardTitle) },
        text = message?.let { { Text(it, style = TriType.body.copy(fontSize = TriType.small.fontSize.times(1.15f))) } },
        confirmButton = {
            TextButton(onClick = {
                if (destructive) Haptics.warning() else Haptics.tap()
                onConfirm()
            }) {
                Text(confirmTitle, style = TriType.bodyBold, color = if (destructive) colors.negative else colors.sunrise)
            }
        },
        dismissButton = dismissTitle?.let {
            {
                TextButton(onClick = onDismiss) {
                    Text(it, style = TriType.body, color = colors.inkSecondary)
                }
            }
        },
    )
}
