package com.suixin.anomicon.stories

import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private val indexes = listOf("tales-by-page-name", "tales-cn-by-page-name")
private val navigation = indexes + listOf("tales-cn-by-create-time", "foundation-tales-cn", "series-archive-cn", "canon-hub-cn", "contest-archive-cn", "incident-reports-eye-witness-interviews-and-personal-logs")
private val pagePath = Regex("/[a-z0-9][a-z0-9_-]*")

internal fun parseDirectory(doc: Document): List<Tale> {
    val entries = doc.select("#page-content a[href]").mapNotNull { link ->
        val path = link.attr("href").substringBefore('#')
        val slug = path.removePrefix("/")
        val title = link.text().trim()
        if (pagePath.matches(path) && slug !in navigation && title.length >= 2) Tale(slug, title) else null
    }.distinctBy { it.slug }
    if (entries.isEmpty()) throw IOException("索引没有故事条目")
    return entries
}

internal val bundled = listOf(
    Tale("0-underture", "下界序曲"), Tale("0-unsinkable", "永不沉没"),
    Tale("049-x-minion-x-reader", "049 x 小兵 x 读者（读者是个小黄人）（要怪就怪 varaxous我很抱歉）"),
    Tale("085-romance-adult", "085成人浪漫")
) + groups.flatMap { it.entries }.filterNot { it.slug.startsWith("scp-") }

internal suspend fun loadDirectory(publish: (List<Tale>) -> Unit): List<String> {
    val entries = mutableListOf<Tale>()
    val errors = mutableListOf<String>()
    for (index in indexes) {
        try {
            entries += withContext(Dispatchers.IO) {
                parseDirectory(Jsoup.connect("https://scp-wiki-cn.wikidot.com/$index").timeout(15000).maxBodySize(0).get())
            }
            publish((entries + bundled).distinctBy { it.slug }.sortedBy { it.slug })
        } catch (error: IOException) {
            errors += "$index · ${error.message}"
        }
    }
    return errors
}

internal fun filterDirectory(items: List<Tale>, letter: String, query: String) = items.filter {
    (letter.isEmpty() || it.slug.startsWith(letter, true)) &&
        (it.slug.contains(query.trim(), true) || it.title.contains(query.trim(), true))
}

internal fun resumeTale(current: String?, read: Set<String>): Tale {
    val group = groups.find { g -> g.entries.any { it.slug == current } }
    if (group != null) {
        val sequence = if (group.mainline) mainline else group.entries
        val index = sequence.indexOfFirst { it.slug == current }
        return sequence.drop(index).firstOrNull { it.slug !in read }
            ?: mainline.firstOrNull { it.slug !in read } ?: sequence[index]
    }
    return mainline.firstOrNull { it.slug !in read } ?: mainline.first()
}
