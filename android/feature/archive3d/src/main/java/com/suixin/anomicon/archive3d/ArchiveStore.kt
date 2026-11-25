package com.suixin.anomicon.archive3d

import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import kotlinx.coroutines.ensureActive
import kotlin.coroutines.coroutineContext
import okhttp3.OkHttpClient
import okhttp3.Request

internal fun resolveAsset(itemId: String?) = archiveAssets.firstOrNull {
    it.contentId.equals(itemId?.trim()?.trimStart('/'), true)
}

fun hasArchiveModel(itemId: String): Boolean = resolveAsset(itemId) != null

internal fun verify(asset: ArchiveAsset, buffer: ByteBuffer) {
    require(buffer.remaining() == asset.byteLength) { "模型长度不匹配" }
    val header = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
    require(header.getInt(0) == 0x46546c67 && header.getInt(4) == 2 && header.getInt(8) == asset.byteLength) { "GLB 2.0 头校验失败" }
    val digest = MessageDigest.getInstance("SHA-256").apply { update(buffer.duplicate()) }.digest()
    require(digest.joinToString("") { "%02x".format(it) } == asset.sha256) { "模型 SHA-256 校验失败" }
}

internal class ArchiveStore(private val root: File, private val client: OkHttpClient = OkHttpClient.Builder().followSslRedirects(false).build()) {
    fun installed(a: ArchiveAsset) = File(root, "${a.assetId}-${a.sha256}.glb")
    fun partial(a: ArchiveAsset) = File(root, "${a.assetId}-${a.sha256}.part")
    fun ready(a: ArchiveAsset) = a.bundled || installed(a).isFile

    suspend fun download(a: ArchiveAsset, progress: (Long) -> Unit) {
        check(!a.bundled)
        Files.createDirectories(root.toPath())
        val part = partial(a)
        if (part.length() > a.byteLength) Files.delete(part.toPath())
        val offset = part.length()
        if (offset < a.byteLength) {
            val request = Request.Builder().url(a.downloadUrl).header("Accept-Encoding", "identity").apply {
                if (offset > 0) header("Range", "bytes=$offset-")
            }.build()
            client.newCall(request).execute().use { response ->
                val append = when (response.code) {
                    200 -> false
                    206 -> {
                        if (response.header("Content-Range") != "bytes $offset-${a.byteLength - 1}/${a.byteLength}") throw IOException("服务器返回了不匹配的续传范围")
                        true
                    }
                    else -> throw IOException("资源服务器 HTTP ${response.code}")
                }
                coroutineContext.ensureActive()
                val body = response.body ?: throw IOException("服务器未返回模型")
                var written = if (append) offset else 0L
                java.io.FileOutputStream(part, append).use { out ->
                    val input = body.byteStream()
                    val chunk = ByteArray(65536)
                    while (true) {
                        coroutineContext.ensureActive()
                        val n = input.read(chunk)
                        if (n == -1) break
                        if (written + n > a.byteLength) throw IOException("模型超过清单长度")
                        out.write(chunk, 0, n)
                        written += n
                        progress(written)
                    }
                    out.fd.sync()
                }
                if (written != a.byteLength.toLong()) throw IOException("下载中断，可继续下载")
            }
        }
        val data = mapModel(part)
        try { verify(a, data) } catch (error: IllegalArgumentException) {
            Files.delete(part.toPath())
            throw IOException(error.message, error)
        }
        Files.move(part.toPath(), installed(a).toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
    }
}

internal fun mapModel(file: File): ByteBuffer = file.inputStream().channel.use {
    it.map(java.nio.channels.FileChannel.MapMode.READ_ONLY, 0, it.size()).order(ByteOrder.nativeOrder())
}
