package com.suixin.anomicon.core.network

import java.io.IOException
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.ResponseBody
import org.jsoup.Jsoup
import org.jsoup.nodes.Element
import retrofit2.Retrofit
import retrofit2.http.GET
import retrofit2.http.Path

const val WIKI_BASE = "https://scp-wiki-cn.wikidot.com/"
private val slugPattern = Regex("[a-z0-9][a-z0-9_:-]*")

/** A reader entry resolves to a single page on the Chinese Wiki. */
fun wikiSlug(input: String): String? {
    val text = input.trim().lowercase(Locale.ROOT)
    val url = text.toHttpUrlOrNull()
    val slug = if (url != null) {
        if (url.host != "scp-wiki-cn.wikidot.com" || url.port !in listOf(80, 443) ||
            url.username.isNotEmpty() || url.password.isNotEmpty()) return null
        url.pathSegments.singleOrNull() ?: return null
    } else text.removePrefix("/")
    return when {
        slug.matches(Regex("[0-9]{1,5}")) -> "scp-${slug.padStart(3, '0')}"
        slug.matches(Regex("cn-[0-9]{1,5}")) -> "scp-cn-${slug.substringAfter('-').padStart(3, '0')}"
        slug.matches(slugPattern) -> slug
        else -> null
    }
}

@Serializable
data class WikiPreview(val slug: String, val title: String, val blocks: List<PreviewBlock>,
    val tags: List<String> = emptyList(), val rating: String? = null, val objectClass: String? = null,
    val hasInteractiveContent: Boolean = false, val credits: String = "", val offlineHtml: String = "",
    val footnotes: Map<String, String> = emptyMap(), val anchors: Map<String, Int> = emptyMap())

@Serializable
data class HiddenSpan(val start: Int, val end: Int)

@Serializable
data class WikiLink(val start: Int, val end: Int, val slug: String)

@Serializable
sealed interface PreviewBlock {
    @Serializable data class Heading(val text: String) : PreviewBlock
    @Serializable data class Paragraph(val text: String, val links: List<WikiLink> = emptyList(), val hidden: List<HiddenSpan> = emptyList()) : PreviewBlock
    @Serializable data class Image(val url: String, val description: String, val caption: String = "") : PreviewBlock
    @Serializable data class Table(val rows: List<List<String>>) : PreviewBlock
}

