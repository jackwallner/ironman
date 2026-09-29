package com.jackwallner.ironsplits.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.jackwallner.ironsplits.data.RaceNote
import com.jackwallner.ironsplits.ui.theme.GroupHeader
import com.jackwallner.ironsplits.ui.theme.GroupRow
import com.jackwallner.ironsplits.ui.theme.InsetGroup
import com.jackwallner.ironsplits.ui.theme.ToolbarTextButton
import com.jackwallner.ironsplits.ui.theme.Tri
import com.jackwallner.ironsplits.ui.theme.TriAlert
import com.jackwallner.ironsplits.ui.theme.TriGeo
import com.jackwallner.ironsplits.ui.theme.TriScreen
import com.jackwallner.ironsplits.ui.theme.TriSheet
import com.jackwallner.ironsplits.ui.theme.TriSpace
import com.jackwallner.ironsplits.ui.theme.TriType
import com.jackwallner.ironsplits.ui.theme.bottomContentPadding

/** Sheet for editing one race's notes. Unsaved changes are never lost to a stray swipe. */
@Composable
fun RaceNoteEditorSheet(visible: Boolean, initial: RaceNote, raceName: String, onClose: () -> Unit, onSave: (RaceNote) -> Unit) {
    var note by remember(visible, initial.resultId) { mutableStateOf(initial) }
    var confirmingDiscard by remember { mutableStateOf(false) }
    var confirmingDelete by remember { mutableStateOf(false) }
    val dirty = !note.sameContent(initial)

    fun requestDismiss() {
        if (dirty) confirmingDiscard = true else onClose()
    }

    TriSheet(visible = visible, onDismiss = onClose, onRequestDismiss = ::requestDismiss) {
        TriScreen(
            title = raceName,
            inSheet = true,
            leading = { ToolbarTextButton("Cancel", onClick = ::requestDismiss) },
            trailing = {
                ToolbarTextButton("Save", bold = true) {
                    onSave(note)
                    onClose()
                }
            },
        ) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottomContentPadding(TriSpace.x6))) {
                NoteSection("Conditions", note.conditions, "Heat, wind, water and course conditions") { note = note.copy(conditions = it) }
                NoteSection("Nutrition", note.nutrition, "What you took, and when") { note = note.copy(nutrition = it) }
                NoteSection("Gear", note.gear, "Wetsuit, wheels, shoes") { note = note.copy(gear = it) }
                NoteSection("Notes", note.notes, "How it went", minHeight = 120.dp) { note = note.copy(notes = it) }
                if (!initial.isEmpty) {
                    Box(Modifier.padding(top = TriSpace.x6)) {
                        InsetGroup {
                            GroupRow(onClick = { confirmingDelete = true }) {
                                Text("Delete this race note", style = TriType.body, color = Tri.colors.negative)
                            }
                        }
                    }
                }
            }
        }
        if (confirmingDiscard) {
            TriAlert(
                title = "Discard unsaved note changes?",
                message = null,
                confirmTitle = "Discard changes",
                dismissTitle = "Keep editing",
                destructive = true,
                onConfirm = {
                    confirmingDiscard = false
                    onClose()
                },
                onDismiss = { confirmingDiscard = false },
            )
        }
        if (confirmingDelete) {
            TriAlert(
                title = "Delete this race note?",
                message = null,
                confirmTitle = "Delete note",
                dismissTitle = "Keep note",
                destructive = true,
                onConfirm = {
                    confirmingDelete = false
                    onSave(RaceNote(initial.resultId))
                    onClose()
                },
                onDismiss = { confirmingDelete = false },
            )
        }
    }
}

@Composable
private fun NoteSection(title: String, value: String, placeholder: String, minHeight: Dp = 22.dp, onChange: (String) -> Unit) {
    val colors = Tri.colors
    GroupHeader(title)
    InsetGroup {
        Box(Modifier.fillMaxWidth().padding(horizontal = TriGeo.padPage, vertical = TriSpace.x3).heightIn(min = minHeight)) {
            if (value.isEmpty()) Text(placeholder, style = TriType.body, color = colors.inkTertiary.copy(alpha = 0.7f))
            BasicTextField(
                value = value,
                onValueChange = onChange,
                textStyle = TriType.body.copy(color = colors.ink),
                cursorBrush = SolidColor(colors.sunrise),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                modifier = Modifier.fillMaxWidth().heightIn(min = minHeight).testTag("note-${title.lowercase()}"),
            )
        }
    }
}
