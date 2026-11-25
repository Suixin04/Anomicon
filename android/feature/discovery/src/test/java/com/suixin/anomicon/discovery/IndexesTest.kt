package com.suixin.anomicon.discovery

import java.io.File
import java.util.zip.GZIPInputStream
import org.junit.Assert.*
import org.junit.Test

class IndexesTest {
    private fun snapshot(key: String) = File("src/main/assets/discovery/$key.html.gz").inputStream().use { GZIPInputStream(it).bufferedReader().use { r -> r.readText() } }
    @Test fun allSeriesHaveSearchableEntriesFromTheirBranch() {
        assertEquals(15, series.size)
        val rows = series.flatMap { descriptor ->
            parseIndex(descriptor.key, snapshot(descriptor.key)).also { entries ->
                assertTrue(descriptor.key, entries.size > 100)
                assertTrue(descriptor.key, entries.all { it.id.startsWith("scp-cn-") == descriptor.cn })
            }
        }
        assertEquals("scp-002", matches(rows, "002").first().id)
        assertEquals("scp-003", matches(rows, "生物母版").first().id)
        assertEquals("scp-cn-3260", matches(rows, "cn-3260").first().id)
        assertTrue(matches(rows, "众海").any { it.id == "scp-cn-3260" })
        val first = dailyDeck(rows, 1)
        assertEquals(6,first.distinct().size)
        assertEquals(2,first.count { it.id.startsWith("scp-cn-") })
        assertEquals(first,dailyDeck(rows,1)); assertNotEquals(first,dailyDeck(rows,2))
    }
    @Test fun coldStartDeckHasSixAttributedEntriesAndLocalFirstCover() {
        for (day in 1..31) {
            val cards = dailyDeck(starter, day).sortedBy { it.id !in localCovers }
            assertEquals(6, cards.distinct().size)
            assertTrue(cards.all { it.title.isNotBlank() && it.detail.isNotBlank() })
            assertTrue(cards.first().id in localCovers)
        }
        for ((key, cover) in localCovers) {
            assertTrue(File("src/main/res/drawable-nodpi/cover_${key.removePrefix("scp-")}.jpg").length() > 0)
            assertTrue(cover.second > 0f)
        }
    }
    @Test fun officialFeedKeepsArticleAndScoreTogether() {
        val rows = parseIndex("top-rated-pages",snapshot("top-rated-pages"))
        assertEquals("scp-cn-2000",rows.first().id)
        assertTrue(rows.first().detail.toInt() > 5000)
        feeds.keys.forEach { assertTrue(parseIndex(it,snapshot(it)).size >= 5) }
    }
    @Test fun articlePreviewFindsDescriptionAndUpgradesImageToHttps() {
        val p = parsePreview("scp-002",snapshot("scp-002"))
        assertTrue(p.text.contains("60")); assertTrue(p.image!!.startsWith("https://"))
    }
    @Test fun directSearchPreservesWikiAnchorAndNormalizesShortIds() {
        assertEquals("scp-cn-002-j", directTarget("CN 2-J"))
        assertEquals("scp-fr-003", directTarget("SCP FR 3"))
        assertEquals("scp-173", directTarget("173"))
        assertEquals("we-need-to-talk-about-fifty-five#Section2", directTarget("scp-wiki.wikidot.com/we-need-to-talk-about-fifty-five#Section2"))
        assertNull(directTarget("https://example.org/scp-173"))
    }
    @Test fun bundledJokesStoriesAndRecentDatesAreSearchable() {
        for (key in jokeSources.keys + taleSources) {
            val entries = parseIndex(key, snapshot(key))
            assertTrue(key, entries.size > 10)
            assertTrue(key, entries.none { it.id == key || it.id == "main" })
        }
        val recent = parseIndex("most-recently-created-cn", snapshot("most-recently-created-cn"))
        assertNotNull(recentDate(recent.first().detail))
    }
}
