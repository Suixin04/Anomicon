package com.suixin.anomicon.designsystem

import android.os.Build
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
import dev.chrisbanes.haze.*

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
    Surface(modifier = modifier, shape = RoundedCornerShape(24.dp), shadowElevation = 1.dp,
        border = if (LocalArchiveDark.current) BorderStroke(0.5.dp, Color.White.copy(alpha = .12f)) else null,
        color = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(content = content)
    }
}

@Composable
fun ArchiveAction(label: String, onClick: () -> Unit, content: @Composable () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val dark = LocalArchiveDark.current
    val face = if (dark) Modifier.background(colors.surfaceContainerLowest.copy(alpha = .85f), CircleShape)
        .border(.5.dp, Color.White.copy(alpha = .18f), CircleShape)
    else Modifier.shadow(1.dp, CircleShape).background(Color.White, CircleShape)
    Box(Modifier.size(48.dp).clickable(role = Role.Button, onClick = onClick)
        .semantics { contentDescription = label }.padding(4.dp).then(face),
        contentAlignment = Alignment.Center) { content() }
}

@Composable
fun ArchiveSegments(labels: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    val colors = MaterialTheme.colorScheme
    val width = 88.dp
    val x by animateDpAsState(width * selected, animationSpec = spring(stiffness = Spring.StiffnessMediumLow), label = "分段选择")
    Box(Modifier.clip(CircleShape).background(colors.surfaceContainerLow).padding(3.dp)) {
        Box(Modifier.offset(x = x).size(width, 40.dp).background(colors.primary, CircleShape))
        Row(Modifier.selectableGroup()) {
            labels.forEachIndexed { index, label ->
                val active = selected == index
                Box(Modifier.size(width, 40.dp).clip(CircleShape).selectable(active, role = Role.Tab) { onSelect(index) },
                    contentAlignment = Alignment.Center) {
                    Text(label, color = if (active) colors.onPrimary else colors.onSurface,
                        style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}

@Composable
fun ArchiveSwitch(checked: Boolean, onChange: (Boolean) -> Unit) {
    val colors = MaterialTheme.colorScheme
    val thumb by animateDpAsState(if (checked) 20.dp else 0.dp, spring(stiffness = Spring.StiffnessMedium), label = "开关")
    Box(Modifier.size(52.dp, 48.dp).toggleable(value = checked, role = Role.Switch, onValueChange = onChange),
        contentAlignment = Alignment.Center) {
        Box(Modifier.size(46.dp, 26.dp).background(if (checked) colors.primary else colors.outline, CircleShape)
            .padding(3.dp), contentAlignment = Alignment.CenterStart) {
            Box(Modifier.offset(x = thumb).size(20.dp).background(Color.White, CircleShape))
        }
    }
}

@Composable
fun ArchiveFloatingNav(modifier: Modifier = Modifier, visible: Boolean, material: Boolean = true,
    content: @Composable () -> Unit, bar: @Composable () -> Unit) {
    val blur = visible && material && Build.VERSION.SDK_INT >= 31
    val haze = rememberHazeState(blurEnabled = blur)
    val surface = MaterialTheme.colorScheme.surfaceContainerLowest
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
        Box(Modifier.fillMaxSize().then(if (blur) Modifier.hazeSource(haze) else Modifier)) {
            CompositionLocalProvider(LocalArchiveBottomInset provides if (visible) 80.dp + bottom else 0.dp, content = content)
        }
        androidx.compose.animation.AnimatedVisibility(
            visible = visible && !hidden,
            modifier = Modifier.align(Alignment.BottomCenter),
            enter = androidx.compose.animation.slideInVertically { it } + androidx.compose.animation.fadeIn(),
            exit = androidx.compose.animation.slideOutVertically { it } + androidx.compose.animation.fadeOut()
        ) {
            val glass = if (blur) Modifier.hazeEffect(haze) { backgroundColor = surface; blurRadius = 20.dp } else Modifier
            Box(Modifier.padding(start = 18.dp, end = 18.dp, bottom = bottom + 8.dp)
                .widthIn(max = 420.dp).fillMaxWidth().height(60.dp).shadow(6.dp, CircleShape).clip(CircleShape)
                .then(glass).background(surface.copy(alpha = if (blur) .77f else 1f))
                .archiveGlassEdge(blur, CircleShape), contentAlignment = Alignment.Center) { bar() }
        }
    }
}
