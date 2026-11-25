package com.suixin.anomicon.core.data

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class FlutterSnapshotTest {
    @get:Rule val temp = TemporaryFolder()

    @Test fun restoresSearchOrderAndContentIdentities() {
        val prefs = mapOf("flutter.discovery.searchHistory" to "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu![\"CN-2000\",\"173\"]",
            "flutter.history" to """[{"id":"scp-173","pixelOffset":55,"completed":true}]""",
            "flutter.activitySegments" to """[{"segmentId":"main:scp-173:1:0","activeMs":60}]""")
        val rows = FlutterSnapshot(prefs, temp.root).items()
        assertEquals(listOf("CN-2000", "173"), rows.filter { it.collection == "discovery.searchHistory" }.map { it.id })
        assertEquals("scp-173", rows.single { it.collection == "history" }.id)
        assertTrue(rows.single { it.collection == "history" }.payload.contains("pixelOffset"))
    }

    @Test fun expandsCommittedBundleAndIndexesReusableCache() {
        val dir = temp.newFolder("offline-articles", "v1")
        val bundle = File(dir, digest("main:scp-002") + ".article")
        bundle.writeText("""{"content":{"id":"scp-002","title":"生活室","kind":"scp"},"savedAt":1234}
{"html":"<p>正文</p>","images":{"https://example.org/pic":"AAECAw=="}}""")
        File(dir, ".staging-x").mkdir()
        val cache = temp.newFolder("content-cache")
        val name = digest("article:main:scp-002") + ".html"
        File(cache, name).writeText("正文"); File(cache, "$name.meta").writeText("1234")
        val snapshot = FlutterSnapshot(emptyMap<String, String>(), temp.root)
        assertEquals(listOf(bundle), snapshot.offlineFiles())
        val output = temp.newFolder("native")
        val (article, images) = importArticle(bundle, output)
        assertEquals("<p>正文</p>", File(output, article.htmlPath).readText())
        assertArrayEquals(byteArrayOf(0, 1, 2, 3), File(output, images.single().path).readBytes())
        assertEquals(CacheFile(name, 1234, 6), snapshot.cacheIndex().single())
        assertEquals(article to images, importArticle(bundle, output))
    }
}
