package com.suixin.anomicon.feature.web

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.suixin.anomicon.core.data.ResearchProfile
import com.suixin.anomicon.core.network.PreviewBlock
import com.suixin.anomicon.core.network.WikiPreview
import androidx.compose.ui.graphics.Color
import com.suixin.anomicon.designsystem.ArchiveClassification
import com.suixin.anomicon.designsystem.ArchiveAction
import com.suixin.anomicon.designsystem.ArchiveCard
import kotlin.math.cos
import kotlin.math.sin

internal enum class ReaderTool { Contents, Find }
private enum class Symbol { Back, Star, Web, Contents, Find }

@Composable
private fun ReaderIcon(symbol: Symbol, filled: Boolean = false) {
    val ink = LocalContentColor.current
    Canvas(Modifier.size(20.dp)) {
        val u = size.width / 24f
        fun p(x: Int, y: Int) = Offset(x * u, y * u)
        fun line(x: Int, y: Int, xx: Int, yy: Int) = drawLine(ink, p(x,y), p(xx,yy), 1.8f*u)
        val stroke = Stroke(1.8f * u)
        when (symbol) {
            Symbol.Back -> { line(15,3,6,12); line(6,12,15,21) }
            Symbol.Star -> {
                val path = Path()
                repeat(10) { n ->
                    val angle = -Math.PI / 2 + n * Math.PI / 5
                    val radius = if (n % 2 == 0) 10f else 4.5f
                    val x = (12 + cos(angle).toFloat()*radius)*u
                    val y = (12 + sin(angle).toFloat()*radius)*u
                    if (n == 0) path.moveTo(x,y) else path.lineTo(x,y)
                }; path.close()
                if (filled) drawPath(path, ink) else drawPath(path, ink, style=stroke)
            }
            Symbol.Web -> { drawRect(ink, p(2,4), Size(20*u,16*u), style=stroke); line(2,9,22,9); line(7,14,16,14) }
            Symbol.Find -> { drawCircle(ink, 6.6f*u, p(10,10), style=stroke); line(15,15,22,22) }
            Symbol.Contents -> for (y in listOf(5,12,19)) { drawCircle(ink, 1.2f*u, p(3,y)); line(7,y,21,y) }
        }
    }
}

@Composable
internal fun ReaderToolbar(slug: String, title: String, favorite: Boolean?, original: Boolean, offline: Boolean,
    back: () -> Unit, toggleFavorite: () -> Unit, toggleMode: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal=16.dp, vertical=6.dp),
        horizontalArrangement=Arrangement.spacedBy(6.dp), verticalAlignment=Alignment.CenterVertically) {
        ArchiveAction("返回", back) { ReaderIcon(Symbol.Back) }
        Column(Modifier.weight(1f)) {
            val code = slug.startsWith("scp-")
            Text(if (code) slug.uppercase() else title, maxLines=1, overflow=TextOverflow.Ellipsis, style=MaterialTheme.typography.titleLarge)
            if (code && !title.equals(slug,true)) Text(title, maxLines=1, overflow=TextOverflow.Ellipsis, style=MaterialTheme.typography.bodySmall)
        }
        if (favorite != null) ArchiveAction(if (favorite) "已收藏" else "收藏", toggleFavorite) { ReaderIcon(Symbol.Star, favorite) }
        if (!offline) ArchiveAction(if (original) "原生视图" else "原版网页", toggleMode) { ReaderIcon(Symbol.Web) }
    }
}

