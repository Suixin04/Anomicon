package com.suixin.anomicon.core.data

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class NativeDataMigrationTest {
    @Test fun importOncePreservesNativeEdits() = runBlocking {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val legacy = context.getSharedPreferences("FlutterSharedPreferences", 0)
        assertTrue(legacy.edit()
            .putString("flutter.settings", """{"themeMode":"dark","immersiveMaterialEnabled":false,"hapticEnabled":false,"fontSize":20}""")
            .putString("flutter.favorites", """[{"id":"scp-173","kind":"scp","title":"雕像"}]""")
            .putString("flutter.foundation.assessments", """{"crv":{"firstPassedAt":42}}""")
            .commit())
        val documents = File(context.applicationInfo.dataDir, "app_flutter")
        val cache = File(documents, "content-cache").apply { mkdirs() }
        val cached = File(cache, digest("article:main:scp-173") + ".html").apply { writeText("正文") }
        File(cache, "${cached.name}.meta").writeText("10")
        val offline = File(documents, "offline-articles/v1").apply { mkdirs() }
        File(offline, digest("main:scp-173") + ".article").writeText("""{"content":{"id":"scp-173","title":"雕像","kind":"scp"},"savedAt":123}
{"html":"<p>已保存</p>","images":{"https://example.org/a.png":"AAEC"}}""")
        val data = NativeData.open(context)
        data.migrateIfNeeded()
        assertEquals(AppSettings(ThemeMode.DARK, false, false, 20f, 1.6f), data.settings.first())
        assertEquals("scp-173", data.library.items("favorites").first().single().id)
        assertTrue(data.assessments.first().contains("firstPassedAt"))
        assertEquals("正文", data.cachedFile("article:main:scp-173", "html")!!.readText())
        val article = data.library.shelf().first().single()
        assertEquals("<p>已保存</p>", data.offlineFile(article.htmlPath).readText())
        assertArrayEquals(byteArrayOf(0, 1, 2), data.offlineFile(data.library.images(article.id).single().path).readBytes())
        val url = "https://scp-wiki.wdfiles.com/local--files/scp-173/173.jpg"
        val html = "<p>更新正文</p>"
        assertEquals(1, data.saveOffline(article.id, "雕像", html, listOf(url)) { _, _ -> byteArrayOf(3, 4) })
        val updated = data.library.revision(article.id)!!
        assertTrue(updated.article.htmlPath.startsWith("native/"))
        assertTrue(updated.images.single().path.startsWith("native/"))
        val alias = File(context.filesDir, "offline")
        val previouslyGeneratedPath = data.offlineFile(updated.article.htmlPath).relativeTo(alias).path
        assertEquals(html, data.offlineFile(previouslyGeneratedPath).readText())
        assertEquals(html, data.offlineFile(updated.article.htmlPath).readText())
        assertEquals(listOf(url), updated.images.map { it.url })
        assertArrayEquals(byteArrayOf(3, 4), data.offlineFile(updated.images.single().path).readBytes())
        try {
            data.saveOffline(article.id, "雕像", "<p>新版本</p>", listOf(url)) { _, _ -> null }
            fail("缺图的更新不应发布")
        } catch (_: java.io.IOException) {
            assertEquals(updated, data.library.revision(article.id))
        }
        data.setThemeMode(ThemeMode.LIGHT)
        data.migrateIfNeeded()
        assertEquals(ThemeMode.LIGHT, data.settings.first().themeMode)
    }
}
