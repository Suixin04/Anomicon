package com.suixin.anomicon.core.network

import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

/** Only public Wiki media hosts are contacted; each redirect is checked before opening it. */
internal fun trustedImageUrl(raw: String): HttpUrl? = raw.toHttpUrlOrNull()?.takeIf { url ->
    url.isHttps && url.port == 443 && url.username.isEmpty() && url.password.isEmpty() &&
        (url.host.endsWith(".wdfiles.com") || url.host.endsWith(".wikidot.com") ||
            url.host == "upload.wikimedia.org" || url.host == "i.imgur.com")
}

private val imageClient = OkHttpClient.Builder().followRedirects(false).followSslRedirects(false)
    .callTimeout(15, TimeUnit.SECONDS).build()

/** Called on IO. Null indicates that this particular image cannot be included. */
fun downloadOfflineImage(raw: String, limit: Long): ByteArray? {
    var url = trustedImageUrl(raw) ?: return null
    if (limit <= 0) return null
    repeat(5) {
        val next = imageClient.newCall(Request.Builder().url(url).build()).execute().use { response ->
            if (response.isRedirect) {
                response.header("Location")?.let { next -> url.resolve(next)?.toString()?.let(::trustedImageUrl) }
            } else {
                val body = response.body ?: return null
                if (!response.isSuccessful || body.contentLength() > limit) return null
                val source = body.source()
                if (source.request(limit + 1)) return null
                val bytes = source.readByteArray()
                return bytes.takeIf { isRasterImage(it) }
            }
        } ?: return null
        url = next
    }
    return null
}

internal fun isRasterImage(bytes: ByteArray): Boolean {
    if (bytes.size < 12) return false
    return bytes.take(3) == listOf(0xff.toByte(), 0xd8.toByte(), 0xff.toByte()) ||
        bytes.take(8) == listOf(137,80,78,71,13,10,26,10).map(Int::toByte) ||
        String(bytes, 0, 6, Charsets.US_ASCII) in setOf("GIF87a", "GIF89a") ||
        (String(bytes, 0, 4, Charsets.US_ASCII) == "RIFF" && String(bytes, 8, 4, Charsets.US_ASCII) == "WEBP")
}
