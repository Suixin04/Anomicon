package com.suixin.anomicon

import android.widget.Toast
import android.text.format.Formatter
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.suixin.anomicon.core.data.*
import com.suixin.anomicon.designsystem.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
private fun Section(title: String, body: @Composable ColumnScope.() -> Unit) {
    Text(title, style = MaterialTheme.typography.titleLarge)
    ArchiveCard(Modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = body)
    }
}

@Composable
private fun Action(title: String, supporting: String, onClick: () -> Unit) {
    ListItem(headlineContent = { Text(title) }, supportingContent = { Text(supporting) },
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = ListItemDefaults.colors(containerColor = androidx.compose.ui.graphics.Color.Transparent))
}

@Composable
private fun Toggle(title: String, value: Boolean, update: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f)); ArchiveSwitch(value, update)
    }
}

@Composable
internal fun SettingsScreen(settings: AppSettings, model: ShellViewModel) {
    val data = model.data
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val history by data.searchHistory.collectAsStateWithLifecycle(emptyList())
    val shelf by remember(data) { data.library.shelf() }.collectAsStateWithLifecycle(emptyList())
    val bytes by produceState(0L, shelf) {
        value = withContext(Dispatchers.IO) { shelf.sumOf { data.offlineBytes(it.id) } }
    }
    var confirm by remember { mutableStateOf<String?>(null) }
    var shelfOpen by remember { mutableStateOf(false) }
    var font by remember(settings.fontSize) { mutableFloatStateOf(settings.fontSize) }
    var line by remember(settings.lineHeightMultiple) { mutableFloatStateOf(settings.lineHeightMultiple) }
    val modes = listOf("auto", "prompt", "native")
    Column(Modifier.fillMaxSize()) {
        ArchiveDetailBar("设置", model::back)
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(ArchiveSpacing.page), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Section("外观与交互") {
                Text("主题")
                ArchiveSegments(listOf("跟随系统", "浅色", "深色"), ThemeMode.entries.indexOf(settings.themeMode)) { model.theme(ThemeMode.entries[it]) }
                Toggle("触感反馈", settings.haptics, model::haptics)
            }
            Section("阅读体验") {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("阅读排版", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                    TextButton(onClick = { scope.launch { data.setFontSize(18f); data.setLineHeightMultiple(1.6f); data.setJustifyBody(true) } }) { Text("恢复默认") }
                }
                Text("SCP-173 · 特殊收容措施", style = MaterialTheme.typography.titleSmall)
                Text("项目须始终收容于上锁的标准收容室内。进入人员不得少于三人，且须在离开前始终保持直接视线接触。" + if (settings.revealHidden) "【彩蛋已透视】切勿眨眼，它正在注视你。" else "", fontSize = font.sp, lineHeight = (font * line).sp, textAlign = if (settings.justifyBody) TextAlign.Justify else TextAlign.Start)
                Text("正文字号 · %.2f sp".format(font)); Slider(value = font, onValueChange = { font = it }, valueRange = 14f..22f, onValueChangeFinished = { scope.launch { data.setFontSize(font) } })
                Text("阅读行距 · %.2f 倍".format(line)); Slider(value = line, onValueChange = { line = it }, valueRange = 1.2f..2f, onValueChangeFinished = { scope.launch { data.setLineHeightMultiple(line) } })
                Text("正文对齐"); ArchiveSegments(listOf("两端对齐", "左对齐"), if (settings.justifyBody) 0 else 1) { scope.launch { data.setJustifyBody(it == 0) } }
                Text("复杂页面浏览"); ArchiveSegments(listOf("智能识别", "仅提示", "始终原生"), modes.indexOf(settings.complexMode)) { scope.launch { data.setComplexMode(modes[it]) } }
                Toggle("默认反白透视", settings.revealHidden) { scope.launch { data.setRevealHidden(it) } }
                Toggle("阅读时屏幕常亮", settings.keepScreenOn) { scope.launch { data.setKeepScreenOn(it) } }
            }
            Section("存储与缓存") {
                Action("清理临时缓存", "清理文章缓存，保留收藏、进度和永久离线文章") { confirm = "清理临时缓存" }
                Action("离线保存文章", "${shelf.size} 篇 · ${Formatter.formatFileSize(context, bytes)}") { shelfOpen = true }
                Action("清空搜索历史", if (history.isEmpty()) "暂无本地搜索记录" else "${history.size} 条本地搜索记录") { confirm = "清空搜索历史" }
                Action("三维档案模型包", "查看三维模型与资源包") { model.open(Detail.Scene) }
            }
            Section("关于") {
                Action("关于格异录", "应用信息与版本") { model.open(Detail.About) }
                Action("内容来源与许可", "CC BY-SA 3.0 授权使用") { model.open(Detail.License) }
                Action("RAISA 终端运维工单", "提交档案解析异常、终端故障或功能提案") { model.push(DetailRoute(Detail.Feedback, source = "settings")) }
            }
        }
    }
    confirm?.let { action -> AlertDialog(onDismissRequest = { confirm = null }, title = { Text(action) },
        text = { Text(if (action == "清空搜索历史") "确认移除全部本地图鉴搜索记录吗？" else "清理临时文章缓存？已保存的离线文章会保留。") },
        confirmButton = { TextButton(onClick = { confirm = null; scope.launch {
            val result = try {
                if (action == "清空搜索历史") data.clearSearchHistory() else data.clearContentCache()
                "清理完成"
            } catch (cancelled: CancellationException) { throw cancelled } catch (e: Exception) { "清理失败：${e.localizedMessage}" }
            Toast.makeText(context, result, Toast.LENGTH_SHORT).show()
        } }) { Text("确认清理") } }, dismissButton = { TextButton(onClick = { confirm = null }) { Text("取消") } }) }
    if (shelfOpen) AlertDialog(onDismissRequest = { shelfOpen = false }, title = { Text("离线保存文章") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            if (shelf.isEmpty()) Text("可在条目正文内选择保存供离线阅读。")
            shelf.forEach { item -> TextButton(onClick = { shelfOpen = false; model.openEntry(item.id) }) { Text(item.title) } }
        }
    }, confirmButton = { TextButton(onClick = { shelfOpen = false }) { Text("关闭") } })
}

