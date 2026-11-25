package com.suixin.anomicon.terminal

import com.suixin.anomicon.designsystem.*
import androidx.compose.ui.text.font.FontFamily
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.suixin.anomicon.core.data.*
import java.time.LocalDate

private val panel @Composable get() = MaterialTheme.colorScheme.surfaceContainerLowest
private val tile @Composable get() = MaterialTheme.colorScheme.surfaceContainer
private val ink @Composable get() = MaterialTheme.colorScheme.onSurface
private val muted @Composable get() = MaterialTheme.colorScheme.onSurfaceVariant
private val accent @Composable get() = MaterialTheme.colorScheme.primary
private val seals = listOf("cert-01" to "锁盒定级", "cert-02" to "外勤编目", "cert-03" to "CRV 抗性")

@Composable
fun TerminalTab(onEntry: (String) -> Unit, onSettings: () -> Unit, onArchive: () -> Unit) {
    val context = LocalContext.current
    val data = remember(context) { NativeData.open(context) }
    val favorites by data.favorites.collectAsState(emptyList())
    val history by data.history.collectAsState(emptyList())
    val series by data.seriesProgress.collectAsState(emptyList())
    val exams by data.assessmentResults.collectAsState(emptyMap())
    val research by data.research.collectAsState(ResearchProfile())
    val shelf by remember(data) { data.library.shelf() }.collectAsState(emptyList())
    val resume = history.filter { (it.offset > 0 || it.progress > 0) && it.progress < 1f }
    var collection by rememberSaveable { mutableStateOf<String?>(null) }
    var detail by rememberSaveable { mutableStateOf<String?>(null) }
    ArchiveSecondaryPage(collection != null)
    BackHandler(collection != null) { collection = null }
    val view = collection
    if (view != null) {
        val entries = when (view) { "全部收藏" -> favorites; "继续阅读" -> resume; else -> history }
        val isShelf = view == "离线书架"
        Column(Modifier.fillMaxSize()) {
            ArchiveDetailBar("$view  ${if (isShelf) shelf.size else entries.size}", { collection = null })
            LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (isShelf) {
                    if (shelf.isEmpty()) item { Empty("暂无离线档案，已保存到本机的档案会显示在这里。") }
                    items(shelf, key = { it.id }) { article ->
                        Entry(article.title, "已存到本机") { onEntry("offline:${article.id}") }
                    }
                } else {
                    if (entries.isEmpty()) item { Empty(if (view == "全部收藏") "暂无收藏" else "暂无阅读记录") }
                    items(entries, key = { it.id }) { row -> Entry(row.title, caption(row)) { onEntry(row.id) } }
                }
            }
        }
        return
    }
    ArchiveLargePage("终端", actions = { SymbolButton("⚙", "设置", onSettings) }) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = LocalArchiveBottomInset.current + 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                ArchiveCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.size(52.dp).background(tile, RoundedCornerShape(14.dp)), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("LV", fontFamily = FontFamily.Monospace, fontSize = 10.sp, color = accent, fontWeight = FontWeight.Bold)
                            Text("${research.level}", fontFamily = FontFamily.Monospace, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = ink)
                        }
                        Column(Modifier.weight(1f)) { Small("档案阅历  累计 ${research.xp} XP", FontFamily.Monospace); Heading(research.rank) }
                        SymbolButton("ⓘ", "档案阅历说明", { detail = "档案阅历" })
                    }
                    Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                        Small(if (research.level == 50) "已达最高等级" else "距 Lv.${research.level + 1}")
                        Small(if (research.target == 0) "最高等级" else "${research.earned} / ${research.target} XP", FontFamily.Monospace)
                    }
                    LinearProgressIndicator(progress = { if (research.target == 0) 1f else research.earned.toFloat() / research.target },
                        modifier = Modifier.fillMaxWidth().height(6.dp).clip(CircleShape), color = accent, trackColor = tile, drawStopIndicator = {})
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        seals.forEach { (id, title) ->
                            val passed = exams[id]?.passed == true
                            Box(Modifier.weight(1f).clip(RoundedCornerShape(9.dp)).background(tile).clickable { detail = title }.padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
                                Text("${if (passed) "✓" else "♙"} $title", color = if (passed) accent else muted, fontSize = 10.sp)
                            }
                        }
                    }
                    Week(research)
                    val minutes = research.totalMs / MINUTE_MS
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Stat("◷  有效阅读", if (minutes >= 60) "${minutes / 60}时 ${minutes % 60}分" else if (minutes == 0L && research.totalMs > 0) "< 1 分钟" else "$minutes 分钟", Modifier.weight(1f))
                        Stat("▣  已研读", "${research.researched} 篇", Modifier.weight(1f))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Stat("★  收藏", "${favorites.size}", Modifier.weight(1f)) { collection = "全部收藏" }
                        Stat("▤  记录", "${history.size}", Modifier.weight(1f)) { collection = "阅读记录" }
                    }
                }
            }
            }
            item { Column(Modifier.padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) { Heading("个人资料库"); Small("阅读进度、藏品与常用本地入口") } }
            item { Entry("离线书架", "已保存 ${shelf.size} 篇") { collection = "离线书架" } }
            item { Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Quick("⬡", "三维档案", Modifier.weight(1f), onArchive)
                Quick("★", "全部收藏", Modifier.weight(1f)) { collection = "全部收藏" }
                Quick("⚙", "阅读设置", Modifier.weight(1f), onSettings)
            } }
            if (resume.isNotEmpty()) {
                item { Section("继续阅读", resume.size) { collection = "继续阅读" } }
                item { val r = resume.first(); Entry(r.title, caption(r), { onEntry(r.id) }) }
            }
            if (series.isNotEmpty()) {
                item { Section("正在跟读", series.size) }
                items(series) { Entry(it.seriesTitle, it.entryTitle, { onEntry(it.entryId) }) }
            }
            if (shelf.isNotEmpty()) {
                item { Section("离线保存", shelf.size) }
                items(shelf) { Entry(it.title, "已存到本机", { onEntry("offline:${it.id}") }) }
            }
            item { Section("收藏", favorites.size) { collection = "全部收藏" } }
            if (favorites.isEmpty()) item { Empty("暂无收藏，阅读时点亮星标即可在这里找到。") }
            items(favorites.take(5)) { Entry(it.title, it.id, { onEntry(it.id) }) }
            item { Section("最近阅读", history.size) { collection = "阅读记录" } }
            if (history.isEmpty()) item { Empty("阅读过的档案将在这里显示。") }
            items(history.filter { it.id != resume.firstOrNull()?.id }.take(5)) { Entry(it.title, caption(it), { onEntry(it.id) }) }
        }
    }
    detail?.let { title ->
        val seal = seals.firstOrNull { it.second == title }
        val text = if (seal == null) "有效阅读每分钟 +1 XP，单篇累计满 1 分钟额外 +8 XP。每日最多计入 180 分钟。首次通过基金会考核可获印章与 15 至 25 XP。"
        else if (exams[seal.first]?.passed == true) "已签发此资质印章。最高成绩 ${exams.getValue(seal.first).score} / 5。" else "尚未签发。前往基金会页签完成对应考核，答对至少 4 题即可获得此印章。"
        AlertDialog(onDismissRequest = { detail = null }, title = { Text(title) }, text = { Text(text) }, confirmButton = { TextButton(onClick = { detail = null }) { Text("知道了") } })
    }
}

