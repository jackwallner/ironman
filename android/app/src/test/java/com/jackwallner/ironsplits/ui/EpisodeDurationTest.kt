package com.jackwallner.ironsplits.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EpisodeDurationTest {
    @Test
    fun hidesMissingOrInvalidDurations() {
        assertNull(formatEpisodeDuration(0))
        assertNull(formatEpisodeDuration(-1))
    }

    @Test
    fun formatsSecondsAndMinuteBoundaries() {
        assertEquals("42 sec", formatEpisodeDuration(42))
        assertEquals("1 min", formatEpisodeDuration(60))
        assertEquals("1 min 2 sec", formatEpisodeDuration(62))
    }
}
