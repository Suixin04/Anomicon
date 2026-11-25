package com.suixin.anomicon.discovery

import android.content.Context
import com.suixin.anomicon.core.data.NativeData
import com.suixin.anomicon.core.network.WIKI_BASE
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import org.jsoup.Jsoup

internal class DiscoveryStore(private val context: Context) {
    val data = NativeData.open(context)
    private val folder = File(context.cacheDir, "discovery-pages").apply { mkdirs() }
    private val seeds = context.assets.list("discovery")!!.toSet()
    private val permits = Semaphore(4)
    private suspend fun local(key: String): String? = withContext(Dispatchers.IO) {
        val file = File(folder, key)
        when {
            file.isFile -> file.readText()
            "$key.html" in seeds -> context.assets.open("discovery/$key.html").bufferedReader().use { it.readText() }
            else -> data.cachedFile("article:main:$key", "html")?.readText()
        }
    }
    private suspend fun <T> fetch(key: String, parser: (String,String)->T): T = permits.withPermit { withContext(Dispatchers.IO) {
        val html = Jsoup.connect(WIKI_BASE + key).userAgent("Anomicon-Android").timeout(15000).execute().body()
        val value = parser(key, html)
        val temp = File.createTempFile("page-", ".tmp", folder)
        try { temp.writeText(html); Files.move(temp.toPath(), File(folder,key).toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING) } finally { temp.delete() }
        value
    } }
    suspend fun index(key: String, refresh: Boolean = false): List<Entry> = withContext(Dispatchers.Default) {
        if (!refresh) local(key)?.let { return@withContext parseIndex(key,it) }
        fetch(key, ::parseIndex)
    }
    suspend fun preview(key: String): Preview = withContext(Dispatchers.Default) {
        local(key)?.let { parsePreview(key,it) } ?: fetch(key, ::parsePreview)
    }
    suspend fun all() = series.flatMap { index(it.key) }.distinctBy { it.id }
    suspend fun image(url: String): Any = data.cachedFile("image:$url", "img") ?: url
}
