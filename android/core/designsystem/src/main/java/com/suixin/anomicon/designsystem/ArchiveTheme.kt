package com.suixin.anomicon.designsystem

import android.os.Build
import androidx.compose.foundation.border
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.unit.Dp
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource

object ArchiveSpacing {
    val group = 12.dp
    val page = 20.dp
    val section = 28.dp
}

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun ArchiveTheme(dark: Boolean, content: @Composable () -> Unit) {
    val palette = remember(dark) {
        val canvas = if (dark) Color(0xff090a0d) else Color(0xfff1f3f5)
        val card = if (dark) Color(0xff16181d) else Color.White
        val inset = if (dark) Color(0xff20232a) else Color(0xfff6f7f9)
        val text = if (dark) Color(0xfff0f1f4) else Color(0xff111317)
        val muted = if (dark) Color(0xffb3b7bf) else Color(0xff575d67)
        val blue = if (dark) Color(0xff2f80ff) else Color(0xff0a59f7)
        val selected = if (dark) Color(0xff20385e) else Color(0xffe5eeff)
        (if (dark) darkColorScheme() else lightColorScheme()).copy(
            primary = blue, onPrimary = Color.White, primaryContainer = selected, onPrimaryContainer = text,
            secondary = blue, onSecondary = Color.White, secondaryContainer = selected, onSecondaryContainer = text,
            surface = canvas, background = canvas, onBackground = text, onSurface = text,
            surfaceVariant = inset, onSurfaceVariant = muted, surfaceTint = Color.Transparent,
            surfaceContainerLowest = card, surfaceContainerLow = inset, surfaceContainer = inset,
            surfaceContainerHigh = inset, surfaceContainerHighest = inset,
            outline = if (dark) Color(0xff686d76) else Color(0xff9398a1),
            outlineVariant = if (dark) Color(0xff373b43) else Color(0xffd9dce1)
        )
    }
    val typography = remember {
        val base = Typography()
        Typography(
            headlineMedium = base.headlineMedium.copy(fontSize = 28.sp, lineHeight = 36.sp, fontWeight = FontWeight.Bold),
            titleLarge = base.titleLarge.copy(fontSize = 21.sp, lineHeight = 28.sp, fontWeight = FontWeight.SemiBold),
            bodyLarge = base.bodyLarge.copy(fontSize = 16.sp, lineHeight = 25.sp),
            labelLarge = base.labelLarge.copy(letterSpacing = 0.35.sp),
        )
    }
    CompositionLocalProvider(LocalArchiveDark provides dark) {
        MaterialExpressiveTheme(colorScheme = palette, typography = typography,
        shapes = Shapes(medium = RoundedCornerShape(16.dp), large = RoundedCornerShape(24.dp)), content = content)
    }
}

val LocalArchiveDark = staticCompositionLocalOf { false }

@Composable
fun Modifier.archiveGlassEdge(enabled: Boolean, shape: Shape = RectangleShape): Modifier =
    if (enabled && LocalArchiveDark.current) border(Dp.Hairline, Color.White.copy(alpha = 0.20f), shape) else this

@Composable
fun ArchiveOverlay(enabled: Boolean, modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit, overlay: @Composable BoxScope.(Modifier) -> Unit) {
    val state = remember { HazeState() }
    val surface = MaterialTheme.colorScheme.surface
    val blur = enabled && Build.VERSION.SDK_INT >= 31
    Box(modifier) {
        Box(if (blur) Modifier.matchParentSize().hazeSource(state) else Modifier.matchParentSize(), content = content)
        val material = if (blur) Modifier.hazeEffect(state) {
            backgroundColor = surface
            blurRadius = 20.dp
        }.background(surface.copy(alpha = .78f)) else Modifier.background(surface)
        overlay(material.archiveGlassEdge(blur))
    }
}

object ArchiveClassification {
    val safe = Color(0xff16a34a)
    val euclid = Color(0xffea6c0a)
    val keter = Color(0xffdc2626)
}
