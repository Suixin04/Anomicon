package com.suixin.anomicon.terminal

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream
import java.io.IOException

internal fun readAttachment(resolver: ContentResolver, uri: Uri): Attachment {
    val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
        if (it.moveToFirst()) it.getString(0) else null
    } ?: throw IOException("文件提供方未返回附件名称")
    val mime = resolver.getType(uri) ?: "application/octet-stream"
    val bytes = resolver.openInputStream(uri)?.use { input ->
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (output.size() + count > MAX_FILE) throw IOException("单个附件最多 2 MB：$name")
            output.write(buffer, 0, count)
        }
        output.toByteArray()
    } ?: throw IOException("无法打开附件：$name")
    if (bytes.isEmpty()) throw IOException("附件为空：$name")
    return Attachment(name, mime, bytes)
}