private fun caption(row: ReadingEntry) = when { row.progress >= 1f -> "已读完"; row.progress > 0f -> "阅读进度 ${(row.progress * 100).toInt()}%"; row.offset > 0 -> "已保存阅读位置"; else -> row.id }
@Composable private fun Small(text: String, family: FontFamily? = null) { Text(text, fontFamily = family, color = muted, fontSize = 12.sp, lineHeight = 16.sp) }
@Composable private fun Heading(text: String) { Text(text, color = ink, fontSize = 20.sp, fontWeight = FontWeight.Bold) }
@Composable private fun SymbolButton(mark: String, label: String, onClick: () -> Unit) {
    ArchiveAction(label, onClick) { Text(mark, fontSize = 20.sp, color = ink) }
}
@Composable private fun Week(profile: ResearchProfile) {
    val today = LocalDate.now()
    val dates = (6 downTo 0).map { today.minusDays(it.toLong()) }
    val peak = maxOf(20 * MINUTE_MS, dates.maxOf { profile.daily[it] ?: 0 })
    val todayMs = profile.daily[today] ?: 0
    Row(Modifier.fillMaxWidth().background(tile, RoundedCornerShape(14.dp)).padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) { Small("今日研读"); Text("${if (todayMs in 1 until MINUTE_MS) "< 1" else todayMs / MINUTE_MS} / 180 分钟", color = ink, fontSize = 13.sp, fontWeight = FontWeight.Bold) }
        dates.forEach { day ->
            val ms = profile.daily[day] ?: 0L
            Column(Modifier.width(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.width(7.dp).height(24.dp).clip(CircleShape).background(muted.copy(alpha = .14f)), contentAlignment = Alignment.BottomCenter) {
                    if (ms > 0) Spacer(Modifier.fillMaxWidth().fillMaxHeight((ms.toFloat() / peak).coerceAtLeast(.22f)).background(accent, CircleShape))
                }
                Text("一二三四五六日"[day.dayOfWeek.value - 1].toString(), color = if (day == today) accent else muted, fontSize = 9.sp)
            }
        }
    }
}
@Composable private fun Stat(label: String, value: String, modifier: Modifier, click: (() -> Unit)? = null) {
    Column(modifier.clip(RoundedCornerShape(14.dp)).background(tile).then(if (click != null) Modifier.clickable(onClick = click) else Modifier).heightIn(min = 68.dp).padding(12.dp), verticalArrangement = Arrangement.SpaceBetween) {
        Small(if (click == null) label else "$label  ›"); Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ink)
    }
}
@Composable private fun Quick(mark: String, title: String, modifier: Modifier, click: () -> Unit) {
    Column(modifier.clip(RoundedCornerShape(16.dp)).background(panel).clickable(onClick = click).padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(mark, fontSize = 18.sp, color = accent); Text(title, color = ink, fontSize = 13.sp, fontWeight = FontWeight.Bold)
    }
}
@Composable private fun Section(label: String, count: Int, more: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(label, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = ink); Small("   $count"); Spacer(Modifier.weight(1f)); if (more != null) TextButton(onClick = more) { Text("全部 ›") } }
}
@Composable private fun Empty(label: String) { Text(label, Modifier.fillMaxWidth().background(panel, RoundedCornerShape(16.dp)).padding(18.dp), color = muted, fontSize = 13.sp) }
@Composable private fun Entry(title: String, subtitle: String, click: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(panel).clickable(onClick = click).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) { Text(title, fontWeight = FontWeight.Bold, color = ink); Small(subtitle) }; Text("›", color = accent)
    }
}
