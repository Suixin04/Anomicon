package com.suixin.anomicon.core.data

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate

class ResearchProfileTest {
    @Test fun dailyCapAndArticleRewardShareTheSameCreditedTime() {
        val minutes = MINUTE_MS
        val segments = listOf(Activity("a", 0, 180 * minutes, 180 * minutes, 0),
            Activity("b", 180 * minutes, 181 * minutes, minutes, 0))
        val profile = researchProfile(segments, 15)
        assertEquals(180 * minutes, profile.totalMs)
        assertEquals(1, profile.researched)
        assertEquals(203L, profile.xp)
        assertEquals(6, profile.level)
        assertEquals("档案助理", profile.rank)
    }
    @Test fun oneArticleAcrossLocalMidnightGetsOneCompletionBonus() {
        val midnight = 16 * 60 * MINUTE_MS
        val profile = researchProfile(listOf(Activity("a", midnight - MINUTE_MS, midnight + MINUTE_MS, MINUTE_MS, 480)), 0)
        assertEquals(30_000L, profile.daily[LocalDate.ofEpochDay(0)])
        assertEquals(30_000L, profile.daily[LocalDate.ofEpochDay(1)])
        assertEquals(9L, profile.xp)
    }
    @Test fun importedBlockProgressAndWebOffsetRemainAvailable() {
        val row = LibraryItem("history", "scp-173", 0, """{"title":"SCP-173","blockCount":5,"scrollOffset":2,"webPixelOffset":500}""")
        assertEquals(ReadingEntry("scp-173", "SCP-173", 500, .5f), readEntry(row))
    }
}
