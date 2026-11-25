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
                        Column(Modifier.fillMaxSize()) {
                            val insets = if (fullStage) Modifier else Modifier.windowInsetsPadding(
                                WindowInsets.safeDrawing.only(if (showBar) WindowInsetsSides.Top + WindowInsetsSides.Horizontal else WindowInsetsSides.Horizontal + WindowInsetsSides.Vertical))
                            CompositionLocalProvider(LocalArchiveSecondary provides reportSecondary) {
                                Box(Modifier.fillMaxWidth().weight(1f).then(insets)) {
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
                            if (showBar) PhoneTabs(tab, model::select, settings.haptics)
                        }
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
    NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainer, tonalElevation = 0.dp) {
        Tab.entries.forEach { tab ->
            val selected = current == tab
            NavigationBarItem(
                selected = selected,
                onClick = {
                    if (!selected && feedback) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    select(tab)
                },
                icon = { TabIcon(tab, selected) },
                label = { Text(tab.title, style = MaterialTheme.typography.labelMedium) },
                colors = NavigationBarItemDefaults.colors(indicatorColor = MaterialTheme.colorScheme.primaryContainer)
            )
        }
    }
}

@Composable
private fun TabIcon(tab: Tab, selected: Boolean) {
    val icon = when (tab) {
        Tab.Explore -> "explore"
        Tab.Catalog -> "collections_bookmark"
        Tab.Foundation -> "shield"
        Tab.Stories -> "auto_stories"
        Tab.Terminal -> "account_box"
    }
    ArchiveGlyph(if (selected) "${icon}_filled" else icon)
}
