@file:OptIn(androidx.compose.animation.ExperimentalSharedTransitionApi::class, androidx.compose.material3.adaptive.ExperimentalMaterial3AdaptiveApi::class)

package com.suixin.anomicon

import androidx.activity.compose.BackHandler
import androidx.compose.animation.*
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.material3.adaptive.layout.*
import androidx.compose.material3.adaptive.navigation.rememberListDetailPaneScaffoldNavigator
import androidx.compose.material3.adaptive.navigationsuite.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.suixin.anomicon.archive3d.StageProbe
import com.suixin.anomicon.core.data.*
import com.suixin.anomicon.designsystem.*
import com.suixin.anomicon.feature.web.WebReader

@Composable
internal fun ArchiveApp(model: ShellViewModel) {
    val bootstrap by model.bootstrap.collectAsStateWithLifecycle()
    val tab by model.tab.collectAsStateWithLifecycle()
    val detail by model.detail.collectAsStateWithLifecycle()
    val settings = (bootstrap as? Bootstrap.Ready)?.settings
    val dark = when (settings?.themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        else -> isSystemInDarkTheme()
    }
    ArchiveTheme(dark) {
        Surface(Modifier.fillMaxSize()) {
            if (settings == null) {
                Column(Modifier.fillMaxSize().safeDrawingPadding(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                    when (val phase = bootstrap) {
                        is Bootstrap.Error -> {
                            Text("无法打开本地资料库")
                            Text(phase.message, style = MaterialTheme.typography.bodySmall)
                            Button(onClick = model::migrate) { Text("重试") }
                        }
                        else -> CircularProgressIndicator()
                    }
                }
            } else {
                var fullStage by remember(detail) { mutableStateOf(false) }
                BackHandler(enabled = detail != null && !fullStage) { model.open(null) }
                BoxWithConstraints(Modifier.fillMaxSize()) {
                    val split = maxWidth >= 840.dp
                    NavigationSuiteScaffold(
                        layoutType = when {
                            fullStage -> NavigationSuiteType.None
                            split -> NavigationSuiteType.NavigationRail
                            else -> NavigationSuiteType.NavigationBar
                        },
                        navigationSuiteItems = {
                            Tab.entries.forEach { destination -> item(
                                selected = tab == destination,
                                onClick = { model.select(destination) },
                                icon = { TabIcon(destination) }, label = { Text(destination.title) },
                            ) }
                        },
                    ) {
                        SharedTransitionLayout(Modifier.fillMaxSize().then(if (fullStage) Modifier else Modifier.safeDrawingPadding())) {
                            if (split) {
                                val navigator = rememberListDetailPaneScaffoldNavigator<Nothing>()
                                ListDetailPaneScaffold(directive = navigator.scaffoldDirective.copy(maxHorizontalPartitions = 2),
                                    value = ThreePaneScaffoldValue(
                                        primary = PaneAdaptedValue.Expanded,
                                        secondary = if (fullStage) PaneAdaptedValue.Hidden else PaneAdaptedValue.Expanded,
                                        tertiary = PaneAdaptedValue.Hidden,
                                    ),
                                    listPane = { TabPage(tab, settings, model::open) },
                                    detailPane = {
                                        if (detail != null) DetailPage(detail!!, settings, model, onFullscreenChange = { fullStage = it })
                                        else Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("选择档案查看详情", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                                    },
                                )
                            } else {
                                AnimatedContent(targetState = detail, label = "档案详情") { target ->
                                    if (target == null) {
                                        TabPage(tab, settings, model::open) { key -> Modifier.sharedElement(rememberSharedContentState(key), this@AnimatedContent) }
                                    } else {
                                        DetailPage(target, settings, model, Modifier.sharedElement(rememberSharedContentState(target), this@AnimatedContent), onFullscreenChange = { fullStage = it })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TabPage(tab: Tab, settings: AppSettings, open: (Detail) -> Unit, shared: @Composable (Detail) -> Modifier = { Modifier }) {
    val destinations = when (tab) {
        Tab.Explore -> listOf(Detail.Web)
        Tab.Catalog -> listOf(Detail.Web, Detail.Scene)
        Tab.Foundation, Tab.Stories -> emptyList()
        Tab.Terminal -> listOf(Detail.Scene, Detail.Settings)
    }
    val intro = when (tab) {
        Tab.Explore -> "今日推荐"
        Tab.Catalog -> "主站译文 · Series I"
        Tab.Foundation -> "基金会设定手册与 RAISA 资质考核"
        Tab.Stories -> "故事索引与系列跟读"
        Tab.Terminal -> "研究员资料库"
    }
    ArchiveOverlay(settings.immersiveMaterial, Modifier.fillMaxSize(), content = {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = ArchiveSpacing.page), verticalArrangement = Arrangement.spacedBy(ArchiveSpacing.group)) {
            Spacer(Modifier.height(76.dp))
            Text(intro, style = MaterialTheme.typography.titleLarge)
            destinations.forEach { dest ->
                val feedback = LocalHapticFeedback.current
                val interaction = remember { MutableInteractionSource() }
                val pressed by interaction.collectIsPressedAsState()
                val scale by animateFloatAsState(if (pressed) .975f else 1f, spring(), label = "按压反馈")
                Surface(modifier = shared(dest).fillMaxWidth().graphicsLayer { scaleX = scale; scaleY = scale },
                    shape = MaterialTheme.shapes.large, color = MaterialTheme.colorScheme.surfaceContainerLow) {
                    Column(Modifier.clickable(interactionSource = interaction, indication = LocalIndication.current) {
                        if (settings.haptics) feedback.performHapticFeedback(HapticFeedbackType.LongPress)
                        open(dest)
                    }.padding(ArchiveSpacing.page)) {
                        Text(if (dest == Detail.Web) "SCP-002" else dest.title, style = MaterialTheme.typography.titleMedium)
                        if (dest == Detail.Web) Text("“生活”室 · 原版网页", style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
            Spacer(Modifier.height(ArchiveSpacing.page))
        }
    }, overlay = { material ->
        Text(tab.title, material.fillMaxWidth().padding(horizontal = ArchiveSpacing.page, vertical = 14.dp), style = MaterialTheme.typography.headlineMedium)
    })
}

@Composable
private fun DetailPage(detail: Detail, settings: AppSettings, model: ShellViewModel, modifier: Modifier = Modifier, onFullscreenChange: (Boolean) -> Unit) {
    Box(modifier.fillMaxSize()) {
        when (detail) {
            Detail.Web -> WebReader(entry = "scp-002", onBack = { model.open(null) })
            Detail.Scene -> StageProbe(onBack = { model.open(null) }, immersiveMaterial = settings.immersiveMaterial, onFullscreenChange = onFullscreenChange)
            Detail.Settings -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(ArchiveSpacing.page), verticalArrangement = Arrangement.spacedBy(ArchiveSpacing.group)) {
                TextButton(onClick = { model.open(null) }) { Text("返回") }
                Text("设置", style = MaterialTheme.typography.headlineMedium)
                Text("外观", style = MaterialTheme.typography.titleLarge)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    ThemeMode.entries.forEach { mode -> FilterChip(selected = settings.themeMode == mode, onClick = { model.theme(mode) }, label = { Text(when (mode) { ThemeMode.SYSTEM -> "跟随系统"; ThemeMode.LIGHT -> "浅色"; ThemeMode.DARK -> "深色" }) }) }
                }
                SettingSwitch("沉浸材质", settings.immersiveMaterial, model::material)
                SettingSwitch("触感反馈", settings.haptics, model::haptics)
            }
        }
    }
}

@Composable
private fun SettingSwitch(label: String, value: Boolean, change: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text(label)
        Switch(checked = value, onCheckedChange = change, modifier = Modifier.semantics { contentDescription = label })
    }
}

@Composable
private fun TabIcon(tab: Tab) {
    val color = LocalContentColor.current
    Canvas(Modifier.size(24.dp)) {
        val stroke = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.7.dp.toPx())
        val unit = size.width / 24f
        fun point(x: Int, y: Int) = androidx.compose.ui.geometry.Offset(x * unit, y * unit)
        fun line(x: Int, y: Int, x2: Int, y2: Int) = drawLine(color, point(x,y), point(x2,y2), stroke.width)
        when (tab) {
            Tab.Explore -> { drawCircle(color, 9 * unit, style = stroke); line(8,16,11,10); line(11,10,16,8); line(16,8,13,14); line(13,14,8,16) }
            Tab.Catalog -> { drawRoundRect(color, point(4,3), androidx.compose.ui.geometry.Size(16*unit,18*unit), androidx.compose.ui.geometry.CornerRadius(2*unit), style=stroke); line(8,3,8,21); line(11,9,17,9); line(11,13,16,13) }
            Tab.Foundation -> { line(12,2,20,6); line(20,6,19,15); line(19,15,12,21); line(12,21,5,15); line(5,15,4,6); line(4,6,12,2) }
            Tab.Stories -> { line(5,3,15,3); line(15,3,20,8); line(20,8,20,21); line(20,21,5,21); line(5,21,5,3); line(8,12,17,12); line(8,16,15,16) }
            Tab.Terminal -> { drawRoundRect(color, point(2,4), androidx.compose.ui.geometry.Size(20*unit,14*unit), androidx.compose.ui.geometry.CornerRadius(2*unit), style=stroke); line(12,18,12,21); line(7,21,17,21) }
        }
    }
}
