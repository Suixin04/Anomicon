@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)

package com.suixin.anomicon.designsystem

import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.animation.core.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

val LocalArchiveSecondary = staticCompositionLocalOf<(Boolean) -> Unit> { {} }
val LocalArchiveBottomInset = compositionLocalOf { 0.dp }

@Composable
fun ArchiveSecondaryPage(active: Boolean) {
    val report = LocalArchiveSecondary.current
    DisposableEffect(active, report) {
        if (active) report(true)
        onDispose { if (active) report(false) }
    }
}

@Composable
fun ArchiveCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = modifier, shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer), content = content)
}

@Composable
fun ArchiveAction(label: String, onClick: () -> Unit, content: @Composable () -> Unit) {
    FilledTonalIconButton(onClick = onClick, modifier = Modifier.semantics { contentDescription = label }, content = content)
}

@Composable
fun ArchiveSegments(labels: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
        labels.forEachIndexed { index, label ->
            SegmentedButton(selected = selected == index, onClick = { onSelect(index) },
                shape = SegmentedButtonDefaults.itemShape(index, labels.size), label = { Text(label) })
        }
    }
}

@Composable
fun ArchiveSwitch(checked: Boolean, onChange: (Boolean) -> Unit) {
    Switch(checked = checked, onCheckedChange = onChange)
}

@Composable
fun ArchiveLargePage(title: String, actions: @Composable RowScope.() -> Unit = {}, content: @Composable () -> Unit) {
    val behavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
    Column(Modifier.fillMaxSize().nestedScroll(behavior.nestedScrollConnection)) {
        LargeTopAppBar(title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            actions = actions, scrollBehavior = behavior, windowInsets = WindowInsets(0))
        Box(Modifier.fillMaxWidth().weight(1f)) { content() }
    }
}

@Composable
fun ArchiveDetailBar(title: String, onBack: () -> Unit, actions: @Composable RowScope.() -> Unit = {}) {
    TopAppBar(title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        navigationIcon = {
            IconButton(onClick = onBack) { Icon(painterResource(R.drawable.archive_arrow_back), contentDescription = "返回") }
        }, actions = actions, windowInsets = WindowInsets(0))
}

@Composable
fun ArchiveFloatingNav(modifier: Modifier = Modifier, visible: Boolean,
    content: @Composable () -> Unit, bar: @Composable () -> Unit) {
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    var hidden by remember(visible) { mutableStateOf(false) }
    val threshold = with(LocalDensity.current) { 20.dp.toPx() }
    val scrolling = remember(visible, threshold) {
        object : NestedScrollConnection {
            private var travel = 0f
            override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
                if (consumed.y * travel < 0f) travel = 0f
                travel += consumed.y
                if (kotlin.math.abs(travel) > threshold) { hidden = travel < 0; travel = 0f }
                return Offset.Zero
            }
        }
    }
    Box(modifier.fillMaxSize().nestedScroll(scrolling)) {
        Box(Modifier.fillMaxSize()) {
            CompositionLocalProvider(LocalArchiveBottomInset provides if (visible) 80.dp + bottom else 0.dp, content = content)
        }
        androidx.compose.animation.AnimatedVisibility(
            visible = visible && !hidden,
            modifier = Modifier.align(Alignment.BottomCenter),
            enter = androidx.compose.animation.slideInVertically { it } + androidx.compose.animation.fadeIn(),
            exit = androidx.compose.animation.slideOutVertically { it } + androidx.compose.animation.fadeOut()
        ) {
            HorizontalFloatingToolbar(
                expanded = true,
                modifier = Modifier.padding(start = 18.dp, end = 18.dp, bottom = bottom + 8.dp)
                    .widthIn(max = 420.dp),
                content = { bar() }
            )
        }
    }
}