/** Stage-one preview preserves source order and table structure, independent of WebView. */
fun parseWikiPreview(html: String, slug: String): WikiPreview {
    val document = Jsoup.parse(html, WIKI_BASE + slug)
    val body = document.getElementById("page-content") ?: throw IOException("页面缺少 Wiki 正文")
    if (body.selectFirst(".error-block") != null && body.selectFirst("#edit-page-form") != null) {
        throw IOException("条目不存在")
    }
    // A static fragment keeps credit links and captions from the same revision the reader sees.
    body.select("[style]").forEach { element ->
        val css = element.attr("style").lowercase().split(';').associate { it.substringBefore(':').trim() to it.substringAfter(':').trim() }
        val ink = css["color"]
        if (ink != null && (ink == "transparent" || ink == css["background-color"] || ink == css["background"] ||
            (ink in setOf("#fff", "white", "#ffffff") && css.keys.none { it.startsWith("background") }))) element.attr("data-concealed", "true")
    }
    // Earlier shelf copies retained the numbered markers, but omitted href/id.
    for (ref in body.select("a.footnoteref")) {
        val number = ref.text().trim().toIntOrNull() ?: continue
        ref.attr("data-note", "footnote-$number")
    }
    val source = body.clone()
    document.select(".page-tags,.rate-points").filter { it.closest("#page-content") == null }
        .forEach { source.appendChild(it.clone()) }
    val attribution = source.appendElement("div").addClass("licensebox").appendElement("div").addClass("collapsible-block-content")
    attribution.appendText("原文：").appendElement("a").attr("href", WIKI_BASE + slug).text(WIKI_BASE + slug)
    // Store stable anchors through cleaning, including fragment-only footnote references.
    val offlineHtml = Jsoup.clean(source.html(), WIKI_BASE + slug, org.jsoup.safety.Safelist.relaxed()
        .addTags("figure", "figcaption", "main", "section", "article", "h1", "h2", "h3", "h4", "h5", "h6")
        .addAttributes(":all", "class", "id", "data-concealed").addAttributes("a", "data-note", "name"))
    val tags = document.select(".page-tags a").map { it.text() }.filter { it.isNotBlank() && !it.startsWith("_") }.distinct()
    val rating = document.selectFirst(".rate-points")?.text()?.let { Regex("[+−-]?\\s*\\d+").find(it)?.value?.replace(" ", "") }
    val classes = listOf("Safe", "Euclid", "Keter", "Thaumiel", "Apollyon", "Archon", "Neutralized", "Explained", "Pending")
    val objectClass = classes.firstOrNull { name -> tags.any { it.equals(name, true) } } ?: Regex(
        "(?:项目等级|收容等级|Object Class)\\s*[:：]\\s*(${classes.joinToString("|")})", RegexOption.IGNORE_CASE
    ).find(body.text())?.groupValues?.get(1)
    val interactive = body.selectFirst("audio,video,iframe,object,embed,.collapsible-block,.yui-navset") != null
    body.select(".translation_block,.u-faq").remove()
    val credits = body.select(".licensebox .collapsible-block-content,.info-container .collapsible-block-content").map { it.text() }
        .filter { it.isNotBlank() }.distinct().joinToString("\n\n")
    body.select(".info-container,.licensebox").remove()
    body.select("script,style,noscript,.page-rate-widget-box,.creditRate,.page-tags,.printuser").remove()
    val notes = body.select(".footnote-footer").mapIndexed { index, item ->
        val key = item.id().ifEmpty { "footnote-${index + 1}" }
        val copy = item.clone()
        copy.selectFirst("a")?.takeIf { it.text().trim().toIntOrNull() != null }?.remove()
        key to copy.text().trimStart('.', ' ')
    }.toMap()
    body.select(".footnotes-footer,.footnote-footer").remove()
    val captions = body.select(".scp-image-block,figure").associate { frame ->
        val image = frame.selectFirst("img")
        val caption = frame.selectFirst(".scp-image-caption,figcaption")
        val text = caption?.text().orEmpty()
        caption?.remove()
        image to text
    }
    val blocks = mutableListOf<PreviewBlock>()
    val anchors = mutableMapOf<String, Int>()
    fun visit(node: Element) {
        if (node.id().isNotBlank()) anchors[node.id()] = blocks.size
        if (node.hasAttr("name")) anchors[node.attr("name")] = blocks.size
        if (node.normalName() in setOf("p", "li", "pre", "table", "h1", "h2", "h3", "h4", "h5", "h6")) {
            node.select("[id],a[name]").forEach { anchors[it.id().ifBlank { it.attr("name") }] = blocks.size }
        }
        when (node.normalName()) {
            "h1", "h2", "h3", "h4", "h5", "h6" -> if (node.text().isNotBlank()) blocks += PreviewBlock.Heading(node.text())
            "table" -> {
                val rows = node.select("tr").filter { it.closest("table") == node }.map { row ->
                    row.children().filter { it.normalName() == "th" || it.normalName() == "td" }.map { it.text() }
                }.filter { it.isNotEmpty() }
                if (rows.isNotEmpty()) blocks += PreviewBlock.Table(rows)
            }
            "img" -> {
                val url = node.absUrl("src").toHttpUrlOrNull() ?: return
                blocks += PreviewBlock.Image(url.newBuilder().scheme("https").build().toString(), node.attr("alt"), captions[node].orEmpty())
            }
            "p", "li", "pre" -> {
                node.select("img").forEach(::visit)
                val text = node.text()
                if (text.isNotBlank()) {
                    val links = node.select("a[href],a[data-note]").mapNotNull { link ->
                        val label = link.text()
                        if (label.isBlank()) return@mapNotNull null
                        val note = link.attr("data-note").ifEmpty { link.attr("href").substringAfterLast('#', "") }
                        val target = if (note in notes) "#$note" else {
                            val url = link.absUrl("href").toHttpUrlOrNull() ?: return@mapNotNull null
                            val page = wikiSlug(url.toString()) ?: return@mapNotNull null
                            if (page == slug && !url.fragment.isNullOrBlank()) "#${url.fragment}" else page
                        }
                        // Mark the actual DOM node so a repeated digit in the preceding prose is never linked.
                         val original = link.html()
                         link.prependText("\uE000")
                         val start = node.text().indexOf('\uE000')
                         link.html(original)
                        if (start < 0) return@mapNotNull null
                        WikiLink(start, start + label.length, target)
                    }
                    var end = 0
                    val hidden = node.select("[data-concealed=true]").mapNotNull { span ->
                        val label = span.text()
                        val start = text.indexOf(label, end)
                        if (start < 0 || label.isEmpty()) null else HiddenSpan(start, start + label.length).also { end = it.end }
                    }
                    blocks += PreviewBlock.Paragraph(text, links, hidden)
                }
            }
            else -> {
                if (node.childrenSize() == 0 && node.text().isNotBlank()) blocks += PreviewBlock.Paragraph(node.text())
                else node.children().forEach(::visit)
            }
        }
    }
    body.children().forEach(::visit)
    if (blocks.isEmpty()) throw IOException("此页暂无可预览正文，请查看原版网页")
    val title = document.getElementById("page-title")?.text()?.takeIf { it.isNotBlank() } ?: slug.uppercase(Locale.ROOT)
    return WikiPreview(slug, title, blocks, tags, rating, objectClass, interactive, credits, offlineHtml, notes, anchors.filterValues { it in blocks.indices })
}

/** The series indexes retain the translated short name when the article heading contains only its number. */
fun seriesSubtitle(html: String, slug: String): String? {
    val link = Jsoup.parse(html).selectFirst("#page-content li a[href=/$slug]") ?: return null
    return link.closest("li")?.text()?.substringAfter(link.text(), "")?.trimStart(' ', '-', '—', '：', ':')
        ?.removeSuffix("[已锁]")?.trim()?.takeIf { it.isNotBlank() }
}

internal interface WikiService {
    @GET("{slug}") suspend fun page(@Path("slug") slug: String): ResponseBody
}

class WikiRepository internal constructor(private val service: WikiService) {
    constructor() : this(service(WIKI_BASE))
    suspend fun preview(entry: String): WikiPreview {
        val slug = requireNotNull(wikiSlug(entry)) { "无效的 Wiki 条目地址" }
        val html = withContext(Dispatchers.IO) {
            try { service.page(slug).use { it.string() } }
            catch (error: retrofit2.HttpException) { throw IOException("Wiki HTTP ${error.code()}", error) }
        }
        return withContext(Dispatchers.Default) { parseWikiPreview(html, slug) }
    }

    companion object {
        internal fun service(baseUrl: String): WikiService {
            val client = OkHttpClient.Builder().callTimeout(25, TimeUnit.SECONDS)
                .addInterceptor { chain -> chain.proceed(chain.request().newBuilder()
                    .header("User-Agent", "Anomicon-Android/1.2.11").build()) }.build()
            return Retrofit.Builder().baseUrl(baseUrl).client(client).build().create(WikiService::class.java)
        }
    }
}
