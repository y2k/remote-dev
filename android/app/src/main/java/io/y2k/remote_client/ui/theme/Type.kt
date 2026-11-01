package io.y2k.remote_client.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val defaults = Typography()

val ProjectTitle = defaults.titleMedium.copy(
    fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.sp,
)
val SessionTitle = ProjectTitle.copy(fontWeight = FontWeight.SemiBold)
val CardMeta = defaults.bodySmall.copy(
    fontSize = 12.sp, lineHeight = 18.sp, fontWeight = FontWeight.Normal, letterSpacing = 0.sp,
)

// Stitch sizes and weights with Material's system font, including paths/code.
val Typography = defaults.copy(
    headlineLarge = defaults.headlineLarge.copy(
        fontWeight = FontWeight.SemiBold,
        fontSize = 24.sp, lineHeight = 30.sp, letterSpacing = (-0.6).sp,
    ),
    bodyLarge = defaults.bodyLarge.copy(
        fontSize = 16.sp, lineHeight = 24.sp, letterSpacing = 0.sp,
    ),
    bodyMedium = defaults.bodyMedium.copy(
        fontSize = 14.sp, lineHeight = 21.sp, letterSpacing = 0.sp,
    ),
    bodySmall = defaults.bodySmall.copy(
        fontSize = 12.sp, lineHeight = 18.sp, letterSpacing = 0.sp,
    ),
    labelLarge = defaults.labelLarge.copy(
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp, lineHeight = 21.sp, letterSpacing = 0.sp,
    ),
)
