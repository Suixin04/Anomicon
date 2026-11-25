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
internal val jokeSources = linkedMapOf("joke-scps" to "搞笑 SCP", "joke-scps-cn" to "中文搞笑 SCP", "joke-scps-tales-edition" to "轻松故事")
internal val taleSources = listOf("tales-by-page-name", "tales-cn-by-page-name")
private val navigation = (taleSources + listOf("main", "tales-cn-by-create-time", "foundation-tales-cn", "series-archive-cn", "canon-hub-cn", "contest-archive-cn", "incident-reports-eye-witness-interviews-and-personal-logs")).toSet()
private val number = Regex("scp-(?:cn-)?[0-9]+(?:-[a-z0-9]+)*")
private fun body(key: String, html: String) = Jsoup.parse(html, WIKI_BASE + key).getElementById("page-content") ?: throw IOException("页面缺少正文")
internal fun parseIndex(key: String, html: String): List<Entry> {
    val root = body(key, html)
    val entries = if (key in jokeSources || key in taleSources) {
        val jokeTales = key == "joke-scps-tales-edition"
        val marker = if (jokeTales) root.selectFirst("p:contains(就这样啦)") else null
        val links = (marker?.nextElementSiblings()?.flatMap { it.select("a[href]") } ?: root.select("a[href]"))
        links.mapNotNull { link ->
            val path = link.attr("href")
            val title = link.text().trim()
            if (!path.matches(Regex("/[a-zA-Z0-9][a-zA-Z0-9_-]*")) || title.length < 2) return@mapNotNull null
            val id = path.drop(1).lowercase()
            val scp = id.startsWith("scp-") || id.startsWith("spc-")
            if (id in navigation || listOf("scp-series", "joke-scps", "tales-by", "foundation-tales", "most-recently", "top-rated", "explained-scps", "forum", "help").any(id::startsWith)) return@mapNotNull null
            if (key in jokeSources && (if (jokeTales) scp else !scp || "-j" !in id && !title.contains("-j", true))) return@mapNotNull null
            Entry(id, title, if (key in taleSources) "故事" else jokeSources.getValue(key))
        }
    } else if (key in feeds) root.select("tr").mapNotNull { row ->
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
    val target = directTarget(q)?.substringBefore('#')
    return entries.filter { it.id == target || it.id.contains(q, true) || it.title.contains(q, true) }.sortedByDescending { it.id == target }
}
internal fun dailyDeck(pool: List<Entry>, seed: Int): List<Entry> {
    val random = Random(seed)
    val (cn, main) = pool.partition { it.id.startsWith("scp-cn-") }
    return (cn.shuffled(random).take(2) + main.shuffled(random).take(4)).shuffled(random)
}

private val scpInput = Regex("""(?:scp[\s-]*(?:([a-z]{2,4})[\s-]*)?|(cn)[\s-]*)(\d{1,5})(?:[\s-]+([a-z0-9-]+))?""", RegexOption.IGNORE_CASE)
private val wikiHosts = setOf("scp-wiki-cn.wikidot.com", "scp-wiki.wikidot.com", "www.scp-wiki-cn.wikidot.com", "www.scp-wiki.wikidot.com")
internal fun directTarget(input: String): String? {
    val text = input.trim().lowercase()
    if (text.matches(Regex("""\d{3,4}"""))) return "scp-$text"
    scpInput.matchEntire(text)?.let { match ->
        val (branch, cn, digits, suffix) = match.destructured
        return listOf("scp", branch.ifEmpty { cn }, digits.padStart(3, '0'), suffix).filter(String::isNotEmpty).joinToString("-")
    }
    val raw = input.trim()
    val uri = try { java.net.URI(if ("://" in raw) raw else "https://$raw") } catch (_: java.net.URISyntaxException) { return null }
    if (uri.scheme.lowercase() !in setOf("http", "https") || uri.rawAuthority?.lowercase() !in wikiHosts) return null
    val slug = uri.rawPath.trim('/').lowercase()
    if (!slug.matches(Regex("[a-z0-9][a-z0-9._-]*"))) return null
    return slug + (uri.fragment?.takeIf(String::isNotBlank)?.let { "#$it" } ?: "")
}

private val sourceDate = Regex("""\d{1,2} [A-Za-z]{3} \d{4} \d{2}:\d{2}""")
private val sourceDateFormat = java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy HH:mm", java.util.Locale.ENGLISH)
internal fun recentDate(detail: String): java.time.LocalDateTime? = sourceDate.find(detail)?.value?.let { value ->
    try { java.time.LocalDateTime.parse(value, sourceDateFormat) } catch (_: java.time.format.DateTimeParseException) { null }
}
