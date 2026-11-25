package com.suixin.anomicon.terminal

import android.content.ClipData
import android.content.ClipboardManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.suixin.anomicon.core.data.*
import com.suixin.anomicon.designsystem.ArchiveDetailBar
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.IOException
import java.util.UUID

@Composable
fun RaisaPage(onBack: () -> Unit, source: String = "settings", articleId: String = "", articleTitle: String = "",
    articleUrl: String = "", renderMode: String = "", revealHiddenText: Boolean = false) {
    val context = LocalContext.current
    val config = LocalConfiguration.current
    val uriHandler = LocalUriHandler.current
    val scope = rememberCoroutineScope()
    val data = remember(context) { NativeData.open(context) }
    val settings by data.settings.collectAsState(AppSettings())
    val receipts by remember(data) { data.library.items("raisa.receipts") }.collectAsState(emptyList())
    val pkg = remember(context) { context.packageManager.getPackageInfo(context.packageName, 0) }
    val diagnostics = JSONObject().apply {
        put("appVersion", pkg.versionName); put("appVersionCode", pkg.versionCode); put("appVersionLabel", "${pkg.versionName} (${pkg.versionCode})")
        put("deviceType", if (config.smallestScreenWidthDp >= 600) "tablet" else "phone"); put("osLabel", "Android ${Build.VERSION.RELEASE}"); put("windowWidthVp", config.screenWidthDp)
        put("themeMode", settings.themeMode.name.lowercase()); put("immersiveMaterial", settings.immersiveMaterial); put("entrySource", source)
        put("articleId", articleId); put("articleTitle", articleTitle); put("articleUrl", articleUrl); put("renderMode", renderMode); put("revealHiddenText", revealHiddenText)
    }
    var category by rememberSaveable { mutableStateOf(if (source == "article") "archive_render" else "terminal_bug") }
    var summary by rememberSaveable { mutableStateOf("") }
    var details by rememberSaveable { mutableStateOf("") }
    var contact by rememberSaveable { mutableStateOf("") }
    var diagnosticsEnabled by rememberSaveable { mutableStateOf(true) }
    var files by remember { mutableStateOf(emptyList<Attachment>()) }
    var status by rememberSaveable { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<Receipt?>(null) }
    var delete by remember { mutableStateOf<Receipt?>(null) }
    val draft = TicketDraft(category, summary, details, contact, diagnosticsEnabled, diagnostics, files)
    val key = rememberSaveable(category, summary, details, contact, diagnosticsEnabled, files) { UUID.randomUUID().toString() }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.size + files.size > 3) status = "最多选择 3 个附件" else if (uris.isNotEmpty()) {
            busy = true
            scope.launch {
                try {
                    val added = withContext(Dispatchers.IO) { uris.map { readAttachment(context.contentResolver, it) } }
                    if ((files + added).sumOf { it.bytes.size } > MAX_TOTAL) status = "附件总大小最多 5 MB"
                    else { files += added; status = "" }
                } catch (e: IOException) { status = e.localizedMessage.orEmpty() }
                catch (e: SecurityException) { status = "无法读取所选附件，请重新选择" }
                finally { busy = false }
            }
        }
    }
    fun copy(text: String) {
        context.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("RAISA", text)); status = "已复制"
    }
    BackHandler { if (!busy) onBack() }
    Column(Modifier.fillMaxSize()) {
        ArchiveDetailBar("RAISA 工单", { if (!busy) onBack() })
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Text("RAISA-OPS // 终端运维通道", style = MaterialTheme.typography.labelMedium)
                Text("档案系统故障与演进工单", style = MaterialTheme.typography.headlineSmall)
                Text("工单将发布到公开 GitHub Issue。请检查描述、附件和诊断内容，避免包含个人信息。", style = MaterialTheme.typography.bodyMedium)
            }
            if (result == null) {
                item { Text("工单分类", style = MaterialTheme.typography.titleMedium)
                    categories.entries.chunked(2).forEach { pair -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { pair.forEach { (id, title) ->
                        FilterChip(selected = category == id, enabled = !busy, onClick = { category = id }, label = { Text(title) })
                    } } }
                }
                item { OutlinedTextField(summary, { summary = it.take(80) }, Modifier.fillMaxWidth(), enabled = !busy, singleLine = true, label = { Text("工单简述（4–80 字）") }) }
                item { OutlinedTextField(details, { details = it.take(2000) }, Modifier.fillMaxWidth(), enabled = !busy, minLines = 3, label = { Text("详细说明与复现路径（8–2000 字）") }) }
                item { OutlinedTextField(contact, { contact = it.take(64) }, Modifier.fillMaxWidth(), enabled = !busy, singleLine = true, label = { Text("联络代号（选填）") }) }
                item {
                    Text("现场截图与附件（选填）", style = MaterialTheme.typography.titleMedium)
                    Text("最多 3 项，单项 2 MB，合计 5 MB。", style = MaterialTheme.typography.bodySmall)
                    Row { TextButton(enabled = !busy && files.size < 3, onClick = { picker.launch(arrayOf("image/png", "image/jpeg", "image/webp", "image/gif")) }) { Text("选择图片") }
                        TextButton(enabled = !busy && files.size < 3, onClick = { picker.launch(arrayOf("text/*", "application/pdf", "application/json", "application/octet-stream")) }) { Text("选择文件") } }
                }
                items(files.size) { index -> Row(verticalAlignment = Alignment.CenterVertically) { val file = files[index]; Text("${file.name} · ${android.text.format.Formatter.formatFileSize(context, file.bytes.size.toLong())}", Modifier.weight(1f)); TextButton(enabled = !busy, onClick = { files = files.filterIndexed { i, _ -> i != index } }) { Text("移除") } } }
                item { Row(verticalAlignment = Alignment.CenterVertically) { Text("附带脱敏终端诊断快照", Modifier.weight(1f)); Switch(diagnosticsEnabled, { diagnosticsEnabled = it }, enabled = !busy) }
                    if (diagnosticsEnabled) Text(diagnostics.toString(2), style = MaterialTheme.typography.bodySmall) }
                item { Button(enabled = !busy, onClick = { val error = draft.validationError(); if (error != null) status = error else confirm = true }) { Text(if (busy) "处理中…" else "签发工单") }
                    Row { TextButton(onClick = { copy(draft.report()) }) { Text("复制工单报文") }; TextButton(onClick = { uriHandler.openUri(ISSUES) }) { Text("前往 GitHub Issues") } } }
            } else {
                item { val receipt = requireNotNull(result)
                    Text(if (receipt.deduplicated) "已关联原有工单" else "工单已签发", style = MaterialTheme.typography.titleLarge)
                    Text(receipt.code); Row { TextButton(onClick = { copy(receipt.code) }) { Text("复制编号") }; TextButton(onClick = { uriHandler.openUri(receipt.issueUrl) }) { Text("查看公开进展") } }
                    OutlinedButton(onClick = { result = null; summary = ""; details = ""; contact = ""; files = emptyList(); status = "" }) { Text("继续签发新工单") }
                }
            }
            if (status.isNotEmpty()) item { Text(status, color = MaterialTheme.colorScheme.primary) }
            item { HorizontalDivider(); Text("近期已提交工单", style = MaterialTheme.typography.titleMedium) }
            if (receipts.isEmpty()) item { Text("本地尚无已签发的工单回执") }
            items(receipts, key = { it.id }) { item -> val r = remember(item) { Receipt.stored(item.payload) }
                Column { Text("${r.code} · ${r.summary}"); Text("${r.createdAt}  ${r.version}", style = MaterialTheme.typography.bodySmall)
                    Row { TextButton(onClick = { copy(r.code) }) { Text("复制编号") }; TextButton(onClick = { uriHandler.openUri(r.issueUrl) }) { Text("查看进展") }; TextButton(onClick = { delete = r }) { Text("移除回执") } }
                }
            }
        }
    }
    if (confirm) AlertDialog(onDismissRequest = { confirm = false }, title = { Text("发布公开工单？") }, text = { Text("${summary.trim()}\n${files.size} 个附件。工单和所选内容会公开显示在 GitHub。") }, dismissButton = { TextButton(onClick = { confirm = false }) { Text("返回检查") } }, confirmButton = {
        Button(onClick = {
            confirm = false; busy = true; status = ""
            scope.launch {
                try {
                    val receipt = withContext(Dispatchers.IO) { RaisaRelay().submit(draft, key) }
                    result = receipt
                    try {
                        val ordinal = (data.library.firstOrdinal("raisa.receipts") ?: 0) - 1
                        data.library.putItems(listOf(LibraryItem("raisa.receipts", receipt.number.toString(), ordinal, receipt.json())))
                    } catch (e: android.database.SQLException) { status = "云端已签发，本地保存失败，请复制工单编号。" }
                } catch (e: IOException) { status = "签发失败：${e.localizedMessage}" }
                catch (e: org.json.JSONException) { status = "中转服务返回的回执无效" }
                finally { busy = false }
            }
        }) { Text("确认发布") }
    })
    delete?.let { r -> AlertDialog(onDismissRequest = { delete = null }, title = { Text("移除本机回执？") }, text = { Text("${r.code} 的公开工单仍可在 GitHub 查看。") }, dismissButton = { TextButton(onClick = { delete = null }) { Text("取消") } }, confirmButton = { TextButton(onClick = { scope.launch { data.library.remove("raisa.receipts", r.number.toString()); delete = null } }) { Text("移除") } }) }
}
