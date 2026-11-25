package com.suixin.anomicon.terminal

import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.Base64

internal const val ISSUES = "https://github.com/Suixin04/Anomicon/issues"
internal const val MAX_FILE = 2 * 1024 * 1024
internal const val MAX_TOTAL = 5 * 1024 * 1024
internal val categories = linkedMapOf("archive_render" to "档案解析异常", "terminal_bug" to "终端运行故障", "archive_3d" to "三维收容异常", "system_proposal" to "系统演进提案")
internal data class Attachment(val name: String, val mime: String, val bytes: ByteArray)
internal data class TicketDraft(val category: String, val summary: String, val details: String, val contact: String,
    val includeDiagnostics: Boolean, val diagnostics: JSONObject, val attachments: List<Attachment>) {
    fun validationError(): String? = when {
        summary.trim().length !in 4..80 -> "工单简述请填写 4 至 80 个字符"
        details.trim().length !in 8..2000 -> "详细说明请填写 8 至 2000 个字符"
        contact.trim().length > 64 -> "联络代号最多 64 个字符"
        attachments.size > 3 -> "最多选择 3 个附件"
        attachments.any { it.bytes.size !in 1..MAX_FILE } -> "附件不能为空，单个附件最多 2 MB"
        attachments.sumOf { it.bytes.size } > MAX_TOTAL -> "附件总大小最多 5 MB"
        else -> null
    }
    fun payload(): JSONObject = JSONObject().apply {
        put("category", category); put("summary", summary.trim()); put("details", details.trim()); put("contact", contact.trim())
        put("includeDiagnostics", includeDiagnostics); put("appVersionLabel", diagnostics.getString("appVersionLabel"))
        if (includeDiagnostics) put("diagnostics", diagnostics)
        if (attachments.isNotEmpty()) put("attachments", JSONArray().apply {
            attachments.forEach { put(JSONObject().put("fileName", it.name).put("mimeType", it.mime)
                .put("base64Data", Base64.getEncoder().encodeToString(it.bytes))) }
        })
    }
    fun report(): String = buildString {
        appendLine("[RAISA 工单报文 // ${categories.getValue(category)}]")
        appendLine("简述：${summary.trim()}"); appendLine("说明：\n${details.trim()}")
        if (contact.isNotBlank()) appendLine("联络代号：${contact.trim()}")
        appendLine("提交版本：${diagnostics.getString("appVersionLabel")}")
        if (includeDiagnostics) appendLine(diagnostics.toString(2))
        if (attachments.isNotEmpty()) append("需手动添加附件：${attachments.joinToString { it.name }}")
    }.trimEnd()
}
internal data class Receipt(val number: Int, val code: String, val summary: String, val createdAt: String, val version: String, val deduplicated: Boolean) {
    val issueUrl get() = "$ISSUES/$number"
    fun json() = JSONObject().put("issueNumber", number).put("ticketCode", code).put("issueUrl", issueUrl)
        .put("createdAt", createdAt).put("summary", summary).put("submittedAppVersion", version).toString()
    companion object {
        fun stored(text: String): Receipt = JSONObject(text).let { Receipt(it.getInt("issueNumber"), it.getString("ticketCode"),
            it.getString("summary"), it.getString("createdAt"), it.optString("submittedAppVersion"), false) }
    }
}
internal class RaisaRelay(private val endpoint: URL = URL("https://raisa.xiaotau.com/v1/raisa/tickets")) {
    fun submit(draft: TicketDraft, key: String): Receipt {
        val connection = endpoint.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = if (draft.attachments.isEmpty()) 15_000 else 45_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("X-Anomicon-Client", "android")
            connection.setRequestProperty("X-Anomicon-Version", draft.diagnostics.getString("appVersionLabel"))
            connection.setRequestProperty("X-Idempotency-Key", key)
            val bytes = draft.payload().toString().toByteArray()
            connection.setFixedLengthStreamingMode(bytes.size)
            connection.outputStream.use { it.write(bytes) }
            val status = connection.responseCode
            if (status !in 200..299) {
                val text = connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                val message = when (status) { 413 -> "附件超出限制"; 429 -> "提交过于频繁，请稍后再试"; 400, 422 -> "工单内容未通过校验"; else -> "中转服务响应异常" }
                val detail = try { JSONObject(text).let { it.optString("message", it.optString("error")) } } catch (_: org.json.JSONException) { "" }
                throw IOException("HTTP $status · ${detail.ifBlank { message }}")
            }
            val response = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
            val number = response.getInt("issueNumber")
            if (number <= 0) throw IOException("工单回执编号无效")
            val date = when (val value = response.opt("createdAt")) { is Number -> Instant.ofEpochMilli(value.toLong()).toString(); is String -> value; else -> Instant.now().toString() }
            return Receipt(number, response.optString("ticketCode", "RAISA-#$number"), draft.summary.trim(), date,
                draft.diagnostics.getString("appVersionLabel"), response.optBoolean("deduplicated"))
        } finally { connection.disconnect() }
    }
}