private val licenseLinks = listOf(
    "SCP Wiki" to "https://scp-wiki.wikidot.com/",
    "SCP 基金会中文 Wiki" to "https://scp-wiki-cn.wikidot.com/",
    "SCP 官方许可指南" to "https://scp-foundation.net/licensing-guide",
    "SCP 三维模型来源（scp-unity-assets）" to "https://github.com/Yni-Viar/scp-unity-assets/tree/7fda38944f51db7ee3aeb4d9e5ca821263153da5",
    "SCP 三维模型扩展来源（scp-assets）" to "https://github.com/Yni-Viar/scp-assets/tree/1265487d1978b60398ab71f366bc5a1ba4ce1d0d",
    "三维模型许可声明" to "https://github.com/Yni-Viar/scp-unity-assets/blob/7fda38944f51db7ee3aeb4d9e5ca821263153da5/LICENSE.CCBYSA3",
    "CC BY-SA 3.0 许可文本" to "https://creativecommons.org/licenses/by-sa/3.0/",
)

@Composable
internal fun ProductInfoScreen(page: Detail, back: () -> Unit) {
    val uri = LocalUriHandler.current
    val context = LocalContext.current
    Column(Modifier.fillMaxSize()) {
        ArchiveDetailBar(page.title, back)
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(ArchiveSpacing.page), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (page == Detail.About) {
                Section("应用信息") {
                    Text("应用名称　格异录"); Text("英文名称　Anomicon")
                    Text("版本　" + remember { context.packageManager.getPackageInfo(context.packageName, 0).versionName })
                }
                Section("非官方应用说明") { Text("格异录是一款非官方社区阅读应用，与 SCP Wiki 不存在隶属、合作或认可关系。应用内呈现的条目文本与模型素材均归各自创作者所有。") }
            } else {
                Section("CC BY-SA 3.0") { Text("各 SCP 条目与衍生素材的授权可能因来源而异，请以具体页面及原始出处说明为准。") }
                Section("来源与许可链接") { licenseLinks.forEach { (name, link) -> TextButton(onClick = {
                    try { uri.openUri(link) } catch (_: IllegalArgumentException) { Toast.makeText(context, "未找到可打开链接的应用", Toast.LENGTH_SHORT).show() }
                }) { Text(name) } } }
                Text("格异录为非官方应用，与 SCP Wiki 不存在隶属或认可关系。")
            }
        }
    }
}
