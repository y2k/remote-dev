package io.y2k.remote_client.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    background = Color(0xFF14171C),
    onBackground = Color(0xFFE6EAF0),
    surface = Color(0xFF1D222A),
    surfaceContainer = Color(0xFF1D222A),
    onSurface = Color(0xFFE6EAF0),
    primary = Color(0xFF82AAFF),
    onPrimary = Color(0xFF14171C),
    primaryContainer = Color(0xFF1D222A),
    onPrimaryContainer = Color(0xFF82AAFF),
    outlineVariant = Color(0xFF343A43),
)
private val LightColorScheme = lightColorScheme()

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
