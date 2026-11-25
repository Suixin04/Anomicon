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
data class WikiPreview(val slug: String, val title: String, val blocks: List<PreviewBlock>)

@Serializable
data class WikiLink(val start: Int, val end: Int, val slug: String)

@Serializable
sealed interface PreviewBlock {
    @Serializable data class Heading(val text: String) : PreviewBlock
    @Serializable data class Paragraph(val text: String, val links: List<WikiLink> = emptyList()) : PreviewBlock
    @Serializable data class Image(val url: String, val description: String) : PreviewBlock
    @Serializable data class Table(val rows: List<List<String>>) : PreviewBlock
}

/** Stage-one preview preserves source order and table structure, independent of WebView. */
fun parseWikiPreview(html: String, slug: String): WikiPreview {
    val document = Jsoup.parse(html, WIKI_BASE + slug)
    val body = document.getElementById("page-content") ?: throw IOException("页面缺少 Wiki 正文")
    if (body.selectFirst(".error-block") != null && body.selectFirst("#edit-page-form") != null) {
        throw IOException("条目不存在")
    }
    body.select("script,style,noscript,.page-rate-widget-box,.creditRate,.page-tags,.printuser").remove()
    val blocks = mutableListOf<PreviewBlock>()
    fun visit(node: Element) {
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
                blocks += PreviewBlock.Image(url.newBuilder().scheme("https").build().toString(), node.attr("alt"))
            }
            "p", "li", "pre" -> {
                node.select("img").forEach(::visit)
                val text = node.text()
                if (text.isNotBlank()) {
                    var offset = 0
                    val links = node.select("a[href]").mapNotNull { link ->
                        val label = link.text()
                        if (label.isBlank() || link.attr("href").startsWith('#')) return@mapNotNull null
                        val target = wikiSlug(link.absUrl("href")) ?: return@mapNotNull null
                        val start = text.indexOf(label, offset)
                        if (start < 0) return@mapNotNull null
                        offset = start + label.length
                        WikiLink(start, offset, target)
                    }
                    blocks += PreviewBlock.Paragraph(text, links)
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
    return WikiPreview(slug, title, blocks)
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
