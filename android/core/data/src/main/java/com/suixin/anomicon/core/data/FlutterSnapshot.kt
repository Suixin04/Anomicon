package com.suixin.anomicon.core.data

import com.fasterxml.jackson.core.JsonFactory
import com.fasterxml.jackson.core.JsonToken
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest

internal fun digest(value: String) = MessageDigest.getInstance("SHA-256").digest(value.toByteArray())
    .joinToString("") { "%02x".format(it) }

internal class FlutterSnapshot(private val preferences: Map<String, *>, val documents: File) {
    fun string(key: String) = preferences["flutter.$key"] as String?
    val starterDismissed get() = preferences["flutter.discovery.starterDismissed"] as Boolean?
    fun items(): List<LibraryItem> = buildList {
        for ((name, key) in mapOf("favorites" to "id", "history" to "id", "activitySegments" to "segmentId", "raisa.receipts" to "issueNumber")) {
            val values = JSONArray(string(name) ?: "[]")
            for (index in 0 until values.length()) {
                val row = values.getJSONObject(index)
                add(LibraryItem(name, row.get(key).toString(), index, row.toString()))
            }
        }
        val values = string("discovery.searchHistory")?.removePrefix("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!") ?: "[]"
        val searches = JSONArray(values)
        for (i in 0 until searches.length()) {
            val query = searches.getString(i)
            add(LibraryItem("discovery.searchHistory", query, i, query))
        }
    }
    fun cacheIndex(): List<CacheFile> = entries(File(documents, "content-cache")).mapNotNull { file ->
        if (!file.isFile || !file.name.matches(CACHE_NAME)) return@mapNotNull null
        val meta = File(file.parentFile, "${file.name}.meta")
        val time = if (meta.isFile) meta.readText().trim().toLongOrNull() else null
        if (time == null && file.extension != "img") return@mapNotNull null
        CacheFile(file.name, time ?: file.lastModified(), file.length())
    }
    fun offlineFiles() = entries(File(documents, "offline-articles/v1")).filter { it.isFile && it.extension == "article" }

    private fun entries(directory: File): List<File> = if (!directory.exists()) emptyList() else
        Files.newDirectoryStream(directory.toPath()).use { stream -> stream.map { it.toFile() } }
    private companion object { val CACHE_NAME = Regex("[0-9a-f]{64}\\.(json|html|img)") }
}

/** Only committed .article files enter here. Large Base64 image fields stream directly to disk. */
internal fun importArticle(file: File, output: File): Pair<OfflineArticle, List<OfflineImage>> {
    file.bufferedReader().use { input ->
        val header = JSONObject(requireNotNull(input.readLine()))
        val content = header.getJSONObject("content")
        val id = content.getString("id")
        require(file.nameWithoutExtension == digest("main:$id")) { "离线档案键不匹配" }
        val savedAt = header.getLong("savedAt")
        val folder = File(output, "${file.nameWithoutExtension}/$savedAt")
        Files.createDirectories(folder.toPath())
        val html = File(folder, "body.html")
        val images = mutableListOf<OfflineImage>()
        var wroteBody = false
        JsonFactory().createParser(input).use { parser ->
            require(parser.nextToken() == JsonToken.START_OBJECT)
            while (parser.nextToken() == JsonToken.FIELD_NAME) {
                val field = parser.currentName()
                val token = parser.nextToken()
                when (field) {
                    "html" -> {
                        require(token == JsonToken.VALUE_STRING)
                        publish(html) { dst -> dst.writer().use { parser.getText(it) } }
                        wroteBody = true
                    }
                    "images" -> {
                        require(token == JsonToken.START_OBJECT)
                        while (parser.nextToken() == JsonToken.FIELD_NAME) {
                            val url = parser.currentName()
                            require(parser.nextToken() == JsonToken.VALUE_STRING)
                            val image = File(folder, digest(url))
                            publish(image) { dst -> dst.outputStream().use { parser.readBinaryValue(it) } }
                            images += OfflineImage(id, url, image.relativeTo(output).path)
                        }
                        require(parser.currentToken() == JsonToken.END_OBJECT)
                    }
                    else -> parser.skipChildren()
                }
            }
            require(wroteBody && parser.currentToken() == JsonToken.END_OBJECT && parser.nextToken() == null)
        }
        return OfflineArticle(id, content.getString("title"), content.getString("kind"), savedAt, html.relativeTo(output).path) to images
    }
}

private inline fun publish(file: File, write: (File) -> Unit) {
    val tmp = File(file.parentFile, "${file.name}.tmp")
    write(tmp)
    Files.move(tmp.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
}