@Composable
internal fun ReaderStatus(progress: Float, profile: ResearchProfile?, onTool: (ReaderTool) -> Unit) {
    Surface(modifier=Modifier.fillMaxWidth().padding(horizontal=16.dp), shape=CircleShape, color=MaterialTheme.colorScheme.surfaceContainerLow) {
        Row(Modifier.padding(horizontal=10.dp), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.spacedBy(6.dp)) {
            CircularProgressIndicator(progress={progress}, modifier=Modifier.size(18.dp), strokeWidth=2.dp)
            Text(when { progress >= .98f -> "已读完"; progress > 0 -> "已读 ${(progress*100).toInt()}%"; else -> "开始阅读" }, Modifier.weight(1f), style=MaterialTheme.typography.labelMedium)
            profile?.let { Text("Lv.${it.level}  ${it.xp} XP", style=MaterialTheme.typography.labelMedium) }
            TextButton(onClick={ onTool(ReaderTool.Contents) }, contentPadding=PaddingValues(horizontal=4.dp)) { ReaderIcon(Symbol.Contents); Text("目录") }
            IconButton(onClick={ onTool(ReaderTool.Find) }, modifier=Modifier.size(38.dp).semantics { contentDescription="查找" }) { ReaderIcon(Symbol.Find) }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun ReaderArticleInfo(doc: WikiPreview, online: Boolean, onOriginal: () -> Unit) {
    if (online && doc.hasInteractiveContent) ArchiveCard(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment=Alignment.CenterVertically) {
            Text("本文包含交互组件或音视频，建议切换原版网页体验", Modifier.weight(1f), style=MaterialTheme.typography.bodySmall)
            TextButton(onClick=onOriginal) { Text("原版网页") }
        }
    }
    if (doc.tags.isNotEmpty() || doc.rating != null || doc.objectClass != null) ArchiveCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement=Arrangement.spacedBy(8.dp)) {
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp), verticalAlignment=Alignment.CenterVertically) {
                doc.objectClass?.let { classification ->
                    val color = when (classification.lowercase()) {
                        "safe" -> ArchiveClassification.safe
                        "euclid" -> ArchiveClassification.euclid
                        "keter" -> ArchiveClassification.keter
                        else -> MaterialTheme.colorScheme.primary
                    }
                    Surface(shape = MaterialTheme.shapes.small, color = color, contentColor = Color.White) {
                        Text(classification, Modifier.padding(horizontal=8.dp, vertical=3.dp), style=MaterialTheme.typography.labelLarge)
                    }
                }
                doc.rating?.let { Text(it,style=MaterialTheme.typography.labelLarge) }
            }
            FlowRow(horizontalArrangement=Arrangement.spacedBy(5.dp), verticalArrangement=Arrangement.spacedBy(4.dp)) {
                doc.tags.filterNot { it.equals(doc.objectClass,true) || it == "scp" }.forEach { tag ->
                    Surface(shape=MaterialTheme.shapes.small,color=MaterialTheme.colorScheme.surfaceContainer) { Text(tag, Modifier.padding(horizontal=6.dp, vertical=3.dp), style=MaterialTheme.typography.labelSmall) }
                }
            }
        }
    }
}

private fun PreviewBlock.label() = when(this) {
    is PreviewBlock.Heading -> text
    is PreviewBlock.Paragraph -> text
    is PreviewBlock.Image -> caption.ifEmpty { description }
    is PreviewBlock.Table -> rows.flatten().joinToString(" ")
}

internal fun readerTargets(tool: ReaderTool, doc: WikiPreview?, query: String): List<Pair<Int,String>> =
    doc?.blocks.orEmpty().mapIndexedNotNull { index, block ->
        val text = block.label()
        if (tool == ReaderTool.Contents) {
            when {
                block is PreviewBlock.Heading -> index to text
                block is PreviewBlock.Paragraph -> Regex("^([^：:]{1,16})[：:]").find(text)?.let { index to it.groupValues[1] }
                else -> null
            }
        } else {
            val start = text.indexOf(query.trim(), ignoreCase=true)
            if (query.isBlank() || start < 0) null else index to text.substring((start-12).coerceAtLeast(0)).take(90)
        }
    }

@Composable
internal fun ReaderTools(tool: ReaderTool, doc: WikiPreview?, onClose: () -> Unit, onSelect: (Int) -> Unit) {
    var query by remember { mutableStateOf("") }
    val targets = remember(tool,doc,query) { readerTargets(tool,doc,query) }
    AlertDialog(onDismissRequest=onClose, title={ Text(if (tool==ReaderTool.Find) "查找正文" else "目录") },
        text={ Column {
            if (tool==ReaderTool.Find) OutlinedTextField(query, { query=it }, singleLine=true, label={ Text("关键词") })
            LazyColumn(Modifier.heightIn(max=380.dp)) {
                items(targets) { (index, label) -> Text(label, Modifier.fillMaxWidth().clickable { onSelect(index) }.padding(vertical=12.dp)) }
                if (targets.isEmpty() && (tool==ReaderTool.Contents || query.isNotBlank())) item { Text(if (tool==ReaderTool.Find) "未找到匹配段落" else "正文没有章节标题", Modifier.padding(vertical=12.dp)) }
            }
        } }, confirmButton={ TextButton(onClick=onClose) { Text("关闭") } })
}
