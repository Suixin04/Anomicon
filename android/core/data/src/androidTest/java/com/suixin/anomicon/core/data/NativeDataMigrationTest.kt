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
        data.setThemeMode(ThemeMode.LIGHT)
        data.migrateIfNeeded()
        assertEquals(ThemeMode.LIGHT, data.settings.first().themeMode)
    }
}
