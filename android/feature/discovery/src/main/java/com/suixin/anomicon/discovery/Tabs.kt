package com.suixin.anomicon.discovery

import com.suixin.anomicon.designsystem.*
import androidx.compose.ui.text.font.FontFamily
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.lazy.staggeredgrid.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import coil3.compose.AsyncImage
import com.suixin.anomicon.core.network.wikiSlug
import kotlinx.coroutines.launch
import java.io.IOException
import java.time.LocalDate

@Composable private fun store(): DiscoveryStore {
    val context = LocalContext.current.applicationContext
    return remember(context) { DiscoveryStore(context) }
}
@Composable private fun Heading(text: String, large: Boolean = true) = Text(text, style = if (large) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
@Composable private fun Hint(text: String) = Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
@Composable private fun HeaderActions( archive: (() -> Unit)? = null, search: ()->Unit) {
    ArchiveAction("搜索", search) { ArchiveGlyph("search") }
    if (archive != null) {
        Spacer(Modifier.width(8.dp))
        ArchiveAction("三维档案", archive) { ArchiveGlyph("view_in_ar") }
    }
}
@Composable private fun Pill(text: String, selected: Boolean, click: ()->Unit) {
    Surface(onClick = click, shape = CircleShape, color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHigh) {
        Text(text, Modifier.padding(horizontal = 13.dp, vertical = 6.dp), style = MaterialTheme.typography.bodyMedium)
    }
}
@Composable private fun ArticleCard(store: DiscoveryStore, entry: Entry, large: Boolean, progress: Float?, open: ()->Unit) {
    var preview by remember(entry.id) { mutableStateOf<Preview?>(null) }
    var failed by remember(entry.id) { mutableStateOf(false) }
    LaunchedEffect(entry.id) { try { preview = store.preview(entry.id) } catch (e: IOException) { failed = true } }
    ArchiveCard(onClick = open, modifier = Modifier.fillMaxWidth()) {
        Column {
            val url = preview?.image
            val cover = localCovers[entry.id]
            if (cover != null) {
                Image(androidx.compose.ui.res.painterResource(cover.first), entry.title,
                    Modifier.fillMaxWidth().aspectRatio(if (large) 2f else cover.second), contentScale = ContentScale.Crop)
            } else if (url != null) {
                val model by produceState<Any?>(null, url) { value = store.image(url) }
                AsyncImage(model, entry.title, Modifier.fillMaxWidth().aspectRatio(if (large) 2f else 1.4f), contentScale = ContentScale.Crop)
            } else if (large || preview == null && !failed) {
                Box(Modifier.fillMaxWidth().aspectRatio(if (large) 2f else 1.4f).background(MaterialTheme.colorScheme.surfaceContainerHigh), contentAlignment = Alignment.Center) {
                    Text(entry.id.uppercase(), fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.Medium)
                }
            }
            Column(Modifier.padding(if (large) 17.dp else 12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) { Text(entry.id.uppercase(), fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary); if (large) { Spacer(Modifier.width(6.dp)); Hint(if (entry.id.startsWith("scp-cn")) "中文原创" else "主站译文") } }
                Heading(entry.title, large)
                progress?.let { Hint(if (it >= 1f) "已读完" else "已读 ${(it*100).toInt()}%") }
                Text(preview?.text?.takeIf { it.isNotBlank() } ?: entry.detail, maxLines = if (large) 4 else 3, overflow = TextOverflow.Ellipsis, style = if (large) MaterialTheme.typography.bodyMedium else MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable fun CatalogTab(onEntry: (String)->Unit, onArchive: (() -> Unit)? = null) {
    val store = store()
    var searching by rememberSaveable { mutableStateOf(false) }
    var key by rememberSaveable { mutableStateOf(series.first().key) }
    ArchiveSecondaryPage(searching)
    if (searching) { Search(store, onEntry) { searching = false }; return }
    val selected = series.first { it.key == key }
    val reads by store.data.history.collectAsState(emptyList())
    val completed by store.data.completedIds.collectAsState(emptySet())
    val progress = remember(reads, completed) { reads.associate { it.id to it.progress } + completed.associateWith { 1f } }
    ArchiveLargePage("图鉴", actions = { HeaderActions(onArchive) { searching = true } }) {
        Column(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            ArchiveSegments(listOf("主站译文", "中文原创"), if (selected.cn) 1 else 0) { branch ->
                val cn = branch == 1
                if (cn != selected.cn) key = series.first { it.cn == cn }.key
            }
            key(selected.cn) { Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) { series.filter { it.cn == selected.cn }.forEach { s -> Pill(s.label, s == selected) { key = s.key } } } }
            key(key) {
                var rows by remember { mutableStateOf(emptyList<Entry>()) }; var error by remember { mutableStateOf("") }; var refresh by remember { mutableIntStateOf(0) }
                LaunchedEffect(refresh) { try { rows = store.index(key,refresh > 0); error = "" } catch(e: IOException) { error = "目录更新失败，可重试" } }
                if(error.isNotEmpty()) TextButton(onClick = { refresh++ }) { Text(error) }
                LazyVerticalStaggeredGrid(StaggeredGridCells.Adaptive(146.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalItemSpacing = 10.dp, contentPadding = PaddingValues(bottom = LocalArchiveBottomInset.current + 16.dp)) {
                    items(rows, key = { it.id }) { entry -> ArticleCard(store, entry, false, progress[entry.id]) { onEntry(entry.id) } }
                    item(span = StaggeredGridItemSpan.FullLine) { TextButton(onClick = { refresh++ }) { Text("刷新目录") } }
                }
            }
        }
    }
}

@Composable fun DiscoveryTab(onEntry: (String)->Unit) {
    val store = store(); var searching by rememberSaveable { mutableStateOf(false) }
    var collection by rememberSaveable { mutableStateOf<String?>(null) }
    ArchiveSecondaryPage(searching || collection != null)
    if (searching) { Search(store, onEntry) { searching = false }; return }
    collection?.let { key ->
        BackHandler { collection = null }
        Column(Modifier.fillMaxSize()) {
            ArchiveDetailBar(key, { collection = null })
            Collection(store, key, true, onEntry)
        }
        return
    }
    var batch by rememberSaveable { mutableIntStateOf(0) }
    var all by remember { mutableStateOf(emptyList<Entry>()) }
    var indexError by remember { mutableStateOf(false) }
    LaunchedEffect(store) {
        try { all = store.all() } catch (e: IOException) { indexError = true }
    }
    val day = LocalDate.now().toEpochDay().toInt()
    val pool = all.ifEmpty { starter }
    val deck = remember(day, batch, pool) {
        val cards = dailyDeck(pool, 31 * day + batch)
        if (pool === starter) cards.sortedBy { it.id !in localCovers } else cards
    }
    val titles = remember(all) { (starter + all).associateBy { it.id } }
    ArchiveLargePage("探索", actions = { HeaderActions { searching = true } }) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp,end = 16.dp,bottom = LocalArchiveBottomInset.current + 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Heading("今日推荐"); Hint("每日从主站与中文原创档案库随机调阅一组条目") }
            item { key(batch) {
                val pager = rememberPagerState { deck.size }
                HorizontalPager(pager, pageSpacing = 10.dp) { i -> ArticleCard(store,deck[i],true,null) { onEntry(deck[i].id) } }
                Row(Modifier.fillMaxWidth().padding(vertical=8.dp),verticalAlignment = Alignment.CenterVertically) { Hint("${pager.currentPage+1} / ${deck.size}　左右滑动切换，点按卡片查阅全文"); Spacer(Modifier.weight(1f)); TextButton(onClick = { batch++ }) { Text("换一组") } }
            } }
            if (indexError) item { Hint("完整目录暂时不可用，当前展示随包推荐") }
            item { Feed(store, "top-rated-pages", "热门原创", titles, onEntry) }
            listOf("最近更新", "轻松一下").forEach { name -> item(key = name) {
                Heading(name)
                Collection(store, name, false, onEntry) { collection = name }
            } }
        }
    }
}
@Composable private fun Feed(store: DiscoveryStore, key: String, title: String, titles: Map<String,Entry>, open: (String)->Unit) {
    var rows by remember { mutableStateOf(emptyList<Entry>()) }; var expanded by rememberSaveable { mutableStateOf(false) }; var refresh by remember { mutableIntStateOf(0) }; var error by remember { mutableStateOf("") }
    LaunchedEffect(refresh) { try { rows = store.index(key,refresh>0); error = "" } catch(e: IOException) { error = "更新失败" } }
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Heading(title); if(key == "top-rated-pages") Hint("中文分部高评分原创档案")
        ArchiveCard(Modifier.fillMaxWidth()) { Column {
            rows.take(if(expanded) rows.size else 6).forEachIndexed { i,e -> Row(Modifier.fillMaxWidth().clickable { open(e.id) }.padding(12.dp),verticalAlignment = Alignment.CenterVertically) {
                Text("${i+1}", Modifier.width(32.dp),color = MaterialTheme.colorScheme.primary); Column(Modifier.weight(1f)) { Text(titles[e.id]?.title ?: e.title,maxLines=2,overflow=TextOverflow.Ellipsis); Hint(e.id) }; Hint(if(key=="top-rated-pages") "+${e.detail.trimStart('+')}" else e.detail)
            } }
            Row { TextButton(onClick={expanded=!expanded}) { Text(if(expanded) "收起" else "显示更多") }; TextButton(onClick={refresh++}) { Text(if(error.isBlank()) "刷新" else "$error · 重试") } }
        } }
    }
}

@Composable private fun Collection(store: DiscoveryStore, name: String, full: Boolean, open: (String) -> Unit, more: () -> Unit = {}) {
    val recent = name == "最近更新"
    val sources = if (recent) feeds.filterKeys { it.startsWith("most-recently") } else jokeSources
    var entries by remember(name) { mutableStateOf(emptyList<Entry>()) }
    var failed by remember(name) { mutableStateOf(false) }
    var retry by remember { mutableIntStateOf(0) }
    LaunchedEffect(name, retry) {
        failed = false
        val combined = mutableListOf<Entry>()
        for ((source, label) in sources) {
            try {
                combined += store.index(source, retry > 0).map { it.copy(detail = listOf(label, it.detail).distinct().joinToString(" · ")) }
            } catch (e: IOException) { failed = true }
        }
        entries = if (recent) combined.sortedByDescending { recentDate(it.detail) } else combined.distinctBy { it.id }.shuffled(kotlin.random.Random(LocalDate.now().toEpochDay()))
    }
    val row: @Composable (Entry) -> Unit = { entry ->
        ArchiveCard(onClick = { open(entry.id) }, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp)) { Text(entry.title); Hint(entry.detail) }
        }
    }
    if (full) {
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (failed) item { TextButton(onClick = { retry++ }) { Text("索引未完整加载 · 重试") } }
            items(entries) { row(it) }
        }
    } else Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        entries.take(6).forEach { row(it) }
        if (failed) TextButton(onClick = { retry++ }) { Text("重试") }
        TextButton(onClick = more) { Text("查看更多") }
    }
}

