package com.suixin.anomicon.feature.web

import android.annotation.SuppressLint
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
    val initial = remember(entry) { wikiSlug(entry) }
    if (initial == null) {
        Column(modifier.padding(20.dp)) {
            Text("无法识别此 Wiki 条目")
            TextButton(onClick = onBack) { Text("返回") }
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
    key(slug) {
        var attempt by remember { mutableIntStateOf(0) }
        var document by remember { mutableStateOf<WikiPreview?>(null) }
        var message by remember { mutableStateOf<String?>(null) }
        val position = rememberLazyListState()
        LaunchedEffect(slug, attempt) {
            message = null
            try {
                document = wiki.preview(slug)
            } catch (error: IOException) {
                message = "当前无法读取正文，请检查网络后重试。"
            }
        }
        Column(modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = back) { Text("返回") }
                Text(document?.title ?: slug.uppercase(), Modifier.weight(1f), maxLines = 1,
                    overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = {
                    original = !original
                }) { Text(if (original) "原生视图" else "原版网页") }
            }
            HorizontalDivider()
            when {
                original -> OriginalPage(slug, { webView = it }, openNative, loadOriginal)
                message != null -> Column(Modifier.padding(20.dp)) {
                    Text(message!!)
                    TextButton(onClick = { attempt++ }) { Text("重新加载") }
                }
                document == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                else -> LazyColumn(state = position, contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    items(document!!.blocks) { block -> NativeBlock(block) { next ->
                        if (next != slug) openNative(next)
                    } }
                }
            }
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
            }, style = MaterialTheme.typography.bodyLarge)
        }
        is PreviewBlock.Image -> AsyncImage(model = block.url, contentDescription = block.description.ifBlank { null },
            contentScale = ContentScale.FillWidth, modifier = Modifier.fillMaxWidth())
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
private fun OriginalPage(slug: String, bind: (WebView?) -> Unit, openNative: (String) -> Unit,
    loadOriginal: (WebView, String) -> Unit) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context -> WebView(context).apply {
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
                override fun onPageFinished(view: WebView, url: String) {
                    view.evaluateJavascript("""(function(){document.querySelectorAll('#page-content table').forEach(function(t){if(t.parentElement.dataset.anomiconScroll)return;var w=document.createElement('div');w.dataset.anomiconScroll='1';w.style.cssText='max-width:100%;overflow-x:auto';t.parentNode.insertBefore(w,t);w.appendChild(t)})})();""", null)
                }
            }
            bind(this)
            loadOriginal(this, WIKI_BASE + slug)
        } },
        onRelease = { view -> bind(null); view.stopLoading(); view.destroy() },
    )
}
