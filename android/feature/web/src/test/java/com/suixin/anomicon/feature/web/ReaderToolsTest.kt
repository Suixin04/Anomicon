package com.suixin.anomicon.feature.web

import com.suixin.anomicon.core.network.parseWikiPreview
import org.junit.Assert.*
import org.junit.Test

class ReaderToolsTest {
    @Test fun pageMetadataCaptionAndJumpTargetsComeFromSource() {
        val preview = parseWikiPreview("""
            <div class='page-tags'><a>传染性</a><a>euclid</a></div><span class='rate-points'>评分: +615</span>
            <div id='page-content'><figure><img src='/049.jpg' alt='档案照片'><figcaption>医生在工作。</figcaption></figure>
            <h2>附录</h2><p>收容措施：详见观察记录。</p><audio></audio></div>
        """.trimIndent(), "scp-049")
        assertEquals("Euclid", preview.objectClass)
        assertEquals("+615", preview.rating)
        assertTrue(preview.hasInteractiveContent)
        assertEquals(listOf("传染性", "euclid"), preview.tags)
        assertEquals(listOf(1 to "附录", 2 to "收容措施"), readerTargets(ReaderTool.Contents, preview, ""))
        assertEquals(listOf(0 to "医生在工作。"), readerTargets(ReaderTool.Find, preview, "医生"))
        assertTrue(readerTargets(ReaderTool.Find, preview, "不存在").isEmpty())
    }
}
