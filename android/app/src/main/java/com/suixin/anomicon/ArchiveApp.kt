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
import com.suixin.anomicon.archive3d.hasArchiveModel
import com.suixin.anomicon.archive3d.StageProbe
import com.suixin.anomicon.core.data.*
import com.suixin.anomicon.designsystem.*
import com.suixin.anomicon.feature.web.WebReader

@Composable
internal fun ArchiveApp(model: ShellViewModel, applyBarStyle: (Boolean) -> Unit) {
    val bootstrap by model.bootstrap.collectAsStateWithLifecycle()
    val tab by model.tab.collectAsStateWithLifecycle()
    val routes by model.routes.collectAsStateWithLifecycle()
    val detail = routes.lastOrNull()
    val detailState = rememberSaveableStateHolder()
    var previousKeys by remember { mutableStateOf(emptySet<String>()) }
    LaunchedEffect(routes) {
        val active = routes.map { it.key }.toSet()
        (previousKeys - active).forEach(detailState::removeState)
        previousKeys = active
    }
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
                BackHandler(enabled = detail != null && !fullStage) { model.back() }
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
                                                if (detail != null) detailState.SaveableStateProvider(detail.key) { DetailPage(detail, settings, model, onFullscreenChange = { fullStage = it }) }
                                                else Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("选择档案查看详情", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                                            },
                                        )
                                    } else {
                                        AnimatedContent(targetState = detail, label = "档案详情") { target ->
                                            if (target == null) {
                                                tabState.SaveableStateProvider(tab.name) { TabPage(tab, model) }
                                            } else {
                                                detailState.SaveableStateProvider(target.key) { DetailPage(target, settings, model, onFullscreenChange = { fullStage = it }) }
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
        Tab.Foundation -> com.suixin.anomicon.foundation.FoundationTab(model::openEntry, onWorkOrder = { model.push(DetailRoute(Detail.Feedback, source = "foundation")) })
        Tab.Stories -> com.suixin.anomicon.stories.StoriesTab(model::openEntry)
        Tab.Terminal -> com.suixin.anomicon.terminal.TerminalTab(model::openEntry,
            onSettings = { model.open(Detail.Settings) }, onArchive = { model.open(Detail.Scene) })
    }
}

@Composable
private fun DetailPage(route: DetailRoute, settings: AppSettings, model: ShellViewModel, onFullscreenChange: (Boolean) -> Unit) {
    when (route.page) {
        Detail.Web -> WebReader(entry = route.item, onBack = model::back,
            onOpenArchive = { model.push(DetailRoute(Detail.Scene, item = it)) },
            hasArchiveModel = ::hasArchiveModel,
            onFeedback = { id, title, url, mode, revealed ->
                model.push(DetailRoute(Detail.Feedback, id, "article", title, url, mode, revealed))
            })
        Detail.Scene -> StageProbe(onBack = model::back, onFullscreenChange = onFullscreenChange,
            initialItemId = route.item.ifBlank { null }, onOpenArticle = model::openEntry)
        Detail.Feedback -> com.suixin.anomicon.terminal.RaisaPage(model::back, route.source, route.item,
            route.title, route.url, route.renderMode, route.revealed)
        Detail.Settings -> SettingsScreen(settings, model)
        Detail.About, Detail.License -> ProductInfoScreen(route.page, model::back)
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
