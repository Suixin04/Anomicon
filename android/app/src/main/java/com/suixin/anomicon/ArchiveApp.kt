@file:OptIn(androidx.compose.animation.ExperimentalSharedTransitionApi::class, androidx.compose.material3.adaptive.ExperimentalMaterial3AdaptiveApi::class)

package com.suixin.anomicon

import androidx.activity.compose.BackHandler
import androidx.compose.animation.*
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.material3.adaptive.layout.*
import androidx.compose.material3.adaptive.navigation.rememberListDetailPaneScaffoldNavigator
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.*
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
internal fun ArchiveApp(model: ShellViewModel, applyBarStyle: (Boolean) -> Unit) {
    val bootstrap by model.bootstrap.collectAsStateWithLifecycle()
    val tab by model.tab.collectAsStateWithLifecycle()
    val detail by model.detail.collectAsStateWithLifecycle()
    val settings = (bootstrap as? Bootstrap.Ready)?.settings
    val dark = when (settings?.themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        else -> isSystemInDarkTheme()
    }
    LaunchedEffect(dark) { applyBarStyle(dark) }
    val tabState = rememberSaveableStateHolder()
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
                    var secondary by remember(tab) { mutableStateOf(false) }
                    val reportSecondary = remember(tab) { { active: Boolean -> secondary = active } }
                    Row(Modifier.fillMaxSize()) {
                        if (split && !fullStage) NavigationRail {
                            Tab.entries.forEach { item -> NavigationRailItem(
                                selected = item == tab, onClick = { model.select(item) },
                                icon = { TabIcon(item, item == tab) }, label = { Text(item.title) }) }
                        }
                        val showBar = !split && detail == null && !secondary
                        ArchiveFloatingNav(Modifier.fillMaxSize(), visible = showBar,
                            bar = { PhoneTabs(tab, model::select, settings.haptics) }, content = {
                            val insets = if (fullStage) Modifier else Modifier.windowInsetsPadding(
                                WindowInsets.safeDrawing.only(if (showBar) WindowInsetsSides.Top + WindowInsetsSides.Horizontal else WindowInsetsSides.Horizontal + WindowInsetsSides.Vertical))
                            CompositionLocalProvider(LocalArchiveSecondary provides reportSecondary) {
                                Box(Modifier.fillMaxSize().then(insets)) {
                                    if (split) {
                                        val navigator = rememberListDetailPaneScaffoldNavigator<Nothing>()
                                        ListDetailPaneScaffold(directive = navigator.scaffoldDirective.copy(maxHorizontalPartitions = 2),
                                            value = ThreePaneScaffoldValue(
                                                primary = PaneAdaptedValue.Expanded,
                                                secondary = if (fullStage) PaneAdaptedValue.Hidden else PaneAdaptedValue.Expanded,
                                                tertiary = PaneAdaptedValue.Hidden,
                                            ),
                                            listPane = { tabState.SaveableStateProvider(tab.name) { TabPage(tab, model) } },
                                            detailPane = {
                                                if (detail != null) DetailPage(detail!!, settings, model, onFullscreenChange = { fullStage = it })
                                                else Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("选择档案查看详情", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                                            },
                                        )
                                    } else {
                                        AnimatedContent(targetState = detail, label = "档案详情") { target ->
                                            if (target == null) {
                                                tabState.SaveableStateProvider(tab.name) { TabPage(tab, model) }
                                            } else {
                                                DetailPage(target, settings, model, Modifier, onFullscreenChange = { fullStage = it })
                                            }
                                        }
                                    }
                                }
                            }
                        })
                    }
                }
            }
        }
    }
}

@Composable
private fun TabPage(tab: Tab, model: ShellViewModel) {
    when (tab) {
        Tab.Explore -> com.suixin.anomicon.discovery.DiscoveryTab(model::openEntry)
        Tab.Catalog -> com.suixin.anomicon.discovery.CatalogTab(model::openEntry, onArchive = { model.open(Detail.Scene) })
        Tab.Foundation -> com.suixin.anomicon.foundation.FoundationTab(model::openEntry)
        Tab.Stories -> com.suixin.anomicon.stories.StoriesTab(model::openEntry)
        Tab.Terminal -> com.suixin.anomicon.terminal.TerminalTab(model::openEntry,
            onSettings = { model.open(Detail.Settings) }, onArchive = { model.open(Detail.Scene) })
    }
}

@Composable
private fun DetailPage(detail: Detail, settings: AppSettings, model: ShellViewModel, modifier: Modifier = Modifier, onFullscreenChange: (Boolean) -> Unit) {
    Box(modifier.fillMaxSize()) {
        when (detail) {
            Detail.Web -> WebReader(entry = model.entry.collectAsStateWithLifecycle().value, onBack = { model.open(null) })
            Detail.Scene -> StageProbe(onBack = { model.open(null) }, onFullscreenChange = onFullscreenChange)
            Detail.Settings -> Column(Modifier.fillMaxSize()) {
                ArchiveDetailBar("设置", { model.open(null) })
                Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(ArchiveSpacing.page), verticalArrangement = Arrangement.spacedBy(ArchiveSpacing.group)) {
                Text("外观", style = MaterialTheme.typography.titleLarge)
                ArchiveCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text("主题", style = MaterialTheme.typography.titleMedium)
                        ArchiveSegments(listOf("跟随系统", "浅色", "深色"), ThemeMode.entries.indexOf(settings.themeMode)) { model.theme(ThemeMode.entries[it]) }
                    }
                }
                Text("交互", style = MaterialTheme.typography.titleLarge)
                ArchiveCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(horizontal = 18.dp)) {
                        SettingSwitch("触感反馈", settings.haptics, model::haptics)
                    }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingSwitch(label: String, value: Boolean, change: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text(label)
        Box(Modifier.semantics { contentDescription = label }) { ArchiveSwitch(value, change) }
    }
}

