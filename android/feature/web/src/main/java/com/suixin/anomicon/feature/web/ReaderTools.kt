package com.suixin.anomicon.feature.web

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.suixin.anomicon.core.data.ResearchProfile
import com.suixin.anomicon.core.network.PreviewBlock
import com.suixin.anomicon.core.network.WikiPreview
import androidx.compose.ui.graphics.Color
import com.suixin.anomicon.designsystem.ArchiveClassification
import com.suixin.anomicon.designsystem.ArchiveTypography
import com.suixin.anomicon.designsystem.ArchiveGlyph
import com.suixin.anomicon.designsystem.ArchiveAction
import com.suixin.anomicon.designsystem.ArchiveDetailBar
import com.suixin.anomicon.designsystem.ArchiveCard

internal enum class ReaderTool { Contents, Find }
@Composable
private fun ReaderAction(label: String, glyph: String, onClick: () -> Unit) {
    ArchiveAction(label, onClick) { ArchiveGlyph(glyph) }
}

@Composable
internal fun ReaderToolbar(slug: String, title: String, favorite: Boolean?, original: Boolean, offline: Boolean,
    back: () -> Unit, toggleFavorite: () -> Unit, toggleMode: () -> Unit, save: (() -> Unit)? = null) {
    val numbered = slug.startsWith("scp-")
    ArchiveDetailBar(
        title = if (numbered) slug.uppercase() else title,
        onBack = back,
        subtitle = if (numbered && !title.equals(slug, true)) title else null,
    ) {
        if (save != null) ReaderAction("保存离线副本", "download", save)
        if (favorite != null) ReaderAction(if (favorite) "已收藏" else "收藏", if (favorite) "star" else "star_outline", toggleFavorite)
        if (!offline) ReaderAction(if (original) "原生视图" else "原版网页", if (original) "menu_book" else "web", toggleMode)
    }
}

@Composable
internal fun ReaderStatus(progress: Float, profile: ResearchProfile?, onTool: (ReaderTool) -> Unit) {
    Surface(modifier=Modifier.fillMaxWidth().padding(horizontal=16.dp), shape=MaterialTheme.shapes.large, color=MaterialTheme.colorScheme.surfaceContainerLow) {
        Row(Modifier.padding(horizontal=10.dp), verticalAlignment=Alignment.CenterVertically, horizontalArrangement=Arrangement.spacedBy(6.dp)) {
            CircularProgressIndicator(progress={progress}, modifier=Modifier.size(18.dp), strokeWidth=2.dp)
            Text(when { progress >= .98f -> "已读完"; progress > 0 -> "已读 ${(progress*100).toInt()}%"; else -> "开始阅读" }, Modifier.weight(1f), style=MaterialTheme.typography.labelMedium)
            profile?.let { Text("Lv.${it.level}  ${it.xp} XP", style = ArchiveTypography.metadata) }
            ReaderAction("目录", "toc", { onTool(ReaderTool.Contents) })
            ReaderAction("查找", "search", { onTool(ReaderTool.Find) })
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun ReaderArticleInfo(doc: WikiPreview, online: Boolean, onOriginal: () -> Unit) {
    if (online && doc.hasInteractiveContent) ArchiveCard(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment=Alignment.CenterVertically) {
            Text("本文包含交互组件或音视频，建议切换原版网页体验", Modifier.weight(1f), style=MaterialTheme.typography.bodySmall)
            FilledTonalButton(onClick=onOriginal) { Text("原版网页") }
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
                        Text(classification, Modifier.padding(horizontal=8.dp, vertical=3.dp), style = ArchiveTypography.metadata)
                    }
                }
                doc.rating?.let { Text(it, style = MaterialTheme.typography.labelLarge) }
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
                items(targets) { (index, label) ->
                    ArchiveCard(
                        onClick = { onSelect(index) },
                        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
                        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    ) { Text(label, Modifier.padding(12.dp), style = MaterialTheme.typography.bodyMedium) }
                }
                if (targets.isEmpty() && (tool==ReaderTool.Contents || query.isNotBlank())) item { Text(if (tool==ReaderTool.Find) "未找到匹配段落" else "正文没有章节标题", Modifier.padding(vertical=12.dp)) }
            }
        } }, confirmButton={ FilledTonalButton(onClick=onClose) { Text("关闭") } })
}
