package com.suixin.anomicon.archive3d

import com.suixin.anomicon.designsystem.ArchiveDetailBar
import androidx.compose.ui.text.font.FontFamily
import com.suixin.anomicon.designsystem.ArchiveGlyph
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import io.github.sceneview.*
import io.github.sceneview.math.Position
import io.github.sceneview.node.ModelNode
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import kotlin.math.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal fun verifiedModel(bytes: ByteArray): ByteBuffer {
    require(bytes.size == 3969944) { "模型长度不匹配" }
    val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
    require(buffer.getInt(0) == 0x46546c67 && buffer.getInt(4) == 2 && buffer.getInt(8) == bytes.size) { "GLB 头无效" }
    val digest = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    require(digest == "f89aefe1f7cf116dc8c12e9c5d554278217afe4744e49e14ab52840ca91f256d") { "模型校验失败" }
    return ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder()).apply { put(bytes); rewind() }
}

@Composable
fun StageProbe(
    onBack: () -> Unit,
    onFullscreenChange: (Boolean) -> Unit = {},
) {
    val assets = LocalContext.current.assets
    var model by remember { mutableStateOf<ByteBuffer?>(null) }
    var failure by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(assets) {
        try {
            model = withContext(Dispatchers.IO) { assets.open("models/scp-173.glb").use { verifiedModel(it.readBytes()) } }
        } catch (e: java.io.IOException) { failure = e.localizedMessage }
        catch (e: IllegalArgumentException) { failure = e.localizedMessage }
    }
    var fullscreen by rememberSaveable { mutableStateOf(false) }
    val notifyFullscreen by rememberUpdatedState(onFullscreenChange)
    LaunchedEffect(fullscreen) { notifyFullscreen(fullscreen) }
    DisposableEffect(Unit) { onDispose { notifyFullscreen(false) } }
    var spinning by rememberSaveable { mutableStateOf(false) }
    var yaw by rememberSaveable { mutableFloatStateOf(0f) }
    var pitch by rememberSaveable { mutableFloatStateOf(0f) }
    var distance by rememberSaveable { mutableFloatStateOf(3.2f) }
    val window = LocalActivity.current?.window
    val view = LocalView.current
    DisposableEffect(window, view, fullscreen) {
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val status = WindowInsetsCompat.Type.statusBars()
        val nav = WindowInsetsCompat.Type.navigationBars()
        if (fullscreen) controller?.hide(status or nav) else controller?.show(status or nav)
        onDispose { if (fullscreen) controller?.show(status or nav) }
    }
    val back = { if (fullscreen) fullscreen = false else onBack() }
    BackHandler(onBack = back)
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surface)) {
        if (!fullscreen) ArchiveDetailBar("三维档案", onBack) {
            Text("SCP-173", Modifier.padding(end = 16.dp), fontFamily = FontFamily.Monospace)
        }
        Box(Modifier.fillMaxWidth().weight(1f)) {
            model?.let { buffer ->
                val engine = rememberEngine()
                val loader = rememberModelLoader(engine)
                val camera = rememberCameraNode(engine)
                val nodes = rememberNodes { add(ModelNode(loader.createModelInstance(buffer), autoAnimate = false, scaleToUnits = 1.8f, centerOrigin = Position())) }
                val lastFrame = remember { longArrayOf(0L) }
                Scene(modifier = Modifier.fillMaxSize(), engine = engine, modelLoader = loader,
                    childNodes = nodes, cameraNode = camera, cameraManipulator = null,
                    onFrame = { now ->
                        if (spinning && lastFrame[0] != 0L) yaw = (yaw + ((now - lastFrame[0]) * 1e-9f).coerceAtMost(0.1f) * 0.42f) % (2f * PI.toFloat())
                        lastFrame[0] = now
                        camera.position = Position(distance * cos(pitch) * sin(yaw), distance * sin(pitch), distance * cos(pitch) * cos(yaw))
                        camera.lookAt(Position())
                    })
                Box(Modifier.fillMaxSize().pointerInput(Unit) {
                    detectTransformGestures { _, pan, zoom, _ ->
                        yaw -= pan.x / size.width.coerceAtLeast(1) * 3.8f
                        pitch = (pitch + pan.y / size.height.coerceAtLeast(1) * 3.8f).coerceIn(-1.42f, 1.42f)
                        distance = (distance / zoom).coerceIn(1.35f, 7.5f)
                    }
                })
            } ?: Text(failure ?: "正在校验模型…", Modifier.align(Alignment.Center))
            StageControls(Modifier.align(Alignment.BottomCenter).padding(16.dp), spinning, fullscreen,
                { spinning = !spinning }, { spinning = false; yaw = 0f; pitch = 0f; distance = 3.2f }, { fullscreen = !fullscreen })
        }
        if (!fullscreen) Text("单指旋转 · 双指缩放", Modifier.padding(20.dp), style = MaterialTheme.typography.bodyMedium)
    }
}

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
private fun StageControls(modifier: Modifier, spinning: Boolean, fullscreen: Boolean,
                          spin: () -> Unit, reset: () -> Unit, expand: () -> Unit) {
    HorizontalFloatingToolbar(
        expanded = true,
        modifier = modifier,
        colors = FloatingToolbarDefaults.standardFloatingToolbarColors( toolbarContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh)
    ) {
        StageAction(if (spinning) "暂停" else "360°", if (spinning) "pause" else "play_arrow", spin)
        StageAction("复位", "restart_alt", reset)
        StageAction(if (fullscreen) "退出全屏" else "全屏", if (fullscreen) "fullscreen_exit" else "fullscreen", expand)
    }
}

@Composable
private fun StageAction(label: String, glyph: String, action: () -> Unit) {
    IconButton(onClick = action, modifier = Modifier.semantics { contentDescription = label }) { ArchiveGlyph(glyph) }
}
