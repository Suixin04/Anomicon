package com.suixin.anomicon.designsystem

import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
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
    val context = LocalContext.current
    val palette = when {
        Build.VERSION.SDK_INT >= 31 && dark -> dynamicDarkColorScheme(context)
        Build.VERSION.SDK_INT >= 31 -> dynamicLightColorScheme(context)
        dark -> darkColorScheme(primary = Color(0xffa7c7ff), secondaryContainer = Color(0xff33455d))
        else -> lightColorScheme(primary = Color(0xff28598e), secondaryContainer = Color(0xffdce8f7), surface = Color(0xfff8f9fc))
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
    MaterialExpressiveTheme(colorScheme = palette, typography = typography,
        shapes = Shapes(medium = RoundedCornerShape(16.dp), large = RoundedCornerShape(24.dp)), content = content)
}

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
        overlay(material)
    }
}
