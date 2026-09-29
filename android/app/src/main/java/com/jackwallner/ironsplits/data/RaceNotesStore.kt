package com.jackwallner.ironsplits.data

import android.content.Context
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject

/** The athlete's own account of a race. Stored on this device and never sent anywhere. */
data class RaceNote(
    val resultId: String,
    val conditions: String = "",
    val nutrition: String = "",
    val gear: String = "",
    val notes: String = "",
    val updatedAt: Long = System.currentTimeMillis(),
) {
    val isEmpty: Boolean get() = listOf(conditions, nutrition, gear, notes).all { it.isBlank() }

    /** Same content, ignoring when it was saved. */
    fun sameContent(other: RaceNote): Boolean =
        conditions == other.conditions && nutrition == other.nutrition && gear == other.gear && notes == other.notes

    /** "Conditions: ...  |  Notes: ..." or null. */
    val labelledText: String?
        get() = fields.mapNotNull { (label, value) -> value.trim().takeIf { it.isNotEmpty() }?.let { "$label: $it" } }
            .takeIf { it.isNotEmpty() }?.joinToString("  |  ")

    val fields: List<Pair<String, String>>
        get() = listOf("Conditions" to conditions, "Nutrition" to nutrition, "Gear" to gear, "Notes" to notes)
}

class RaceNotesStore(context: Context) {
    private val file = File(context.filesDir, "race-notes.json")
    private val _notes = MutableStateFlow(load())
    val notes: StateFlow<Map<String, RaceNote>> = _notes.asStateFlow()

    fun note(resultId: String): RaceNote = _notes.value[resultId] ?: RaceNote(resultId)

    fun hasNote(resultId: String): Boolean = _notes.value[resultId]?.isEmpty == false

    fun save(note: RaceNote) {
        val updated = note.copy(updatedAt = System.currentTimeMillis())
        val next = _notes.value.toMutableMap()
        if (updated.isEmpty) next.remove(note.resultId) else next[note.resultId] = updated
        _notes.value = next
        persist(next)
    }

    fun clearForTesting() {
        _notes.value = emptyMap()
        file.delete()
    }

    private fun persist(notes: Map<String, RaceNote>) {
        val json = JSONObject()
        notes.forEach { (id, note) ->
            json.put(
                id,
                JSONObject()
                    .put("resultID", note.resultId)
                    .put("conditions", note.conditions)
                    .put("nutrition", note.nutrition)
                    .put("gear", note.gear)
                    .put("notes", note.notes)
                    .put("updatedAt", note.updatedAt),
            )
        }
        runCatching {
            val temp = File(file.parentFile, "race-notes.json.tmp")
            temp.writeText(json.toString())
            temp.renameTo(file)
        }
    }

    private fun load(): Map<String, RaceNote> = runCatching {
        if (!file.exists()) return emptyMap()
        val json = JSONObject(file.readText())
        json.keys().asSequence().mapNotNull { key ->
            val item = json.optJSONObject(key) ?: return@mapNotNull null
            key to RaceNote(
                resultId = item.optString("resultID", key),
                conditions = item.optString("conditions"),
                nutrition = item.optString("nutrition"),
                gear = item.optString("gear"),
                notes = item.optString("notes"),
                updatedAt = item.optLong("updatedAt"),
            )
        }.toMap()
    }.getOrDefault(emptyMap())
}
