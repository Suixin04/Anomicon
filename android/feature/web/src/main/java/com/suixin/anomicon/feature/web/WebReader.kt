package com.suixin.anomicon.feature.web

import android.annotation.SuppressLint
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ScrollState
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.draw.clip
import kotlinx.coroutines.launch
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.suixin.anomicon.core.data.NativeData
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.suixin.anomicon.core.network.parseWikiPreview
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import coil3.compose.AsyncImage
import com.suixin.anomicon.core.network.PreviewBlock
import com.suixin.anomicon.core.network.WIKI_BASE
import com.suixin.anomicon.core.network.WikiPreview
import com.suixin.anomicon.core.network.WikiRepository
import com.suixin.anomicon.core.network.wikiSlug
import java.io.IOException

private val wiki by lazy { WikiRepository() }

@Composable
fun WebReader(entry: String, onBack: () -> Unit, modifier: Modifier = Modifier) {
    ReaderContent(entry, onBack, modifier) { view, url -> view.loadUrl(url) }
}

@Composable
internal fun ReaderContent(entry: String, onBack: () -> Unit, modifier: Modifier,
    loadOriginal: (WebView, String) -> Unit) {
    val fromShelf = entry.startsWith("offline:")
    val initial = remember(entry) { wikiSlug(entry.removePrefix("offline:")) }
    val data = NativeData.open(LocalContext.current)
    if (initial == null) {
        Column(modifier.padding(20.dp)) {
            Text("无法识别此 Wiki 条目")
            FilledTonalButton(onClick = onBack) { Text("返回") }
        }
        return
    }
    var history by rememberSaveable(initial) { mutableStateOf(arrayListOf(initial)) }
    val slug = history.last()
    var original by rememberSaveable(initial) { mutableStateOf(false) }
    var webView by remember { mutableStateOf<WebView?>(null) }
    var previousWebModes by rememberSaveable(initial) { mutableStateOf(arrayListOf<Boolean>()) }
    val openNative: (String) -> Unit = { next ->
        previousWebModes = ArrayList(previousWebModes + original)
        history = ArrayList(history + next)
        original = false
    }
    val back: () -> Unit = {
        val view = webView
        if (original && view?.canGoBack() == true) view.goBack()
        else if (history.size > 1) {
            original = previousWebModes.last()
            previousWebModes = ArrayList(previousWebModes.dropLast(1))
            history = ArrayList(history.dropLast(1))
        }
        else onBack()
    }
    BackHandler(onBack = back)
    val offline = fromShelf && history.size == 1
    key(slug, offline) {
        val session = rememberReaderSession(slug, data)
        val favorites by data.favorites.collectAsStateWithLifecycle(initialValue = null)
        val favorite = favorites?.any { it.id == slug }
        var attempt by remember { mutableIntStateOf(0) }
        var document by remember { mutableStateOf<WikiPreview?>(null) }
        var message by remember { mutableStateOf<String?>(null) }

        LaunchedEffect(slug, attempt) {
            message = null
            try {
                document = if (offline) offlinePreview(data, slug) else wiki.preview(slug)
            } catch (error: IOException) {
                message = if (offline) "无法读取离线副本：${error.localizedMessage}" else "当前无法读取正文，请检查网络后重试。"
            }
        }
        val assets = LocalContext.current.assets
        val catalogTitle by produceState<String?>(null, slug) {
            val match = Regex("scp-(cn-)?([0-9]+)").matchEntire(slug) ?: return@produceState
            val number = match.groupValues[2].toIntOrNull() ?: return@produceState
            val base = if (match.groupValues[1].isEmpty()) "scp-series" else "scp-series-cn"
            val series = number / 1000 + 1
            val name = (if (series == 1) base else "$base-$series") + ".html"
            value = withContext(Dispatchers.IO) {
                if (name !in assets.list("discovery").orEmpty()) null else assets.open("discovery/$name").bufferedReader().use {
                    com.suixin.anomicon.core.network.seriesSubtitle(it.readText(), slug)
                }
            }
        }
        val title = document?.title ?: slug.uppercase()
        SideEffect { if (session != null) session.title = title }
        val scroll = rememberScrollState()
        val offsets = remember(document) { mutableMapOf<Int, Int>() }
        val scope = rememberCoroutineScope()
        val profile by data.research.collectAsStateWithLifecycle(initialValue = null)
        var tool by remember { mutableStateOf<ReaderTool?>(null) }
        var saving by remember { mutableStateOf(false) }
        var saveResult by remember { mutableStateOf<String?>(null) }
        val snapshot = document
        val save: (() -> Unit)? = if (offline || original || snapshot == null || saving) null else {{
            saving = true
            saveResult = null
            scope.launch {
                val urls = snapshot.blocks.filterIsInstance<PreviewBlock.Image>().map { it.url }.distinct()
                try {
                    val saved = data.saveOffline(slug, snapshot.title, snapshot.offlineHtml, urls) { url, limit ->
                        try { com.suixin.anomicon.core.network.downloadOfflineImage(url, limit) }
                        catch (_: IOException) { null } // An unavailable image is counted in the result.
                    }
                    saveResult = "已保存到离线书架 · 配图 $saved/${urls.size}" +
                        if (snapshot.hasInteractiveContent) " · 互动内容需联网" else ""
                } catch (e: IOException) {
                    saveResult = "保存失败：${e.localizedMessage}"
                } catch (e: android.database.sqlite.SQLiteException) {
                    saveResult = "书架写入失败，请检查可用存储后重试。"
                } finally { saving = false }
            }
        }}
        Column(modifier.fillMaxSize()) {
            ReaderToolbar(slug, catalogTitle ?: title, favorite, original, offline, back,
                toggleFavorite = { session?.favorite(favorite != true) }, toggleMode = { original = !original }, save = save)
            if (saving) LinearProgressIndicator(Modifier.fillMaxWidth())
            saveResult?.let { Snackbar(action = { TextButton(onClick = { saveResult = null }) { Text("关闭") } }) { Text(it) } }
            if (!original && document != null) {
                ReaderStatus(session?.position?.progress ?: 0f, profile, onTool = { tool = it })
            }
            tool?.let { selected ->
                ReaderTools(selected, document, onClose = { tool = null }, onSelect = { index ->
                    tool = null
                    offsets[index]?.let { offset -> scope.launch { scroll.scrollTo(offset) } }
                })
            }
            when {
                session == null -> CircularProgressIndicator()
                original -> OriginalPage(session, slug, { webView = it }, openNative, loadOriginal)
                message != null -> Column(Modifier.padding(20.dp)) {
                    Text(message!!)
                    FilledTonalButton(onClick = { attempt++ }) { Text("重新加载") }
                }
                document == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                else -> NativePage(document!!, session, scroll, offsets, !offline, { original = true }, openNative)

            }
        }
    }
}

