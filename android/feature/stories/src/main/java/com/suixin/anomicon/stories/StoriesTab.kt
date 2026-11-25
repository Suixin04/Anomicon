package com.suixin.anomicon.stories

import com.suixin.anomicon.designsystem.*
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.ui.res.painterResource
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.suixin.anomicon.core.data.NativeData
import kotlinx.coroutines.launch

@Composable
fun StoriesTab(onEntry: (String) -> Unit) {
    val context = LocalContext.current
    val data = remember(context) { NativeData.open(context) }
    val progress by data.seriesProgress.collectAsState(initial = emptyList())
    val history by data.history.collectAsState(initial = emptyList())
    val completed = remember(history) { history.filter { it.progress >= 0.95 }.map { it.id }.toSet() }
    val next = resumeTale(progress.find { it.seriesId == SERIES_ID }?.entryId, completed)
    var detail by rememberSaveable { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val openChapter: (Tale) -> Unit = { tale -> scope.launch {
        data.saveSeriesProgress(SERIES_ID, "逆模因部", tale.slug, tale.title)
        onEntry(tale.slug)
    } }
    var query by rememberSaveable { mutableStateOf("") }
    var letter by rememberSaveable { mutableStateOf("") }
    var limit by rememberSaveable(query, letter) { mutableIntStateOf(40) }
    var retry by remember { mutableIntStateOf(0) }
    var directory by remember { mutableStateOf(bundled.sortedBy { it.slug }) }
    var errors by remember { mutableStateOf(emptyList<String>()) }
    LaunchedEffect(retry) { errors = emptyList(); errors = loadDirectory { directory = it } }
    val filtered = remember(query, letter, directory) { filterDirectory(directory, letter, query) }
    ArchiveSecondaryPage(detail)
    BackHandler(detail) { detail = false }
    if (detail) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = LocalArchiveBottomInset.current + 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { TextButton(onClick = { detail = false }) { Text("‹ 故事") } }
            item { Heading("逆模因部 · 中心页与顺序") }
            item { OutlinedButton(onClick = { onEntry("antimemetics-division-hub") }) { Text("阅读 Wiki 中心页") } }
            groups.forEach { group ->
                item { Heading(group.title) }
                items(group.entries, key = { it.slug }) { tale -> StoryRow(tale, if (tale.slug in completed) "已读" else tale.slug) { openChapter(tale) } }
            }
        }
        return
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 14.dp, bottom = LocalArchiveBottomInset.current + 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Text("故事", Modifier.padding(bottom = 10.dp), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold) }
        item { OutlinedTextField(query, { query = it }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(26.dp), singleLine = true, leadingIcon = { Icon(painterResource(R.drawable.search), null, Modifier.size(18.dp)) }, placeholder = { Text("搜索故事标题或别名") }) }
        item { LazyRow(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            items(listOf("") + ('A'..'Z').map { it.toString() }) { key -> FilterChip(selected = key == letter, onClick = { letter = key }, label = { Text(key.ifEmpty { "全部" }) }, shape = RoundedCornerShape(24.dp)) }
        } }
        if (query.isBlank() && letter.isEmpty()) {
            item { Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                Heading("系列跟读")
                Tag("按 Wiki 编排顺序")
            } }
            item { Panel {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(38.dp).background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                        Icon(painterResource(R.drawable.series_book), null, Modifier.size(21.dp), tint = MaterialTheme.colorScheme.onPrimaryContainer)
                    }
                    Column(Modifier.weight(1f)) {
                        Text("逆模因部", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        Caption("从 SCP-055 起步 · 按中心页顺序")
                    }
                    Tag("主线 ${mainline.count { it.slug in completed }}/19")
                }
                Text("围绕未知与被抹除记忆展开的经典系列：先从核心档案 SCP-055 起步，经《这里没有逆模因部》与 SCP-2256，直面《五-五-五-五-五》。", maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    Button(onClick = { openChapter(next) }, modifier = Modifier.weight(1f)) { Text("继续 · ${next.title}", maxLines = 1, overflow = TextOverflow.Ellipsis) }
                    TextButton(onClick = { detail = true }) { Text("中心页与顺序") }
                }
            } }
        }
        item { Heading(if (query.isBlank() && letter.isEmpty()) "全部故事" else "筛选结果 · ${filtered.size}") }
        if (errors.isNotEmpty()) item { TextButton(onClick = { retry++ }) { Text("在线索引未完整载入 · 重试") } }
        if (filtered.isEmpty()) item { Caption("没有匹配的故事") }
        items(filtered.take(limit), key = { it.slug }) { tale -> StoryRow(tale, tale.slug) { onEntry(tale.slug) } }
        if (filtered.size > limit) item { OutlinedButton(onClick = { limit += 40 }, modifier = Modifier.fillMaxWidth()) { Text("加载更多 · $limit/${filtered.size}") } }
    }
}

@Composable private fun Tag(text: String) {
    Text(text, Modifier.background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(8.dp)).padding(horizontal = 7.dp, vertical = 2.dp), fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer)
}
@Composable private fun Heading(title: String) = Text(title, fontSize = 19.sp, fontWeight = FontWeight.Bold)
@Composable private fun Caption(text: String) = Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
@Composable private fun Panel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    ArchiveCard(modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(7.dp), content = content)
    }
}
@Composable private fun StoryRow(tale: Tale, subtitle: String, open: () -> Unit) {
    Panel(Modifier.clickable(onClick = open)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(tale.title, fontWeight = FontWeight.SemiBold); Caption(subtitle) }
            Text("›", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
