package com.suixin.anomicon.core.network

import java.io.IOException
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.*
import org.junit.Test

class WikiRepositoryTest {
    private val html = """
        <div id='page-title'>SCP-002</div>
        <p>导航</p><div id='page-content'><div class='page-rate-widget-box'>评分</div>
        <h2>描述</h2><p>参见 <a href='/scp-003'>生物母版</a>。</p>
        <img alt='生活室' src='http://scp-wiki.wdfiles.com/local--files/scp-002/photo.jpg'>
        <table><tr><th>时间</th><th>观测</th></tr><tr><td>10:00</td><td>记录</td></tr></table></div>
    """.trimIndent()

    @Test fun resolvesArticleNumberOrChineseWikiUrl() {
        assertEquals("scp-002", wikiSlug("2"))
        assertEquals("scp-cn-2000", wikiSlug("CN-2000"))
        assertEquals("scp-002", wikiSlug("https://scp-wiki-cn.wikidot.com/scp-002#toc"))
        assertNull(wikiSlug("https://example.org/scp-002"))
    }

    @Test fun extractsBodyLinksImageAndTableInSourceOrder() {
        val preview = parseWikiPreview(html, "scp-002")
        assertEquals(listOf(
            PreviewBlock.Heading("描述"),
            PreviewBlock.Paragraph("参见 生物母版。", listOf(WikiLink(3, 7, "scp-003"))),
            PreviewBlock.Image("https://scp-wiki.wdfiles.com/local--files/scp-002/photo.jpg", "生活室"),
            PreviewBlock.Table(listOf(listOf("时间", "观测"), listOf("10:00", "记录")))
        ), preview.blocks)
        assertEquals(preview, Json.decodeFromString<WikiPreview>(Json.encodeToString(preview)))
    }

    @Test fun foldedCreditsDoNotDisplaceTheArticlePhoto() {
        val page = parseWikiPreview("""<div id='page-content'>
            <div class='info-container'><div class='collapsible-block-content'><p>作者示例</p><div class='translation_block'>其他语言</div><div class='u-faq'>常见问题</div></div></div>
            <div class='scp-image-block'><img src='/photo.jpg'><div class='scp-image-caption'>图注</div></div>
            <div class='licensebox'><div class='collapsible-block-content'>CC BY-SA</div></div></div>""", "scp-049")
        assertEquals("图注", (page.blocks.single() as PreviewBlock.Image).caption)
        assertEquals("作者示例\n\nCC BY-SA", page.credits)
        assertNull(page.rating)
        assertEquals("疫医", seriesSubtitle("<div id='page-content'><ul><li><a href='/scp-049'>SCP-049</a> - 疫医</li></ul></div>", "scp-049"))
    }

    @Test fun archiveRestoresBodyImageAndAttributionFromSameRevision() {
        val source = html.replace("</table>", "</table><div class='licensebox'><div class='collapsible-block-content'><a href='/author'>署名</a> · CC BY-SA</div></div>")
        val current = parseWikiPreview(source, "scp-002")
        val saved = parseWikiPreview("<main id='page-content'>${current.offlineHtml}</main>", "scp-002")
        assertEquals(current.blocks, saved.blocks)
        assertTrue(saved.credits.contains("署名 · CC BY-SA"))
        assertTrue(saved.credits.contains(WIKI_BASE + "scp-002"))
        assertTrue(current.offlineHtml.contains(WIKI_BASE + "author"))
    }

    @Test fun archiveImagesUseTrustedHttpsHostsAndSupportedRasterBytes() {
        assertNotNull(trustedImageUrl("https://scp-wiki.wdfiles.com/local--files/scp-049/photo.jpg"))
        for (url in listOf("http://scp-wiki.wdfiles.com/a", "https://example.net/a", "https://scp-wiki.wdfiles.com:8123/a", "https://user@scp-wiki.wdfiles.com/a"))
            assertNull(trustedImageUrl(url))
        assertTrue(isRasterImage(byteArrayOf(-1,-40,-1) + ByteArray(12)))
        assertFalse(isRasterImage("<html>missing image</html>".toByteArray()))
    }

    @Test fun repositoryRequestsNormalizedPageAndPropagatesHttpFailure() = runBlocking {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setBody(html))
            server.enqueue(MockResponse().setResponseCode(503))
            val repo = WikiRepository(WikiRepository.service(server.url("/").toString()))
            assertEquals("SCP-002", repo.preview("2").title)
            assertEquals("/scp-002", server.takeRequest().path)
            try {
                repo.preview("2")
                fail("Expected HTTP failure")
            } catch (error: IOException) {
                assertEquals("Wiki HTTP 503", error.message)
            }
        }
    }
}
