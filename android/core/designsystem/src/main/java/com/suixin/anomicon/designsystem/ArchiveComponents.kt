@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)

package com.suixin.anomicon.designsystem

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
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
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLowest), content = content)
}

@Composable
fun ArchiveCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    containerColor: Color = MaterialTheme.colorScheme.surfaceContainerLowest,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        onClick = onClick,
        modifier = modifier,
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = containerColor),
        content = content
    )
}

@Composable
fun ArchiveAction(label: String, onClick: () -> Unit, content: @Composable () -> Unit) {
    FilledTonalIconButton(
        onClick = onClick,
        modifier = Modifier.semantics { contentDescription = label },
        colors = IconButtonDefaults.filledTonalIconButtonColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        content = content
    )
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
    ArchiveDetailBar(title, onBack, subtitle = null, actions = actions)
}

private val scpNumber = Regex("SCP-(?:[A-Z]+-)?[0-9]+(?:-[A-Z0-9]+)*", RegexOption.IGNORE_CASE)

@Composable
fun ArchiveDetailBar(title: String, onBack: () -> Unit, subtitle: String?, actions: @Composable RowScope.() -> Unit = {}) {
    val styledTitle = remember(title) {
        buildAnnotatedString {
            append(title)
            for (number in scpNumber.findAll(title)) {
                addStyle(SpanStyle(fontFamily = FontFamily.Monospace), number.range.first, number.range.last + 1)
            }
        }
    }
    TopAppBar(
        title = {
            Column {
                Text(styledTitle, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (!subtitle.isNullOrEmpty()) {
                    Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        },
        navigationIcon = {
            IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) {
                ArchiveGlyph("arrow_back")
            }
        },
        actions = actions,
        windowInsets = WindowInsets(0)
    )
}
