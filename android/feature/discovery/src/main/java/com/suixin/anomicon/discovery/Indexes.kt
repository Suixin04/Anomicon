package com.suixin.anomicon.discovery

import com.suixin.anomicon.core.network.WIKI_BASE
import com.suixin.anomicon.core.network.wikiSlug
import org.jsoup.Jsoup
import java.io.IOException
import kotlin.random.Random

internal data class Entry(val id: String, val title: String, val detail: String = "")
internal data class Preview(val image: String?, val text: String)
internal data class Series(val key: String, val label: String, val cn: Boolean)
internal val series = listOf(false, true).flatMap { cn ->
    listOf("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X").take(if (cn) 5 else 10).mapIndexed { i, numeral ->
        val prefix = if (cn) "scp-series-cn" else "scp-series"
        Series(if (i == 0) prefix else "$prefix-${i+1}", if (cn) "CN-$numeral" else numeral, cn)
    }
}
internal val feeds = linkedMapOf("top-rated-pages" to "热门原创", "most-recently-created-cn" to "最近原创", "most-recently-created-translated" to "最近译文")
private val number = Regex("scp-(?:cn-)?[0-9]+(?:-[a-z0-9]+)*")
private fun body(key: String, html: String) = Jsoup.parse(html, WIKI_BASE + key).getElementById("page-content") ?: throw IOException("页面缺少正文")
internal fun parseIndex(key: String, html: String): List<Entry> {
    val root = body(key, html)
    val entries = if (key in feeds) root.select("tr").mapNotNull { row ->
        val link = row.selectFirst("td a[href]") ?: return@mapNotNull null
        val id = wikiSlug(link.absUrl("href")) ?: return@mapNotNull null
        Entry(id, link.text(), row.select("td").getOrNull(1)?.text().orEmpty())
    } else root.select("li a[href]").mapNotNull { link ->
        val id = wikiSlug(link.absUrl("href"))?.takeIf { it.matches(number) && it.startsWith("scp-cn-") == key.startsWith("scp-series-cn") } ?: return@mapNotNull null
        val line = link.closest("li")!!.text()
        val title = line.substringAfter(link.text(), "").trimStart(' ', '-', '—', '：', ':').removeSuffix("[已锁]").trim()
        Entry(id, title.ifBlank { link.text() })
    }
    return entries.distinctBy { it.id }.ifEmpty { throw IOException("未找到目录条目") }
}
internal fun parsePreview(id: String, html: String): Preview {
    val root = body(id, html)
    root.select("script, style, .creditRate, .page-rate-widget-box, .licensebox, .printuser").remove()
    val image = (root.selectFirst(".scp-image-block img") ?: root.select("img[src]").firstOrNull { it.absUrl("src").contains("/local--files/") })?.absUrl("src")?.replaceFirst("http://", "https://")
    val paragraphs = root.select("p").map { it.text().trim() }.filter { it.isNotBlank() }
    val index = paragraphs.indexOfFirst { it.startsWith("描述") }
    val text = if (index >= 0) paragraphs.drop(index).take(3).joinToString(" ").removePrefix("描述").trimStart(':','：',' ') else paragraphs.firstOrNull { it.length > 25 }.orEmpty()
    return Preview(image, text.take(220))
}
internal fun matches(entries: List<Entry>, query: String): List<Entry> {
    val q = query.trim()
    if (q.isEmpty()) return emptyList()
    val target = wikiSlug(q)
    return entries.filter { it.id == target || it.id.contains(q, true) || it.title.contains(q, true) }.sortedByDescending { it.id == target }
}
internal fun dailyDeck(pool: List<Entry>, seed: Int): List<Entry> {
    val random = Random(seed)
    val (cn, main) = pool.partition { it.id.startsWith("scp-cn-") }
    return (cn.shuffled(random).take(2) + main.shuffled(random).take(4)).shuffled(random)
}
