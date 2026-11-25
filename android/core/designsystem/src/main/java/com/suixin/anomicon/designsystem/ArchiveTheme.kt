package com.suixin.anomicon.designsystem

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object ArchiveSpacing {
    val group = 12.dp
    val page = 20.dp
    val section = 28.dp
}

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun ArchiveTheme(dark: Boolean, content: @Composable () -> Unit) {
    val palette = remember(dark) {
        val canvas = if (dark) Color(0xff0b0d11) else Color(0xfff2f4f7)
        val card = if (dark) Color(0xff13161c) else Color.White
        val inset = if (dark) Color(0xff1b1f27) else Color(0xfff6f8fb)
        val text = if (dark) Color(0xfff0f1f4) else Color(0xff111317)
        val muted = if (dark) Color(0xffb3b7bf) else Color(0xff575d67)
        val blue = if (dark) Color(0xff2f80ff) else Color(0xff0a59f7)
        val selected = if (dark) Color(0xff20385e) else Color(0xffe5eeff)
        (if (dark) darkColorScheme() else lightColorScheme()).copy(
            primary = blue, onPrimary = Color.White, primaryContainer = selected, onPrimaryContainer = text,
            secondary = blue, onSecondary = Color.White, secondaryContainer = selected, onSecondaryContainer = text,
            surface = canvas, background = canvas, onBackground = text, onSurface = text,
            surfaceVariant = inset, onSurfaceVariant = muted, surfaceTint = Color.Transparent,
            surfaceContainerLowest = card, surfaceContainerLow = inset, surfaceContainer = if (dark) Color(0xff232833) else Color(0xffeceff4),
            surfaceContainerHigh = if (dark) Color(0xff2c3240) else Color(0xffe3e7ef),
            surfaceContainerHighest = if (dark) Color(0xff333842) else Color(0xffdce0e8),
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
            labelSmall = base.labelSmall.copy(fontSize = 12.sp),
            labelLarge = base.labelLarge.copy(letterSpacing = 0.35.sp),
        )
    }
    CompositionLocalProvider(LocalArchiveDark provides dark) {
        MaterialExpressiveTheme(colorScheme = palette, typography = typography,
        shapes = Shapes(
            extraSmall = RoundedCornerShape(8.dp), small = RoundedCornerShape(8.dp),
            medium = RoundedCornerShape(14.dp), large = RoundedCornerShape(20.dp), extraLarge = RoundedCornerShape(20.dp)
        ), content = content)
    }
}

val LocalArchiveDark = staticCompositionLocalOf { false }

object ArchiveTypography {
    val metadata: TextStyle
        @Composable get() = MaterialTheme.typography.labelMedium.copy(fontFamily = FontFamily.Monospace)
}

object ArchiveClassification {
    val safe = Color(0xff16a34a)
    val euclid = Color(0xffea6c0a)
    val keter = Color(0xffdc2626)
}