private suspend fun offlinePreview(data: NativeData, slug: String): WikiPreview = withContext(Dispatchers.IO) {
    val (row, files) = data.library.revision(slug) ?: throw IOException("离线副本不存在")
    val images = files.filter { data.offlineFile(it.path).isFile }.associate { it.url.replaceFirst("http://", "https://") to data.offlineFile(it.path).toURI().toString() }
    val html = data.offlineFile(row.htmlPath).readText()
    val preview = parseWikiPreview("<main id='page-content'>$html</main>", slug)
    preview.copy(title = row.title, blocks = preview.blocks.mapNotNull { block ->
        if (block is PreviewBlock.Image) images[block.url]?.let { block.copy(url = it) } ?: PreviewBlock.Paragraph("配图未离线保存" + block.caption.takeIf { it.isNotBlank() }?.let { " · $it" }.orEmpty()) else block
    })
}

@Composable
private fun NativePage(document: WikiPreview, session: ReaderSession, scroll: ScrollState,
    offsets: MutableMap<Int, Int>, online: Boolean, onOriginal: () -> Unit, open: (String) -> Unit) {
    val density = LocalDensity.current.density
    TrackReading(session)
    LaunchedEffect(session, scroll) {
        val range = snapshotFlow { scroll.maxValue }.first { it != Int.MAX_VALUE }
        scroll.scrollTo(session.position.restore(range, density))
        snapshotFlow { scroll.value }.drop(1).collect { y ->
            session.interact()
            session.move(ReaderPosition.at(y, scroll.maxValue, density))
        }
    }
    Column(Modifier.fillMaxSize().pointerInput(session) {
        awaitPointerEventScope { while (true) { awaitPointerEvent(PointerEventPass.Initial); session.interact() } }
    }.verticalScroll(scroll).padding(horizontal = 20.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ReaderArticleInfo(document, online, onOriginal)
        document.blocks.forEachIndexed { index, block ->
            Box(Modifier.fillMaxWidth().onGloballyPositioned { offsets[index] = it.positionInParent().y.toInt() }) {
                NativeBlock(block) { if (it != document.slug) open(it) }
            }
        }
        if (document.credits.isNotBlank()) {
            var expanded by remember { mutableStateOf(false) }
            FilledTonalButton(onClick = { expanded = !expanded }) { Text(if (expanded) "收起署名与许可" else "查看署名与许可") }
            if (expanded) Text(document.credits, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun NativeBlock(block: PreviewBlock, open: (String) -> Unit) {
    when (block) {
        is PreviewBlock.Heading -> Text(block.text, style = MaterialTheme.typography.titleLarge)
        is PreviewBlock.Paragraph -> {
            val color = MaterialTheme.colorScheme.primary
            Text(buildAnnotatedString {
                append(block.text)
                block.links.forEach { link -> addLink(LinkAnnotation.Clickable(link.slug,
                    TextLinkStyles(style = SpanStyle(color = color)), { open(link.slug) }), link.start, link.end) }
            }, style = MaterialTheme.typography.bodyLarge.copy(fontSize = 18.sp, lineHeight = 29.sp))
        }
        is PreviewBlock.Image -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
            AsyncImage(model = block.url, contentDescription = block.description.ifBlank { null },
            contentScale = ContentScale.FillWidth, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).clip(MaterialTheme.shapes.large))
            if (block.caption.isNotBlank()) Text(block.caption, Modifier.fillMaxWidth().padding(top = 6.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall)
        }
        is PreviewBlock.Table -> Surface(shape = MaterialTheme.shapes.medium,
            color = MaterialTheme.colorScheme.surfaceContainerLow) {
            Column(Modifier.horizontalScroll(rememberScrollState()).padding(8.dp)) {
                block.rows.forEach { row ->
                    Row { row.forEach { cell -> Text(cell, Modifier.width(144.dp).padding(8.dp), style = MaterialTheme.typography.bodyMedium) } }
                    HorizontalDivider()
                }
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun OriginalPage(session: ReaderSession, slug: String, bind: (WebView?) -> Unit, openNative: (String) -> Unit,
    loadOriginal: (WebView, String) -> Unit) {
    var readable by remember { mutableStateOf(false) }
    if (readable) TrackReading(session)
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context -> object : WebView(context) {
            val range get() = (computeVerticalScrollRange() - height).coerceAtLeast(0)
        }.apply {
            val page = this
            var touched = false
            setOnTouchListener { _, event ->
                if (event.actionMasked == android.view.MotionEvent.ACTION_DOWN) touched = true
                session.interact()
                false
            }
            setOnScrollChangeListener { _, _, y, _, _ ->
                if (readable && touched) session.move(ReaderPosition.at(y.coerceAtLeast(0), range, resources.displayMetrics.density))
            }
            settings.javaScriptEnabled = true // Wikidot collapsibles and tabs require script execution.
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.builtInZoomControls = true
            settings.displayZoomControls = false
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val uri = request.url
                    if (!request.isForMainFrame) return false
                    if (uri.host != "scp-wiki-cn.wikidot.com" || uri.scheme !in setOf("http", "https")) return true
                    val target = wikiSlug(uri.toString())
                    if (target != null && target != slug && request.hasGesture() && !request.isRedirect) {
                        openNative(target)
                        return true
                    }
                    return uri.scheme != "https"
                }
                override fun onPageStarted(view: WebView, url: String, icon: android.graphics.Bitmap?) {
                    readable = false
                    touched = false
                }
                override fun onPageFinished(view: WebView, url: String) {
                    if (wikiSlug(url) != slug || readable) return
                    view.evaluateJavascript("!!document.querySelector('#page-content') && !document.querySelector('#page-content #edit-page-form')") { hasBody ->
                        if (hasBody == "true" && view.isAttachedToWindow) {
                            page.scrollTo(0, session.position.restore(page.range, page.resources.displayMetrics.density))
                            readable = true
                        }
                    }
                    view.evaluateJavascript("""(function(){document.querySelectorAll('#page-content table').forEach(function(t){if(t.parentElement.dataset.anomiconScroll)return;var w=document.createElement('div');w.dataset.anomiconScroll='1';w.style.cssText='max-width:100%;overflow-x:auto';t.parentNode.insertBefore(w,t);w.appendChild(t)})})();""", null)
                }
            }
            bind(this)
            loadOriginal(this, WIKI_BASE + slug)
        } },
        onRelease = { view -> bind(null); view.setOnScrollChangeListener(null); view.stopLoading(); view.destroy() },
    )
}
