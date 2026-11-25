package com.suixin.anomicon.feature.web

import org.junit.Assert.assertEquals
import org.junit.Test

class ReaderTrackingTest {
    @Test fun foregroundCheckpointsExcludeIdleAndBackgroundTime() {
        val written = mutableListOf<Pair<Long, Long>>()
        val clock = ReadingClock { start, ms -> written += start to ms }
        clock.resume(0, 1000)
        clock.checkpoint(30_000)
        clock.checkpoint(100_000)
        clock.interact(120_000)
        clock.pause(122_000)
        clock.interact(130_000)
        clock.resume(150_000, 151_000)
        clock.pause(151_000)
        assertEquals(listOf(1000L to 30_000L, 31_000L to 60_000L, 121_000L to 2000L,
            151_000L to 1000L), written)
    }

    @Test fun restoreAcrossViewportSizesAndFromLegacyOffset() {
        val saved = ReaderPosition.at(450, 900, 3f)
        assertEquals(150, saved.offset)
        assertEquals(300, saved.restore(600, 2f))
        assertEquals(320, ReaderPosition(160, 0f).restore(1000, 2f))
    }
}