@Composable private fun Search(store: DiscoveryStore, open: (String)->Unit, close: ()->Unit) {
    BackHandler(onBack = close)
    var query by rememberSaveable { mutableStateOf("") }; val past by store.data.searchHistory.collectAsState(emptyList()); val scope = rememberCoroutineScope()
    var index by remember { mutableStateOf(emptyList<Entry>()) }; var error by remember { mutableStateOf("") }
    var category by rememberSaveable { mutableIntStateOf(0) }
    var refresh by remember { mutableIntStateOf(0) }
    LaunchedEffect(refresh) {
        val loaded = mutableListOf<Entry>()
        error = ""
        for (key in series.map { it.key } + taleSources) {
            try { loaded += store.index(key, refresh > 0) } catch (e: IOException) { error = "部分索引未载入" }
            index = loaded.distinctBy { it.id }
        }
    }
    val hits = remember(index, query, category) { matches(index,query).filter { category == 0 || (it.detail == "故事") == (category == 2) } }
    val direct = remember(query) { directTarget(query) }
    fun select(id: String) { scope.launch { store.data.saveSearch(query); open(id) } }
    Column(Modifier.fillMaxSize()) {
        ArchiveDetailBar("搜索", close)
        OutlinedTextField(query,{query=it},Modifier.fillMaxWidth().padding(horizontal = 16.dp),singleLine=true, placeholder={Text("搜索编号、标题、故事或 Wiki 链接")})
        if (query.isNotBlank()) ArchiveSegments(listOf("全部", "档案", "故事"), category) { category = it }
        if (error.isNotBlank()) TextButton(onClick = { refresh++ }) { Text("$error · 重试") }
        LazyColumn(contentPadding=PaddingValues(start = 16.dp, end = 16.dp, bottom = LocalArchiveBottomInset.current + 16.dp)) {
            if(query.isBlank()) { item { TextButton(onClick = { index.randomOrNull()?.let { open(it.id) } }, enabled = index.isNotEmpty()) { Text("随机发现") } }; item { Row(verticalAlignment=Alignment.CenterVertically) { Text("搜索历史",Modifier.weight(1f)); if(past.isNotEmpty()) TextButton(onClick={scope.launch { store.data.clearSearchHistory() }}) { Text("清空") } } }; items(past) { q -> TextButton(onClick={query=q}) { Text(q) } } }
            else { if(direct!=null) item { TextButton(onClick={select(direct)}) { Text("直接打开 ${direct.uppercase()}") } }; items(hits,key={it.id}) { entry -> Column(Modifier.fillMaxWidth().clickable { select(entry.id) }.padding(vertical=10.dp)) { Text(entry.title); Hint(entry.id.uppercase()) } }; if(hits.isEmpty()) item { Hint(error.ifBlank { if(index.isEmpty()) "正在加载索引…" else "没有匹配的目录条目" }) } }
        }
    }
}
