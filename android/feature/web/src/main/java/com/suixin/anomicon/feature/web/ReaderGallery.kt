package com.suixin.anomicon.feature.web

import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import coil3.toBitmap
import com.suixin.anomicon.core.network.PreviewBlock
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException

@Composable
internal fun ReaderGallery(images: List<PreviewBlock.Image>, initial: PreviewBlock.Image, close: () -> Unit) {
    val pager = rememberPagerState(initialPage = images.indexOf(initial)) { images.size }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var zoomed by remember { mutableStateOf(false) }
    var displayed by remember(pager.currentPage) { mutableStateOf<coil3.Image?>(null) }
    var export by remember { mutableStateOf<coil3.Image?>(null) }
    var status by remember { mutableStateOf("") }
    val destination = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("image/png")) { uri ->
        val image = export
        if (uri != null && image != null) scope.launch {
            status = try {
                withContext(Dispatchers.IO) {
                    val output = context.contentResolver.openOutputStream(uri) ?: throw IOException("无法打开目标文件")
                    output.use { if (!image.toBitmap().compress(Bitmap.CompressFormat.PNG, 100, it)) throw IOException("图片无法编码") }
                }; "图片已保存"
            } catch (e: IOException) { "保存失败：${e.localizedMessage}" }
        }
        export = null
    }
    Dialog(onDismissRequest = close, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxSize().background(Color.Black).safeDrawingPadding()) {
            Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                FilledTonalButton(onClick = close) { Text("关闭") }
                Text("${pager.currentPage + 1} / ${images.size}", Modifier.weight(1f).padding(horizontal = 12.dp), color = Color.White)
                FilledTonalButton(enabled = displayed != null, onClick = { export = displayed; destination.launch("档案配图-${pager.currentPage+1}.png") }) { Text("保存图片") }
            }
            HorizontalPager(pager, Modifier.weight(1f), userScrollEnabled = !zoomed) { page ->
                var scale by remember { mutableFloatStateOf(1f) }
                var pan by remember { mutableStateOf(Offset.Zero) }
                var loaded by remember { mutableStateOf<coil3.Image?>(null) }
                LaunchedEffect(pager.currentPage, page, scale, loaded) {
                    if (pager.currentPage == page) { zoomed = scale > 1f; displayed = loaded }
                    else { scale = 1f; pan = Offset.Zero }
                }
                BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    val width = constraints.maxWidth; val height = constraints.maxHeight
                    val transform = rememberTransformableState { zoom, movement, _ ->
                        scale = (scale * zoom).coerceIn(1f, 5f)
                        val x = width * (scale-1)/2; val y = height * (scale-1)/2
                        pan = Offset((pan.x + movement.x).coerceIn(-x, x), (pan.y + movement.y).coerceIn(-y, y))
                    }
                    AsyncImage(images[page].url, images[page].description,
                        Modifier.fillMaxSize().pointerInput(Unit) { detectTapGestures(onDoubleTap = { scale = if (scale > 1f) 1f else 2.5f; pan = Offset.Zero }) }
                            .transformable(transform, canPan = { scale > 1f }).graphicsLayer { scaleX = scale; scaleY = scale; translationX = pan.x; translationY = pan.y },
                        onSuccess = { loaded = it.result.image }, onError = { status = "无法加载这张配图" })
                }
            }
            Text(images[pager.currentPage].caption.ifBlank { images[pager.currentPage].description }, Modifier.padding(16.dp), color = Color.White)
            if (status.isNotBlank()) Text(status, Modifier.padding(12.dp), color = Color.White)
        }
    }
}
