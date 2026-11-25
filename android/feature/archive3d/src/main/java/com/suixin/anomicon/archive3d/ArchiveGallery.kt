package com.suixin.anomicon.archive3d

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.suixin.anomicon.designsystem.ArchiveDetailBar
import kotlinx.coroutines.*
import java.io.File
import java.io.IOException
import java.util.Locale

private fun sizeLabel(bytes: Long) = String.format(Locale.ROOT, "%.1f MiB", bytes / 1048576.0)

@Composable
fun StageProbe(onBack: () -> Unit, onFullscreenChange: (Boolean) -> Unit = {}, initialItemId: String? = null, onOpenArticle: ((String) -> Unit)? = null) {
    val context = LocalContext.current
    val store = remember(context) { ArchiveStore(File(context.filesDir, "archive-models")) }
    var selected by rememberSaveable(initialItemId) { mutableStateOf(resolveAsset(initialItemId)?.contentId) }
    var stage by rememberSaveable(initialItemId) { mutableStateOf(false) }
    var filter by rememberSaveable { mutableIntStateOf(0) }
    val asset = resolveAsset(selected)
    val back = {
        when {
            stage -> stage = false
            selected != null && initialItemId == null -> selected = null
            else -> onBack()
        }
    }
    BackHandler(onBack = back)
    when {
        asset != null && stage -> ModelStage(asset, store, back, onFullscreenChange)
        asset != null -> key(asset.contentId) { AssetDetail(asset, store, back, { stage = true }, onOpenArticle) }
        else -> Column(Modifier.fillMaxSize()) {
            ArchiveDetailBar("三维档案馆", back) {}
            val ready = archiveAssets.filter(store::ready)
            val groups = listOf(archiveAssets, ready, archiveAssets - ready.toSet())
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("全部", "已下载", "待下载").forEachIndexed { index, title ->
                    FilterChip(selected = filter == index, onClick = { filter = index }, label = { Text("$title ${groups[index].size}") })
                }
            }
            LazyColumn {
                items(groups[filter], key = { it.contentId }) { row ->
                    ListItem(modifier = Modifier.clickable { selected = row.contentId }, headlineContent = { Text(row.displayId) },
                        supportingContent = { Text(row.description) }, overlineContent = {
                            val status = when { row.bundled -> "内置"; row in ready -> "已下载"; store.partial(row).length() > 0 -> "已暂停"; else -> "待下载" }
                            Text("$status · ${row.objectClass} · ${sizeLabel(row.byteLength.toLong())}")
                        })
                }
            }
        }
    }
}

@Composable
private fun AssetDetail(asset: ArchiveAsset, store: ArchiveStore, back: () -> Unit, openStage: () -> Unit, openArticle: ((String) -> Unit)?) {
    val scope = rememberCoroutineScope()
    var ready by remember { mutableStateOf(store.ready(asset)) }
    var received by remember { mutableLongStateOf(store.partial(asset).length()) }
    var job by remember { mutableStateOf<Job?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var confirmDelete by rememberSaveable { mutableStateOf(false) }
    val running = job != null
    val links = LocalUriHandler.current
    Column(Modifier.fillMaxSize()) {
        ArchiveDetailBar("三维档案", back) {}
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(asset.displayId, style = MaterialTheme.typography.headlineLarge)
            Text("${asset.objectClass} · ${sizeLabel(asset.byteLength.toLong())} · ${if (asset.bundled) "内置" else if (ready) "已下载" else "按需下载"}")
            Text(asset.description)
            if (ready) Button(onClick = openStage) { Text("进入三维舞台") }
            else {
                if (received > 0 || running) {
                    LinearProgressIndicator(progress = { received.toFloat() / asset.byteLength }, modifier = Modifier.fillMaxWidth())
                    Text("${sizeLabel(received)} / ${sizeLabel(asset.byteLength.toLong())}")
                }
                Button(onClick = {
                    if (running) job?.cancel()
                    else job = scope.launch {
                        error = null
                        try {
                            withContext(Dispatchers.IO) { store.download(asset) { received = it } }
                            ready = true
                        } catch (e: IOException) { error = e.message }
                        finally { received = store.partial(asset).length(); job = null }
                    }
                }) { Text(if (running) "暂停下载" else if (received > 0) "继续下载" else "下载模型") }
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            if (!asset.bundled && !running && (ready || received > 0)) TextButton(onClick = { confirmDelete = true }) { Text("移除本地模型") }
            openArticle?.let { TextButton(onClick = { it(asset.contentId) }) { Text("阅读条目") } }
            HorizontalDivider()
            Text("来源与许可", style = MaterialTheme.typography.titleLarge)
            Text(asset.attribution)
            Text(asset.contentAttribution)
            Text(asset.notice)
            Text(asset.modificationNote)
            TextButton(onClick = { links.openUri(asset.licenseUrl) }) { Text(asset.license) }
            TextButton(onClick = { links.openUri(asset.sourceUrl) }) { Text(asset.sourceLabel) }
            TextButton(onClick = { links.openUri(asset.contentSourceUrl) }) { Text("条目来源") }
        }
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { Text("移除本地模型？") },
        text = { Text("稍后可以重新下载 ${asset.displayId}。") }, dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("取消") } },
        confirmButton = { TextButton(onClick = {
            confirmDelete = false
            try {
                java.nio.file.Files.deleteIfExists(store.installed(asset).toPath())
                java.nio.file.Files.deleteIfExists(store.partial(asset).toPath())
                ready = false; received = 0; error = null
            } catch (e: IOException) { error = e.message }
        }) { Text("移除") } })
}
