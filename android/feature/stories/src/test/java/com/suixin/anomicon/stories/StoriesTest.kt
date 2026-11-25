package com.suixin.anomicon.stories

import org.jsoup.Jsoup
import org.junit.Assert.*
import org.junit.Test

class StoriesTest {
    @Test fun followsWikiSequenceAndReturnsToUnfinishedChapter() {
        assertEquals(19, mainline.size)
        assertEquals("scp-055", resumeTale(null, emptySet()).slug)
        assertEquals("we-need-to-talk-about-fifty-five", resumeTale("scp-055", setOf("scp-055")).slug)
        assertEquals("scp-2256", resumeTale("scp-2256", emptySet()).slug)
        assertEquals("in-the-trenches-with-the-dead", resumeTale("scp-2111", setOf("scp-2111")).slug)
    }
    @Test fun directoryDeduplicatesAndSupportsTitleAndSlugSearch() {
        val entries = parseDirectory(Jsoup.parse("""<div id="page-content"><a href="/tales-by-page-name">目录</a>
            <a href="/test-tale">故事一</a><a href="/test-tale">重复行</a><a href="/second">故事二</a></div>"""))
        assertEquals(2, entries.size)
        assertEquals(listOf(Tale("test-tale", "故事一")), filterDirectory(entries, "T", "TALE"))
        assertEquals("second", filterDirectory(entries, "", "故事二").single().slug)
    }
}
