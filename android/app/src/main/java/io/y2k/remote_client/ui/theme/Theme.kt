package io.y2k.remote_client.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Material color tokens from the RemoteDev Stitch project (892911315436932478).
private val DarkColorScheme =
    darkColorScheme(
        primary = Color(0xFFB4C5FF),
        onPrimary = Color(0xFF002A77),
        primaryContainer = Color(0xFF275ACF),
        onPrimaryContainer = Color(0xFFD6DEFF),
        inversePrimary = Color(0xFF2156CB),
        secondary = Color(0xFFB0C6FF),
        onSecondary = Color(0xFF022D6F),
        secondaryContainer = Color(0xFF274689),
        onSecondaryContainer = Color(0xFF9BB7FF),
        tertiary = Color(0xFFFFB872),
        onTertiary = Color(0xFF4A2800),
        tertiaryContainer = Color(0xFF8C5515),
        onTertiaryContainer = Color(0xFFFFD7B4),
        background = Color(0xFF101418),
        onBackground = Color(0xFFE0E3E8),
        surface = Color(0xFF101418),
        onSurface = Color(0xFFE0E3E8),
        surfaceVariant = Color(0xFF31353A),
        onSurfaceVariant = Color(0xFFC3C6D6),
        surfaceTint = Color(0xFFB4C5FF),
        inverseSurface = Color(0xFFE0E3E8),
        inverseOnSurface = Color(0xFF2D3135),
        error = Color(0xFFFFB4AB),
        onError = Color(0xFF690005),
        errorContainer = Color(0xFF93000A),
        onErrorContainer = Color(0xFFFFDAD6),
        outline = Color(0xFF8D909F),
        outlineVariant = Color(0xFF434654),
        scrim = Color(0xFF000000),
        surfaceBright = Color(0xFF363A3E),
        surfaceDim = Color(0xFF101418),
        surfaceContainer = Color(0xFF1C2024),
        surfaceContainerHigh = Color(0xFF262A2F),
        surfaceContainerHighest = Color(0xFF31353A),
        surfaceContainerLow = Color(0xFF181C20),
        surfaceContainerLowest = Color(0xFF0B0F12),
    )

// Stitch's light paper, ink, muted, border and accent tokens; remaining roles matched to them.
private val LightColorScheme =
    lightColorScheme(
        primary = Color(0xFF275ACF),
        onPrimary = Color(0xFFFFFFFF),
        primaryContainer = Color(0xFFEAF0FF),
        onPrimaryContainer = Color(0xFF003EA7),
        inversePrimary = Color(0xFFB4C5FF),
        secondary = Color(0xFF244486),
        onSecondary = Color(0xFFFFFFFF),
        secondaryContainer = Color(0xFFD9E2FF),
        onSecondaryContainer = Color(0xFF001946),
        tertiary = Color(0xFF8C5515),
        onTertiary = Color(0xFFFFFFFF),
        tertiaryContainer = Color(0xFFFFDCBF),
        onTertiaryContainer = Color(0xFF2D1600),
        background = Color(0xFFF5F7FA),
        onBackground = Color(0xFF232A30),
        surface = Color(0xFFFFFFFF),
        onSurface = Color(0xFF232A30),
        surfaceVariant = Color(0xFFE7EBF0),
        onSurfaceVariant = Color(0xFF616C75),
        surfaceTint = Color(0xFF275ACF),
        inverseSurface = Color(0xFF2D3135),
        inverseOnSurface = Color(0xFFE0E3E8),
        error = Color(0xFFA93939),
        onError = Color(0xFFFFFFFF),
        errorContainer = Color(0xFFFFF0EE),
        onErrorContainer = Color(0xFFA93939),
        outline = Color(0xFF747F88),
        outlineVariant = Color(0xFFDDE2E7),
        scrim = Color(0xFF000000),
        surfaceBright = Color(0xFFFFFFFF),
        surfaceDim = Color(0xFFDDE2E7),
        surfaceContainer = Color(0xFFF0F3F6),
        surfaceContainerHigh = Color(0xFFE7EBF0),
        surfaceContainerHighest = Color(0xFFDDE2E7),
        surfaceContainerLow = Color(0xFFF5F7FA),
        surfaceContainerLowest = Color(0xFFFFFFFF),
    )

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme,
        typography = Typography,
        content = content,
    )
}
