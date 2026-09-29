package com.jackwallner.ironsplits.data

import com.jackwallner.ironsplits.model.RaceResult

/** The last four event fields, so backing into a race detail is instant. */
class RaceFieldCache {
    private val entries = LinkedHashMap<String, List<RaceResult>>()

    @Synchronized
    fun results(eventId: String): List<RaceResult>? = entries[eventId]

    @Synchronized
    fun store(results: List<RaceResult>, eventId: String) {
        entries.remove(eventId)
        entries[eventId] = results
        while (entries.size > 4) entries.remove(entries.keys.first())
    }

    @Synchronized
    fun clear() = entries.clear()
}