@Composable
private fun PhoneTabs(current: Tab, select: (Tab) -> Unit, feedback: Boolean) {
    val haptic = LocalHapticFeedback.current
    Row(Modifier.fillMaxWidth().height(58.dp).selectableGroup(), verticalAlignment = Alignment.CenterVertically) {
        Tab.entries.forEach { tab ->
            val selected = current == tab
            val tint = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
            val scale by animateFloatAsState(if (selected) 1.10f else 1f, spring(dampingRatio = .64f), label = "页签选中")
            Column(Modifier.weight(1f).fillMaxHeight().selectable(selected, role = Role.Tab) {
                if (!selected && feedback) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                select(tab)
            }, verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                CompositionLocalProvider(LocalContentColor provides tint) {
                    Box(Modifier.graphicsLayer { scaleX = scale; scaleY = scale }) { TabIcon(tab, selected) }
                    Text(tab.title, color = tint, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@Composable
private fun TabIcon(tab: Tab, selected: Boolean) {
    val color = LocalContentColor.current
    Canvas(Modifier.size(24.dp)) {
        val stroke = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.7.dp.toPx())
        val unit = size.width / 24f
        fun point(x: Int, y: Int) = androidx.compose.ui.geometry.Offset(x * unit, y * unit)
        fun line(x: Int, y: Int, x2: Int, y2: Int) = drawLine(color, point(x,y), point(x2,y2), stroke.width)
        if (selected) {
            val contour = androidx.compose.ui.graphics.Path()
            val points = when (tab) {
                Tab.Foundation -> listOf(12 to 2, 21 to 6, 19 to 16, 12 to 22, 5 to 16, 3 to 6)
                Tab.Stories -> listOf(5 to 2, 15 to 2, 21 to 8, 21 to 22, 5 to 22)
                else -> emptyList()
            }
            points.forEachIndexed { i, (x,y) -> if(i==0) contour.moveTo(x*unit,y*unit) else contour.lineTo(x*unit,y*unit) }
            if(points.isNotEmpty()) { contour.close(); drawPath(contour,color) }
            val white = androidx.compose.ui.graphics.Color.White
            fun detail(x:Int,y:Int,xx:Int,yy:Int) = drawLine(white,point(x,y),point(xx,yy),1.4f*unit)
            when(tab) {
                Tab.Explore -> { drawCircle(color,10*unit); detail(7,16,16,7); detail(16,7,13,14) }
                Tab.Catalog -> { drawRoundRect(color,point(3,2),androidx.compose.ui.geometry.Size(18*unit,20*unit),androidx.compose.ui.geometry.CornerRadius(3*unit)); detail(8,5,8,19); detail(11,9,17,9) }
                Tab.Foundation -> { drawCircle(white,2.6f*unit,point(12,11)); detail(12,12,12,16) }
                Tab.Stories -> { detail(8,12,17,12); detail(8,16,17,16) }
                Tab.Terminal -> { drawRoundRect(color,point(2,3),androidx.compose.ui.geometry.Size(20*unit,15*unit),androidx.compose.ui.geometry.CornerRadius(3*unit)); line(12,18,12,21); line(7,21,17,21); detail(5,14,18,14) }
            }
        } else when (tab) {
            Tab.Explore -> { drawCircle(color, 9 * unit, style = stroke); line(8,16,11,10); line(11,10,16,8); line(16,8,13,14); line(13,14,8,16) }
            Tab.Catalog -> { drawRoundRect(color, point(4,3), androidx.compose.ui.geometry.Size(16*unit,18*unit), androidx.compose.ui.geometry.CornerRadius(2*unit), style=stroke); line(8,3,8,21); line(11,9,17,9); line(11,13,16,13) }
            Tab.Foundation -> { line(12,2,20,6); line(20,6,19,15); line(19,15,12,21); line(12,21,5,15); line(5,15,4,6); line(4,6,12,2) }
            Tab.Stories -> { line(5,3,15,3); line(15,3,20,8); line(20,8,20,21); line(20,21,5,21); line(5,21,5,3); line(8,12,17,12); line(8,16,15,16) }
            Tab.Terminal -> { drawRoundRect(color, point(2,4), androidx.compose.ui.geometry.Size(20*unit,14*unit), androidx.compose.ui.geometry.CornerRadius(2*unit), style=stroke); line(12,18,12,21); line(7,21,17,21) }
        }
    }
}
