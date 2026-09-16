package io.y2k.remote_client

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import io.y2k.remote_client.ui.theme.MyApplicationTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.click
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.ByteArrayOutputStream
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalTestApi::class)
class BackendUiParserTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun parsesContainerDecorationStrictly() {
        for (type in listOf("row", "column")) {
            fun parse(fields: String) = parseUiNode("""{"@type":"$type","children":[]$fields}""")
            fun expected(border: UiBorder? = null, radius: Int = 0): UiNode =
                if (type == "row") UiNode.Row(emptyList(), border = border, cornerRadius = radius)
                else UiNode.Column(emptyList(), border = border, cornerRadius = radius)
            fun reject(fields: String) = assertTrue("Accepted $type $fields",
                runCatching { parse(fields) }.exceptionOrNull() is IllegalArgumentException)
            assertEquals(expected(), parse(""))
            for (size in listOf(0, 12, Int.MAX_VALUE)) {
                assertEquals(expected(radius = size), parse(",\"cornerRadius\":$size"))
                for (role in ThemeColor.entries) {
                    val field = """, "border":{"width":$size,"color":"${role.wireName}"}"""
                    assertEquals(expected(UiBorder(size, role)), parse(field))
                    assertEquals(expected(UiBorder(size, role), size), parse("$field,\"cornerRadius\":$size"))
                }
            }
            for (bad in listOf("null", "true", "[]", "1", "\"12\"", "{}", "{\"width\":1}", "{\"color\":\"primary\"}"))
                reject(",\"border\":$bad")
            for (bad in listOf("-1", "1.5", "1.0", "2147483648", "1e100", "\"1\"", "true", "null", "[]", "{}")) {
                reject(",\"cornerRadius\":$bad")
                reject(""", "border":{"width":$bad,"color":"primary"}""")
            }
            for (bad in listOf("null", "true", "1", "[]", "{}", "\"Primary\"", "\"unknown\"", "\"#FF8800\""))
                for (width in listOf(0, 2)) reject(""", "border":{"width":$width,"color":$bad}""")
        }
    }

    @Test
    fun containerBorderAndRadiusPainting() {
        var horizontal by mutableStateOf(false)
        var dark by mutableStateOf(false)
        var radius by mutableStateOf(0)
        var width by mutableStateOf<Int?>(null)
        var filled by mutableStateOf(false)
        var density = 1f
        var stroke = 0
        var surface = 0
        composeRule.setContent {
            density = LocalDensity.current.density
            MyApplicationTheme(darkTheme = dark) {
                stroke = MaterialTheme.colorScheme.outlineVariant.toArgb()
                surface = MaterialTheme.colorScheme.surface.toArgb()
                Box(Modifier.width(80.dp).height(40.dp).background(Color.Magenta).testTag("decoration")) {
                    val children = if (filled) listOf(UiNode.Column(emptyList(), weights = emptyList(), stretch = true,
                        background = ThemeColor.Surface)) else emptyList()
                    val border = width?.let { UiBorder(it, ThemeColor.OutlineVariant) }
                    val node = if (horizontal) UiNode.Row(children, weights = if (filled) listOf(1f) else emptyList(),
                        background = if (filled) null else ThemeColor.Surface, border = border, cornerRadius = radius)
                    else UiNode.Column(children, weights = if (filled) listOf(1f) else emptyList(), stretch = true,
                        background = if (filled) null else ThemeColor.Surface, border = border, cornerRadius = radius)
                    UiNodeContent(node, {}, { _, _ -> }, false, modifier = Modifier.fillMaxSize())
                }
            }
        }
        for (row in listOf(false, true)) for (isDark in listOf(false, true)) {
            for (r in listOf(0, 12, 100)) for (w in listOf(null, 0, 4)) for (child in listOf(false, true)) {
                composeRule.runOnIdle { horizontal = row; dark = isDark; radius = r; width = w; filled = child }
                val image = composeRule.onNodeWithTag("decoration").captureToImage().asAndroidBitmap()
                fun pixel(x: Float, y: Float) = image.getPixel((x * density).toInt(), (y * density).toInt())
                assertEquals(80 * density, image.width.toFloat(), 1f)
                assertEquals(40 * density, image.height.toFloat(), 1f)
                assertEquals(surface, pixel(40f, 20f))
                for ((x, y) in listOf(40f to 1f, 40f to 38f, 1f to 20f, 78f to 20f))
                    assertEquals("edge row=$row radius=$r width=$w child=$child", if (w == 4) stroke else surface, pixel(x, y))
                assertEquals("corner row=$row radius=$r width=$w child=$child",
                    if (r > 0) Color.Magenta.toArgb() else if (w == 4) stroke else surface, pixel(1f, 1f))
                if (r == 100) {
                    assertEquals(Color.Magenta.toArgb(), pixel(3f, 3f))
                    assertEquals(surface, pixel(10f, 20f))
                }
            }
        }
    }

    @Test
    fun parsesContainerBackgroundStrictly() {
        for (type in listOf("row", "column")) {
            for (role in listOf(null) + ThemeColor.entries) {
                val json = JSONObject("""{"@type":"$type","children":[]}""")
                role?.let { json.put("background", it.wireName) }
                val expected = if (type == "row") UiNode.Row(emptyList(), background = role)
                    else UiNode.Column(emptyList(), background = role)
                assertEquals(expected, parseUiNode(json.toString()))
            }
            for (value in listOf("\"unknown\"", "\"Surface\"", "\"#1D222A\"", "1", "true", "null", "[]", "{}")) {
                assertTrue("Accepted $type background $value", runCatching {
                    parseUiNode("""{"@type":"$type","children":[],"background":$value}""")
                }.exceptionOrNull() is IllegalArgumentException)
            }
        }
    }

    @Test
    fun parsesContainerSpacingStrictly() {
        for (type in listOf("row", "column")) {
            fun parse(fields: String): UiNode = parseUiNode("""{"@type":"$type","children":[]$fields}""")
            fun expected(p: UiPadding = UiPadding(), g: UiGap = UiGap()): UiNode =
                if (type == "row") UiNode.Row(emptyList(), padding = p, gap = g)
                else UiNode.Column(emptyList(), padding = p, gap = g)
            fun reject(fields: String) {
                assertTrue("Accepted $type $fields", runCatching { parse(fields) }.exceptionOrNull() is IllegalArgumentException)
            }
            assertEquals(expected(), parse(""))
            for (size in listOf(0, 12, Int.MAX_VALUE)) {
                for (role in listOf(null) + ThemeColor.entries) {
                    val color = role?.let { ",\"color\":\"${it.wireName}\"" }.orEmpty()
                    assertEquals(expected(UiPadding(16, 8, 4, size), UiGap(size, role)),
                        parse(""", "padding":{"start":16,"top":8,"end":4,"bottom":$size},"gap":{"size":$size$color}"""))
                }
            }
            for (bad in listOf("null", "true", "[]", "1", "\"12\"")) {
                reject(",\"padding\":$bad")
                reject(",\"gap\":$bad")
            }
            val sides = listOf("start", "top", "end", "bottom")
            for (side in sides) {
                val missing = sides.filter { it != side }.joinToString(",") { "\"$it\":0" }
                reject(",\"padding\":{$missing}")
                for (bad in listOf("-1", "1.5", "1.0", "2147483648", "1e100", "\"1\"", "true", "null", "[]", "{}")) {
                    val values = sides.joinToString(",") { "\"$it\":" + if (it == side) bad else "0" }
                    reject(",\"padding\":{$values}")
                    reject(",\"gap\":{\"size\":$bad}")
                }
            }
            reject(",\"gap\":{}")
            for (bad in listOf("null", "true", "1", "[]", "{}", "\"Primary\"", "\"unknown\"", "\"#FF8800\"")) {
                reject(",\"gap\":{\"size\":8,\"color\":$bad}")
            }
        }
    }

    @Test
    fun containerPaddingAndGapGeometry() {
        var row by mutableStateOf(false)
        var rtl by mutableStateOf(false)
        var count by mutableStateOf(3)
        var padding by mutableStateOf(UiPadding())
        var gap by mutableStateOf(UiGap())
        var density = 1f
        composeRule.setContent {
            density = LocalDensity.current.density
            CompositionLocalProvider(LocalLayoutDirection provides if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                Box(Modifier.width(300.dp).height(250.dp)) {
                    Box(Modifier.testTag("container")) {
                        // Nested unpadded columns must not inherit the parent's padding.
                        val children = List(count) { UiNode.Column(listOf(UiNode.Text("Child $it"))) }
                        val node = if (row) UiNode.Row(children, padding = padding, gap = gap)
                            else UiNode.Column(children, padding = padding, gap = gap)
                        UiNodeContent(node, {}, { _, _ -> }, false)
                    }
                }
            }
        }
        for (isRow in listOf(false, true)) for (isRtl in listOf(false, true)) {
            for (p in listOf(UiPadding(), UiPadding(16, 8, 4, 12))) {
                for (g in listOf(UiGap(), UiGap(0), UiGap(12))) for (n in 0..3) {
                    composeRule.runOnIdle { row = isRow; rtl = isRtl; padding = p; gap = g; count = n }
                    val container = composeRule.onNodeWithTag("container").fetchSemanticsNode().boundsInRoot
                    val children = List(n) { composeRule.onNodeWithText("Child $it").fetchSemanticsNode().boundsInRoot }
                    val horizontal = (p.start + p.end) * density
                    val vertical = (p.top + p.bottom) * density
                    val gaps = maxOf(0, n - 1) * g.size * density
                    val width = if (isRow) children.sumOf { it.width.toDouble() }.toFloat() + gaps
                        else children.maxOfOrNull { it.width } ?: 0f
                    val height = if (isRow) children.maxOfOrNull { it.height } ?: 0f
                        else children.sumOf { it.height.toDouble() }.toFloat() + gaps
                    assertEquals(width + horizontal, container.width, 2f)
                    assertEquals(height + vertical, container.height, 2f)
                    if (children.isNotEmpty()) {
                        assertEquals(p.top * density, children.first().top - container.top, 1f)
                        val start = if (isRtl) container.right - children.first().right else children.first().left - container.left
                        assertEquals(p.start * density, start, 1f)
                    }
                    children.zipWithNext().forEach { (a, b) ->
                        val actual = if (!isRow) b.top - a.bottom else if (isRtl) a.left - b.right else b.left - a.right
                        assertEquals(g.size * density, actual, 1f)
                    }
                }
            }
        }
    }

    @Test
    fun maximumSpacingRemainsWithinParentConstraints() {
        val maximum = Int.MAX_VALUE
        composeRule.setContent {
            Box(Modifier.width(200.dp).height(200.dp).testTag("bounded-spacing")) {
                UiNodeContent(UiNode.Column(
                    listOf(UiNode.Text("A"), UiNode.Text("B")),
                    padding = UiPadding(maximum, maximum, maximum, maximum),
                    gap = UiGap(maximum, ThemeColor.Primary),
                ), {}, { _, _ -> }, false)
            }
        }
        composeRule.onNodeWithTag("bounded-spacing").assertIsDisplayed()
    }

    @Test
    fun containerBackgroundUsesCurrentThemeWithoutChangingChildren() {
        var dark by mutableStateOf(false)
        var role by mutableStateOf<ThemeColor?>(null)
        var row by mutableStateOf(false)
        var expected = 0
        var foreground = 0
        val underlay = Color.Magenta.toArgb()
        composeRule.setContent {
            MyApplicationTheme(darkTheme = dark) {
                val colors = MaterialTheme.colorScheme
                expected = when (role) {
                    null -> underlay
                    ThemeColor.Background -> colors.background.toArgb()
                    ThemeColor.Surface -> colors.surface.toArgb()
                    ThemeColor.SurfaceContainer -> colors.surfaceContainer.toArgb()
                    ThemeColor.Primary -> colors.primary.toArgb()
                    ThemeColor.PrimaryContainer -> colors.primaryContainer.toArgb()
                    ThemeColor.OutlineVariant -> colors.outlineVariant.toArgb()
                }
                foreground = colors.onSurface.toArgb()
                Box(Modifier.width(300.dp).height(200.dp).background(Color.Magenta).testTag("paint"),
                    propagateMinConstraints = true) {
                    val children = listOf(UiNode.Column(listOf(UiNode.Text("Unchanged text"))), UiNode.Button("Button"))
                    val node = if (row) UiNode.Row(children, background = role)
                        else UiNode.Column(children, stretch = true, background = role)
                    UiNodeContent(node, {}, { _, _ -> }, false)
                }
            }
        }
        for (isRow in listOf(false, true)) {
            for (isDark in listOf(false, true)) {
                composeRule.runOnIdle { row = isRow; dark = isDark; role = null }
                val textBounds = composeRule.onNodeWithText("Unchanged text").fetchSemanticsNode().boundsInRoot
                val buttonBounds = composeRule.onNodeWithText("Button").fetchSemanticsNode().boundsInRoot
                val before = composeRule.onNodeWithTag("paint").captureToImage().asAndroidBitmap()
                for (color in ThemeColor.entries) {
                    composeRule.runOnIdle { role = color }
                    val bitmap = composeRule.onNodeWithTag("paint").captureToImage().asAndroidBitmap()
                    assertEquals(expected, bitmap.getPixel(bitmap.width - 1, bitmap.height - 1))
                    // The transparent nested column and inter-child gap expose the parent fill.
                    assertEquals(expected, bitmap.getPixel(0, 0))
                    val gapX = if (isRow) ((textBounds.right + buttonBounds.left) / 2).toInt() else 0
                    val gapY = if (isRow) 0 else ((textBounds.bottom + buttonBounds.top) / 2).toInt()
                    assertEquals(expected, bitmap.getPixel(gapX, gapY))
                    assertEquals(textBounds, composeRule.onNodeWithText("Unchanged text").fetchSemanticsNode().boundsInRoot)
                    assertEquals(buttonBounds, composeRule.onNodeWithText("Button").fetchSemanticsNode().boundsInRoot)
                    val buttonX = buttonBounds.center.x.toInt()
                    val buttonY = (buttonBounds.top + buttonBounds.height / 4).toInt()
                    assertEquals(before.getPixel(buttonX, buttonY), bitmap.getPixel(buttonX, buttonY))
                    var checkedForeground = false
                    for (y in 0 until before.height) for (x in 0 until before.width) {
                        if (before.getPixel(x, y) == foreground) {
                            assertEquals(foreground, bitmap.getPixel(x, y))
                            checkedForeground = true
                        }
                    }
                    assertTrue(checkedForeground)
                }
                composeRule.runOnIdle { role = null }
                val transparent = composeRule.onNodeWithTag("paint").captureToImage().asAndroidBitmap()
                assertEquals(underlay, transparent.getPixel(transparent.width - 1, transparent.height - 1))
            }
        }
    }

    @Test
    fun coloredGapsFollowInnerBoundsThemeAndDocument() {
        var row by mutableStateOf(false)
        var rtl by mutableStateOf(false)
        var dark by mutableStateOf(false)
        var color by mutableStateOf<ThemeColor?>(null)
        var count by mutableStateOf(3)
        var label by mutableStateOf("A")
        var gapSize by mutableStateOf(12)
        var width by mutableStateOf(280)
        var document by mutableStateOf<Any>(Any())
        var density = 1f
        var expected = 0
        var background = 0
        val padding = UiPadding(16, 8, 4, 12)
        composeRule.setContent {
            density = LocalDensity.current.density
            MyApplicationTheme(darkTheme = dark) {
                val colors = MaterialTheme.colorScheme
                background = colors.surface.toArgb()
                expected = when (color) {
                    null, ThemeColor.Surface -> colors.surface
                    ThemeColor.Background -> colors.background
                    ThemeColor.SurfaceContainer -> colors.surfaceContainer
                    ThemeColor.Primary -> colors.primary
                    ThemeColor.PrimaryContainer -> colors.primaryContainer
                    ThemeColor.OutlineVariant -> colors.outlineVariant
                }.toArgb()
                CompositionLocalProvider(
                    LocalLayoutDirection provides if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr,
                    LocalUiDocument provides document,
                ) {
                    Box(Modifier.width(300.dp).height(240.dp).background(Color.Magenta)) {
                        val children = listOf(UiNode.Text(label), UiNode.Button("B"), UiNode.Text("C")).take(count)
                        val gap = UiGap(gapSize, color)
                        val node = if (row) UiNode.Row(children, background = ThemeColor.Surface, padding = padding, gap = gap)
                            else UiNode.Column(children, background = ThemeColor.Surface, padding = padding, gap = gap)
                        UiNodeContent(node, {}, { _, _ -> }, false,
                            modifier = Modifier.width(width.dp).height(220.dp).testTag("colored"))
                    }
                }
            }
        }
        fun bounds() = listOf(label, "B", "C").take(count).map {
            val node = composeRule.onNodeWithText(it).fetchSemanticsNode()
            // boundsInRoot is clipped to zero for fully hidden children. Gap geometry
            // needs their actual positions, then clipping to the container below.
            androidx.compose.ui.geometry.Rect(node.positionInRoot,
                androidx.compose.ui.geometry.Size(node.size.width.toFloat(), node.size.height.toFloat()))
        }
        fun checkPixels(): Bitmap {
            val parent = composeRule.onNodeWithTag("colored").fetchSemanticsNode().boundsInRoot
            val children = bounds()
            val bitmap = composeRule.onNodeWithTag("colored").captureToImage().asAndroidBitmap()
            val left = (if (rtl) padding.end else padding.start) * density
            val right = bitmap.width - (if (rtl) padding.start else padding.end) * density
            val top = padding.top * density
            val bottom = bitmap.height - padding.bottom * density
            assertEquals(background, bitmap.getPixel(0, 0))
            assertEquals(background, bitmap.getPixel(bitmap.width - 1, bitmap.height - 1))
            assertEquals(background, bitmap.getPixel((left + 1).toInt(), (top / 2).toInt()))
            children.zipWithNext().forEach { (a, b) ->
                val start = maxOf(if (row) left else top,
                    if (!row) a.bottom - parent.top else if (rtl) b.right - parent.left else a.right - parent.left)
                val end = minOf(if (row) right else bottom,
                    if (!row) b.top - parent.top else if (rtl) a.left - parent.left else b.left - parent.left)
                if (gapSize > 0 && end - start >= 2f) {
                    val middle = ((start + end) / 2).toInt()
                    if (row) {
                        for (y in (top + 1).toInt() until (bottom - 1).toInt()) assertEquals(
                            "row rtl=$rtl dark=$dark gap=$gapSize parent=$parent children=$children pixel=($middle,$y) density=$density",
                            expected, bitmap.getPixel(middle, y))
                        assertEquals(background, bitmap.getPixel(middle, (top / 2).toInt()))
                    } else {
                        for (x in (left + 1).toInt() until (right - 1).toInt()) assertEquals(
                            "column rtl=$rtl dark=$dark gap=$gapSize parent=$parent children=$children pixel=($x,$middle) density=$density",
                            expected, bitmap.getPixel(x, middle))
                        assertEquals(background, bitmap.getPixel((left / 2).toInt(), middle))
                    }
                }
            }
            if (count < 2 || gapSize == 0) {
                // At this edge there are no glyphs or button pixels: stale stripes stand out.
                if (row) for (x in (left + 1).toInt() until (right - 1).toInt())
                    assertEquals(background, bitmap.getPixel(x, (bottom - 1).toInt()))
                else for (y in (top + 1).toInt() until (bottom - 1).toInt())
                    assertEquals(background, bitmap.getPixel((if (rtl) left + 1 else right - 1).toInt(), y))
            }
            return bitmap
        }
        for (isRow in listOf(false, true)) for (isRtl in listOf(false, true)) for (isDark in listOf(false, true)) {
            composeRule.runOnIdle { row = isRow; rtl = isRtl; dark = isDark; color = null; count = 3; label = "A"; gapSize = 12; width = 280 }
            val before = bounds()
            checkPixels()
            for (role in ThemeColor.entries) {
                composeRule.runOnIdle { color = role }
                checkPixels()
                assertEquals(before, bounds())
            }
            composeRule.runOnIdle { color = ThemeColor.Primary; label = "Longer A\nsecond line"; document = Any() }
            checkPixels()
            composeRule.runOnIdle { count = 2 }
            checkPixels()
            composeRule.runOnIdle { gapSize = 0 }
            checkPixels()
            composeRule.runOnIdle { gapSize = 12; count = 1 }
            checkPixels()
            composeRule.runOnIdle { count = 0 }
            checkPixels()
            composeRule.runOnIdle { count = 3; label = "A"; width = 80; gapSize = 100 }
            checkPixels()
        }
    }

    @Test
    fun emulatorPanelSurfaceFillsAllocationAndPreservesPreview() {
        var dark by mutableStateOf(false)
        var preview by mutableStateOf(false)
        var surface = 0
        var background = 0
        var divider = 0
        var density = 1f
        val taps = mutableListOf<Pair<UiEvent, String>>()
        val source = Bitmap.createBitmap(80, 40, Bitmap.Config.ARGB_8888).apply {
            eraseColor(android.graphics.Color.RED)
        }.asImageBitmap()
        composeRule.setContent {
            MyApplicationTheme(darkTheme = dark) {
                density = LocalDensity.current.density
                surface = MaterialTheme.colorScheme.surface.toArgb()
                background = MaterialTheme.colorScheme.background.toArgb()
                divider = MaterialTheme.colorScheme.outlineVariant.toArgb()
                // Same outer two-child column and nested content as Emulator.view.
                val panel = UiNode.Column(
                    listOf(UiNode.Column(emptyList()), UiNode.Column(listOf(
                        UiNode.Text("Emulators"),
                        UiNode.Row(listOf(UiNode.Button("Refresh", UiEvent("[\"Refresh\"]")))),
                        if (preview) UiNode.Image("/emulators/emulator-5554/screenshot.png", "Pixel", UiEvent("[\"Tap\"]"))
                        else UiNode.Text("No running emulators"),
                    ))),
                    weights = listOf(0f, 0f), background = ThemeColor.Surface,
                )
                androidx.compose.foundation.layout.Column(
                    Modifier.width(320.dp).height(400.dp).background(MaterialTheme.colorScheme.background).testTag("screen")
                ) {
                    androidx.compose.material3.Text("Header", Modifier.height(40.dp))
                    Box(Modifier.weight(1f).then(Modifier.width(300.dp)).testTag("panes")) {
                        UiNodeContent(UiNode.Row(listOf(UiNode.Text("Left"), panel), listOf(2f, 1f),
                            gap = UiGap(1, ThemeColor.OutlineVariant)),
                            {}, { event, value -> taps.add(event to value) }, false, { source })
                    }
                }
            }
        }
        for (isDark in listOf(false, true)) {
            for (showPreview in listOf(false, true)) {
                composeRule.runOnIdle { dark = isDark; preview = showPreview }
                if (showPreview) composeRule.waitUntil(5_000) {
                    composeRule.onAllNodes(androidx.compose.ui.test.hasTestTag("image")).fetchSemanticsNodes().isNotEmpty()
                }
                val panes = composeRule.onNodeWithTag("panes").fetchSemanticsNode().boundsInRoot
                val title = composeRule.onNodeWithText("Emulators").fetchSemanticsNode().boundsInRoot
                val image = composeRule.onNodeWithTag("screen").captureToImage().asAndroidBitmap()
                assertEquals(background, image.getPixel(image.width - 1, image.height - 1))
                assertEquals(background, image.getPixel(image.width - 1, 1))
                assertEquals(background, image.getPixel(0, image.height - 1))
                assertEquals(surface, image.getPixel(title.left.toInt(), image.height - 1))
                assertEquals(surface, image.getPixel(panes.right.toInt() - 1, image.height - 1))
                val leftWidth = composeRule.onNodeWithText("Left").fetchSemanticsNode().boundsInRoot.width
                assertEquals(leftWidth / 2, panes.right - title.left, 1f)
                assertEquals(density, title.left - (panes.left + leftWidth), 1f)
                if (isDark) assertEquals(Color(0xFF343A43).toArgb(), divider)
                val dividerX = (title.left - density / 2).toInt()
                for (y in (panes.top + 1).toInt() until (panes.bottom - 1).toInt()) {
                    assertEquals(divider, image.getPixel(dividerX, y))
                }
                if (showPreview) {
                    val context = InstrumentationRegistry.getInstrumentation().targetContext
                    File(context.getExternalFilesDir(null), "panel-divider-$isDark.png").outputStream().use {
                        image.compress(Bitmap.CompressFormat.PNG, 100, it)
                    }
                }
                if (showPreview) {
                    val node = composeRule.onNodeWithTag("image")
                    val bounds = node.fetchSemanticsNode().boundsInRoot
                    // ContentScale.Fit preserves the painted bitmap's ratio, not its layout box's.
                    val red = android.graphics.Color.RED
                    val paintedWidth = (bounds.left.toInt() until bounds.right.toInt()).count {
                        image.getPixel(it, bounds.center.y.toInt()) == red
                    }
                    val paintedHeight = (bounds.top.toInt() until bounds.bottom.toInt()).count {
                        image.getPixel(bounds.center.x.toInt(), it) == red
                    }
                    assertEquals(2f, paintedWidth.toFloat() / paintedHeight, 0.06f)
                    assertEquals(android.graphics.Color.RED, image.getPixel(bounds.center.x.toInt(), bounds.center.y.toInt()))
                    node.performTouchInput { click(center) }
                    composeRule.runOnIdle {
                        val (event, value) = taps.last()
                        assertEquals(UiEvent("[\"Tap\"]"), event)
                        val json = JSONObject(value)
                        assertEquals(80, json.getInt("width"))
                        assertEquals(40, json.getInt("height"))
                        assertTrue(json.getInt("x") in 39..40)
                        assertTrue(json.getInt("y") in 19..20)
                    }
                }
            }
        }
        assertEquals(2, taps.size)
    }

    @Test
    fun paddedColoredGapsPreserveWeightsScrollingAndInteractions() {
        var dark by mutableStateOf(false)
        var rtl by mutableStateOf(false)
        var colored by mutableStateOf(false)
        var decorated by mutableStateOf(false)
        var density = 1f
        var primary = 0
        var nestedColor = 0
        var surface = 0
        var outline = 0
        var background = 0
        val events = mutableListOf<UiEvent>()
        composeRule.setContent {
            density = LocalDensity.current.density
            MyApplicationTheme(darkTheme = dark) {
                primary = MaterialTheme.colorScheme.primary.toArgb()
                nestedColor = MaterialTheme.colorScheme.primaryContainer.toArgb()
                surface = MaterialTheme.colorScheme.surface.toArgb()
                outline = MaterialTheme.colorScheme.outlineVariant.toArgb()
                background = MaterialTheme.colorScheme.background.toArgb()
                CompositionLocalProvider(LocalLayoutDirection provides if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                    androidx.compose.foundation.layout.Column(
                        Modifier.width(240.dp).height(440.dp).background(MaterialTheme.colorScheme.background).testTag("spacing-preview")
                    ) {
                        UiNodeContent(
                            UiNode.Row(listOf(UiNode.Text("Left"), UiNode.Text("Right")), weights = listOf(1f, 1f),
                                background = ThemeColor.Surface, padding = UiPadding(10, 8, 10, 8),
                                gap = UiGap(20, if (colored) ThemeColor.Primary else null),
                                border = if (decorated) UiBorder(2, ThemeColor.OutlineVariant) else null,
                                cornerRadius = if (decorated) 12 else 0),
                            {}, { _, _ -> }, false, modifier = Modifier.width(200.dp).height(60.dp).testTag("weighted-row"),
                        )
                        UiNodeContent(
                            UiNode.Column(listOf(
                                UiNode.Button("Header", UiEvent("[\"Header\"]")),
                                UiNode.Column(List(40) { UiNode.Text("Line $it") }, padding = UiPadding(4, 4, 4, 4),
                                    gap = UiGap(2, if (colored) ThemeColor.PrimaryContainer else null)),
                                UiNode.Button("Footer", UiEvent("[\"Footer\"]")),
                            ), weights = listOf(0f, 1f, 0f), stretch = true, background = ThemeColor.Surface,
                                padding = UiPadding(10, 8, 10, 12), gap = UiGap(12, if (colored) ThemeColor.Primary else null),
                                border = if (decorated) UiBorder(2, ThemeColor.OutlineVariant) else null,
                                cornerRadius = if (decorated) 12 else 0),
                            { events.add(it) }, { _, _ -> }, false,
                            modifier = Modifier.width(200.dp).height(360.dp).testTag("weighted-column"),
                        )
                    }
                }
            }
        }
        for (isDark in listOf(false, true)) for (isRtl in listOf(false, true)) {
            composeRule.runOnIdle { dark = isDark; rtl = isRtl; colored = false; decorated = false }
            val row = composeRule.onNodeWithTag("weighted-row").fetchSemanticsNode().boundsInRoot
            val column = composeRule.onNodeWithTag("weighted-column").fetchSemanticsNode().boundsInRoot
            val left = composeRule.onNodeWithText("Left").fetchSemanticsNode().boundsInRoot
            val right = composeRule.onNodeWithText("Right").fetchSemanticsNode().boundsInRoot
            assertEquals(80 * density, left.width, 1f)
            assertEquals(80 * density, right.width, 1f)
            val header = composeRule.onNodeWithText("Header").fetchSemanticsNode().boundsInRoot
            val footer = composeRule.onNodeWithText("Footer").fetchSemanticsNode().boundsInRoot
            val scroll = composeRule.onNode(hasScrollAction())
            val allocation = scroll.fetchSemanticsNode().boundsInRoot
            assertEquals(180 * density, allocation.width, 1f)
            assertEquals(220 * density, allocation.height, 1f)
            assertEquals(180 * density, header.width, 1f)
            assertEquals(180 * density, footer.width, 1f)
            // Button semantics exclude some Material minimum-touch layout space; the
            // allocation edges and actual gap samples below verify the wrapper layout.
            assertTrue(allocation.top > header.bottom)
            assertTrue(allocation.bottom < footer.top)
            val before = composeRule.onNodeWithTag("spacing-preview").captureToImage().asAndroidBitmap()
            composeRule.runOnIdle { colored = true }
            assertEquals(allocation, scroll.fetchSemanticsNode().boundsInRoot)
            assertEquals(header, composeRule.onNodeWithText("Header").fetchSemanticsNode().boundsInRoot)
            assertEquals(footer, composeRule.onNodeWithText("Footer").fetchSemanticsNode().boundsInRoot)
            val previewBounds = composeRule.onNodeWithTag("spacing-preview").fetchSemanticsNode().boundsInRoot
            fun checkPaint() {
                val image = composeRule.onNodeWithTag("spacing-preview").captureToImage().asAndroidBitmap()
                fun pixel(x: Float, y: Float) = image.getPixel((x - previewBounds.left).toInt(), (y - previewBounds.top).toInt())
                assertEquals(primary, pixel(row.center.x, row.top + 10 * density))
                assertEquals(surface, pixel(row.center.x, row.top + 2 * density))
                assertEquals(primary, pixel(column.center.x, allocation.top - 6 * density))
                assertEquals(primary, pixel(column.center.x, allocation.bottom + 6 * density))
                assertEquals(surface, pixel(column.left + 2 * density, allocation.top - 6 * density))
                val buttonX = (header.center.x - previewBounds.left).toInt()
                val buttonY = (header.top + header.height / 4 - previewBounds.top).toInt()
                assertEquals("Button fill changed: dark=$dark rtl=$rtl", before.getPixel(buttonX, buttonY), image.getPixel(buttonX, buttonY))
            }
            scroll.performScrollToNode(hasText("Line 0"))
            checkPaint()
            val line0 = composeRule.onNodeWithText("Line 0").fetchSemanticsNode().boundsInRoot
            val line1 = composeRule.onNodeWithText("Line 1").fetchSemanticsNode().boundsInRoot
            val screenshot = composeRule.onNodeWithTag("spacing-preview").captureToImage().asAndroidBitmap()
            assertEquals(nestedColor, screenshot.getPixel(
                (allocation.center.x - previewBounds.left).toInt(), ((line0.bottom + line1.top) / 2 - previewBounds.top).toInt()))
            val context = InstrumentationRegistry.getInstrumentation().targetContext
            File(context.getExternalFilesDir(null), "spacing-$isDark-$isRtl.png").outputStream().use {
                screenshot.compress(Bitmap.CompressFormat.PNG, 100, it)
            }
            scroll.performScrollToNode(hasText("Line 39"))
            composeRule.onNodeWithText("Line 39").assertIsDisplayed()
            checkPaint()
            composeRule.runOnIdle { decorated = true }
            assertEquals(left, composeRule.onNodeWithText("Left").fetchSemanticsNode().boundsInRoot)
            assertEquals(right, composeRule.onNodeWithText("Right").fetchSemanticsNode().boundsInRoot)
            assertEquals(allocation, scroll.fetchSemanticsNode().boundsInRoot)
            assertEquals(header, composeRule.onNodeWithText("Header").fetchSemanticsNode().boundsInRoot)
            assertEquals(footer, composeRule.onNodeWithText("Footer").fetchSemanticsNode().boundsInRoot)
            for (line in listOf("Line 0", "Line 39")) {
                scroll.performScrollToNode(hasText(line))
                composeRule.onNodeWithText(line).assertIsDisplayed()
                val painted = composeRule.onNodeWithTag("spacing-preview").captureToImage().asAndroidBitmap()
                fun pixel(x: Float, y: Float) = painted.getPixel((x - previewBounds.left).toInt(), (y - previewBounds.top).toInt())
                for (bounds in listOf(row, column)) {
                    assertEquals(outline, pixel(bounds.center.x, bounds.top + density))
                    assertEquals(background, pixel(bounds.left + density, bounds.top + density))
                }
                assertEquals(primary, pixel(row.center.x, row.top + 10 * density))
                assertEquals(primary, pixel(column.center.x, allocation.top - 6 * density))
            }
        }
        composeRule.onNodeWithText("Header").performClick()
        composeRule.onNodeWithText("Footer").performClick()
        assertEquals(listOf(UiEvent("[\"Header\"]"), UiEvent("[\"Footer\"]")), events)
    }

    @Test
    fun voiceNodeContractAndRepeatedDraftReplacement() {
        val json = """{"@type":"row","weights":[1,0],"children":[{"@type":"input","label":"Prompt","text":"voice","event":["Run_prompt","__VALUE__"]},{"@type":"voice_input","event":["Set_prompt","__VALUE__"]}]}"""
        val parsed = parseUiNode(json) as UiNode.Row
        assertEquals(UiNode.VoiceInput(UiEvent("""["Set_prompt","__VALUE__"]""")), parsed.children[1])
        for (invalid in listOf(
            """{"@type":"voice_input"}""",
            """{"@type":"voice_input","event":{}}""",
            """{"@type":"voice_input","event":null}""",
            """{"@type":"voice_input","event":[],"label":""}""",
            """{"@type":"voice_input","event":[],"text":null}""",
        )) assertTrue(runCatching { parseUiNode(invalid) }.isFailure)
        var document by mutableStateOf(parsed as UiNode, androidx.compose.runtime.referentialEqualityPolicy())
        var busy by mutableStateOf(false)
        val submitted = mutableListOf<String>()
        var documentIdentity by mutableStateOf(Any())
        composeRule.setContent {
            androidx.compose.runtime.CompositionLocalProvider(LocalUiDocument provides documentIdentity) {
            UiNodeContent(document, {}, { _, value -> submitted.add(value) }, busy)
            }
        }
        composeRule.onNodeWithTag("voice_input").assertIsDisplayed()
        composeRule.onNodeWithTag("input").performTextInput("edited-")
        composeRule.runOnIdle { busy = true }
        composeRule.onNodeWithTag("input").assertTextContains("edited-voice")
        composeRule.runOnIdle { busy = false }
        composeRule.onNodeWithTag("input").assertTextContains("edited-voice")
        composeRule.runOnIdle { document = parseUiNode(json); documentIdentity = Any() }
        composeRule.onNodeWithTag("input").assertTextContains("voice")
        composeRule.onNodeWithTag("input").performTextInput("new-")
        composeRule.onNodeWithTag("input").performKeyInput { keyDown(Key.Enter); keyUp(Key.Enter) }
        composeRule.runOnIdle { assertEquals(listOf("voicenew-"), submitted) }
    }

    @Test
    fun parsesColumnStretchStrictly() {
        for (stretch in listOf(null, false, true)) {
            val json = JSONObject("""{"@type":"column","children":[]}""")
            if (stretch != null) json.put("stretch", stretch)
            assertEquals(
                UiNode.Column(emptyList(), stretch = stretch ?: false),
                parseUiNode(json.toString()),
            )
        }
        for (value in listOf("\"true\"", "1", "null", "[]", "{}")) {
            val result = runCatching {
                parseUiNode("""{"@type":"column","children":[],"stretch":$value}""")
            }
            assertTrue(
                "Accepted stretch: $value",
                result.exceptionOrNull() is IllegalArgumentException,
            )
        }
    }

    private fun captureStretch(name: String) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val file = File(context.getExternalFilesDir(null), "column-stretch-$name.png")
        file.outputStream().use {
            composeRule
                .onRoot()
                .captureToImage()
                .asAndroidBitmap()
                .compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }

    @Test
    fun columnStretchFillsActualControlsAndRespectsParentWidth() {
        var stretch by mutableStateOf<Boolean?>(null)
        var width by mutableStateOf(320.dp)
        composeRule.setContent {
            Box(Modifier.width(width).testTag("parent")) {
                val json =
                    JSONObject(
                        """{"@type":"column","children":[{"@type":"button","label":"Button"},{"@type":"input","label":"Input","event":["Input"]},{"@type":"text","text":"Text"}]}"""
                    )
                stretch?.let { json.put("stretch", it) }
                UiNodeContent(parseUiNode(json.toString()), {}, { _, _ -> }, false)
            }
        }
        val controls =
            listOf(
                composeRule.onNodeWithText("Button"),
                composeRule.onNodeWithTag("input"),
                composeRule.onNodeWithText("Text"),
            )
        val original = controls.map { it.fetchSemanticsNode().boundsInRoot }
        captureStretch("default")
        composeRule.runOnIdle { stretch = false }
        assertEquals(original, controls.map { it.fetchSemanticsNode().boundsInRoot })
        for (parentWidth in listOf(320.dp, 300.dp)) {
            composeRule.runOnIdle {
                stretch = true
                width = parentWidth
            }
            val parent = composeRule.onNodeWithTag("parent").fetchSemanticsNode().boundsInRoot
            controls.forEachIndexed { index, control ->
                val bounds = control.fetchSemanticsNode().boundsInRoot
                assertEquals(parent.left, bounds.left, 1f)
                assertEquals(parent.right, bounds.right, 1f)
                assertEquals(original[index].height, bounds.height, 1f)
                assertTrue(original[index].width < bounds.width)
            }
        }
        captureStretch("enabled")
    }

    @Test
    fun columnStretchDoesNotStretchGrandchildren() {
        composeRule.setContent {
            Box(Modifier.width(300.dp).testTag("parent")) {
                UiNodeContent(
                    UiNode.Column(
                        listOf(
                            UiNode.Row(listOf(UiNode.Button("Row child"))),
                            UiNode.Column(listOf(UiNode.Button("Column child"))),
                        ),
                        stretch = true,
                    ),
                    {},
                    { _, _ -> },
                    false,
                )
            }
        }
        val parent = composeRule.onNodeWithTag("parent").fetchSemanticsNode().boundsInRoot
        for (label in listOf("Row child", "Column child")) {
            val child = composeRule.onNodeWithText(label).fetchSemanticsNode()
            assertTrue(child.boundsInRoot.width < parent.width)
            assertEquals(parent.width, child.layoutInfo.parentInfo!!.width.toFloat(), 1f)
        }
        captureStretch("nested")
    }

    @Test
    fun stretchingWeightedColumnKeepsControlsFixedWhileScrolling() {
        var stretch by mutableStateOf(false)
        var background by mutableStateOf<ThemeColor?>(null)
        composeRule.setContent {
            Box(Modifier.width(300.dp).height(300.dp).testTag("parent")) {
                UiNodeContent(
                    UiNode.Column(
                        listOf(
                            UiNode.Button("Fixed"),
                            UiNode.Column(List(100) { UiNode.Text("Stretch output $it") }),
                            UiNode.Input("Commands", UiEvent("[\"Run\"]")),
                        ),
                        listOf(0f, 1f, 0f),
                        stretch,
                        background,
                    ),
                    {},
                    { _, _ -> },
                    false,
                )
            }
        }
        val controls =
            listOf(composeRule.onNodeWithText("Fixed"), composeRule.onNodeWithTag("input"))
        val original = controls.map { it.fetchSemanticsNode().boundsInRoot }
        composeRule.runOnIdle { background = ThemeColor.Surface }
        assertEquals(original, controls.map { it.fetchSemanticsNode().boundsInRoot })
        composeRule.runOnIdle { stretch = true }
        val parent = composeRule.onNodeWithTag("parent").fetchSemanticsNode().boundsInRoot
        val stretched = controls.map { it.fetchSemanticsNode().boundsInRoot }
        stretched.forEachIndexed { index, bounds ->
            assertEquals(parent.width, bounds.width, 1f)
            assertEquals(original[index].height, bounds.height, 1f)
            assertEquals(original[index].top, bounds.top, 1f)
        }
        val scroll = composeRule.onNode(hasScrollAction())
        assertEquals(parent.width, scroll.fetchSemanticsNode().boundsInRoot.width, 1f)
        val output = composeRule.onNodeWithText("Stretch output 0").fetchSemanticsNode()
        assertEquals(parent.width, output.layoutInfo.parentInfo!!.width.toFloat(), 1f)
        captureStretch("weighted")
        scroll.performScrollToNode(hasText("Stretch output 99"))
        composeRule.onNodeWithText("Stretch output 99").assertIsDisplayed()
        controls.forEach { it.assertIsDisplayed() }
        assertEquals(stretched, controls.map { it.fetchSemanticsNode().boundsInRoot })
        captureStretch("scrolled")
    }

    @Test
    fun parsesTextRowsEventsAndInputsAndRejectsUnsupportedDocuments() {
        assertEquals(
            UiNode.Column(
                listOf(
                    UiNode.Text("Worktrees"),
                    UiNode.Row(
                        listOf(
                            UiNode.Button("OK"),
                            UiNode.Button("New", UiEvent("[\"New\"]")),
                            UiNode.Input("Input", UiEvent("[\"Input\"]")),
                        )
                    ),
                )
            ),
            parseUiNode(
                """{"@type":"column","children":[{"@type":"text","text":"Worktrees"},{"@type":"row","children":[{"@type":"button","label":"OK"},{"@type":"button","label":"New","event":["New"]},{"@type":"input","label":"Input","event":["Input"]}]}]}"""
            ),
        )

        val worktreeButton =
            parseUiNode(
                """{"@type":"button","label":"Worktree","event":["Worktrees_msg",["Select","/tmp/clicked"]]}"""
            )
                as UiNode.Button
        assertEquals("Worktree", worktreeButton.label)
        assertEquals(
            "/tmp/clicked",
            JSONArray(requireNotNull(worktreeButton.event).json).getJSONArray(1).getString(1),
        )

        assertEquals(
            UiNode.Input("Input", UiEvent("[\"Input\"]"), "draft"),
            parseUiNode("""{"@type":"input","label":"Input","event":["Input"],"text":"draft"}"""),
        )
        assertEquals(
            UiNode.Row(listOf(UiNode.Text("Left"), UiNode.Text("Right")), listOf(2f, 1f)),
            parseUiNode(
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[2,1]}"""
            ),
        )
        assertEquals(
            UiNode.Row(listOf(UiNode.Text("Fixed"), UiNode.Text("Rest")), listOf(0f, 1f)),
            parseUiNode(
                """{"@type":"row","children":[{"@type":"text","text":"Fixed"},{"@type":"text","text":"Rest"}],"weights":[0,1]}"""
            ),
        )
        assertEquals(
            UiNode.Column(listOf(UiNode.Text("Fixed"), UiNode.Text("Rest")), listOf(0f, 1f)),
            parseUiNode(
                """{"@type":"column","children":[{"@type":"text","text":"Fixed"},{"@type":"text","text":"Rest"}],"weights":[0,1]}"""
            ),
        )
        assertEquals(
            UiNode.Image("/emulators/emulator-5554/screenshot.png", "Pixel"),
            parseUiNode(
                """{"@type":"image","src":"/emulators/emulator-5554/screenshot.png","label":"Pixel"}"""
            ),
        )

        listOf(
                """{"@type":"text"}""",
                """{"@type":"text","text":1}""",
                """{"@type":"row"}""",
                """{"@type":"row","children":{}}""",
                """{"@type":"row","children":["bad"]}""",
                """{"@type":"row","children":[],"weights":{}}""",
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[1]}""",
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[1,"bad"]}""",
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[1,-1]}""",
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[1,1e400]}""",
                """{"@type":"column","children":[],"weights":{}}""",
                """{"@type":"column","children":[{"@type":"text","text":"Only"}],"weights":[]}""",
                """{"@type":"column","children":[{"@type":"text","text":"Only"}],"weights":["bad"]}""",
                """{"@type":"column","children":[{"@type":"text","text":"Only"}],"weights":[-1]}""",
                """{"@type":"button","label":"Event","event":"not-an-object"}""",
                """{"@type":"input","event":{"type":"input"}}""",
                """{"@type":"input","label":1,"event":{"type":"input"}}""",
                """{"@type":"input","label":"Input"}""",
                """{"@type":"input","label":"Input","event":"not-an-object"}""",
                """{"@type":"input","label":"Input","event":{"type":"input"},"text":1}""",
                """{"@type":"image","label":"Pixel"}""",
                """{"@type":"image","src":1,"label":"Pixel"}""",
                """{"@type":"image","src":"https://example.com/screenshot.png","label":"Pixel"}""",
                """{"@type":"image","src":"//example.com/screenshot.png","label":"Pixel"}""",
                """{"@type":"image","src":"/emulators/5554.png","label":1}""",
            )
            .forEach { json ->
                try {
                    parseUiNode(json)
                    fail("Unsupported document was accepted: $json")
                } catch (_: Exception) {}
            }
    }

    @Test
    fun parsesOptionalImageEventStrictly() {
        val event = UiEvent("""["Emulator_msg",["Tap","emulator-5554","__VALUE__"]]""")
        assertEquals(
            UiNode.Image("/preview.png", "Pixel", event),
            parseUiNode(
                """{"@type":"image","src":"/preview.png","label":"Pixel","event":${event.json}}"""
            ),
        )
        for (value in listOf("null", "{}", "\"tap\"", "1", "true")) {
            assertTrue(
                "Accepted image event: $value",
                runCatching {
                    parseUiNode(
                        """{"@type":"image","src":"/preview.png","label":"Pixel","event":$value}"""
                    )
                }
                    .isFailure,
            )
        }
    }

    @Test
    fun buildsEventRequestEnvelope() {
        val request =
            JSONObject(
                eventRequest(UiEvent("[\"Worktree_msg\",[\"Run_prompt\",\"__VALUE__\"]]"), "draft")
            )

        assertEquals(
            "Run_prompt",
            request.getJSONArray("event").getJSONArray(1).getString(0),
        )
        assertEquals("draft", request.getString("value"))
        assertEquals(
            true,
            JSONObject(eventRequest(refreshEvent, null)).isNull("value"),
        )
        assertEquals(
            true,
            JSONObject(eventRequest(refreshEvent, null)).has("value"),
        )
    }

    @Test
    fun replacesDisplayedDocumentForEachStreamedLine() {
        val documents =
            listOf(
                    """{"@type":"text","text":"Hel"}""",
                    """{"@type":"text","text":"Hello"}""",
                )
                .map(::parseUiNode)
        var node by mutableStateOf(documents.first())
        composeRule.setContent { UiNodeContent(node, {}, { _, _ -> }, false) }

        documents.forEach { document ->
            composeRule.runOnIdle { node = document }
            composeRule
                .onNodeWithText((document as UiNode.Text).text)
                .assertTextContains(document.text)
        }
    }

    @Test
    fun arrowSubmitsEditedDraftAndPreservesItAfterFailure() {
        val event = UiEvent("""["Run_prompt","__VALUE__"]""")
        val submitted = mutableListOf<Pair<UiEvent, String>>()
        var busy by mutableStateOf(false)
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Prompt", event, "recognized text"),
                {},
                { action, value -> submitted.add(action to value); busy = true },
                busy,
            )
        }
        val input = composeRule.onNodeWithTag("input")
        val arrow = composeRule.onNodeWithContentDescription("Submit Prompt")
        input.performTextReplacement("edited recognized text")
        arrow.assertIsDisplayed().assertWidthIsAtLeast(48.dp).assertHeightIsAtLeast(48.dp)
        arrow.performClick()
        arrow.assertIsNotEnabled().performTouchInput { click() }
        input.assertTextContains("edited recognized text")
        composeRule.runOnIdle {
            assertEquals(listOf(event to "edited recognized text"), submitted)
            busy = false // A failed request retains the same document.
        }
        input.assertTextContains("edited recognized text")
        composeRule.runOnIdle { assertEquals(1, submitted.size) }
        arrow.performClick()
        composeRule.runOnIdle { assertEquals(List(2) { event to "edited recognized text" }, submitted) }
    }

    @Test
    fun inputSubmitsItsValueOnHardwareEnter() {
        var submitted: Pair<UiEvent, String>? = null
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Input", UiEvent("[\"Input\"]")),
                {},
                { event, value -> submitted = event to value },
                false,
            )
        }

        composeRule.onNodeWithTag("input").performTextInput("draft")
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }

        composeRule.runOnIdle {
            assertEquals(UiEvent("[\"Input\"]") to "draft", submitted)
        }
    }

    @Test
    fun buttonSubmitsItsEvent() {
        var submitted: UiEvent? = null
        composeRule.setContent {
            UiNodeContent(
                UiNode.Button("Worktree", UiEvent("[\"Select\"]")),
                { event -> submitted = event },
                { _, _ -> },
                false,
            )
        }

        composeRule.onNodeWithText("Worktree").performClick()

        composeRule.runOnIdle {
            assertEquals(UiEvent("[\"Select\"]"), submitted)
        }
    }

    @Test
    fun inputBlocksDuplicateEnterWhileSubmitting() {
        var calls = 0
        var inProgress by mutableStateOf(false)
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Input", UiEvent("[\"Input\"]")),
                {},
                { _, _ ->
                    calls++
                    inProgress = true
                },
                inProgress,
            )
        }

        composeRule.onNodeWithTag("input").performClick()
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }

        composeRule.runOnIdle { assertEquals(1, calls) }
    }

    @Test
    fun inputAcceptsAnEventAfterStreamCompletion() {
        var calls = 0
        var inProgress by mutableStateOf(true)
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Input", UiEvent("[\"Input\"]")),
                {},
                { _, _ -> calls++ },
                inProgress,
            )
        }

        composeRule.runOnIdle { inProgress = false }
        composeRule.onNodeWithTag("input").performClick()
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }

        composeRule.runOnIdle { assertEquals(1, calls) }
    }

    @Test
    fun inputKeepsDraftWhenSubmissionEndsWithoutReplacement() {
        var inProgress by mutableStateOf(false)
        composeRule.setContent {
            UiNodeContent(
                parseUiNode(
                    """{"@type":"input","label":"Input","event":["Input"],"text":"seed"}"""
                ),
                {},
                { _, _ -> },
                inProgress,
            )
        }

        composeRule.onNodeWithTag("input").assertTextContains("seed")
        composeRule.onNodeWithTag("input").performTextInput("-draft")
        composeRule.runOnIdle { inProgress = true }
        composeRule.runOnIdle { inProgress = false }

        composeRule.onNodeWithTag("input").assertTextContains("-draftseed")
    }

    @Test
    fun inputUsesTextFromReplacementDocument() {
        var node by mutableStateOf<UiNode>(UiNode.Input("Input", UiEvent("[\"Input\"]"), "seed"))
        composeRule.setContent {
            UiNodeContent(node, {}, { _, _ -> }, false)
        }

        composeRule.onNodeWithTag("input").performTextInput("-draft")
        composeRule.runOnIdle {
            node = UiNode.Input("Input", UiEvent("[\"Input\"]"), "returned")
        }

        composeRule.onNodeWithTag("input").assertTextContains("returned")
    }

    @Test
    fun decodesPng() {
        val bytes =
            ByteArrayOutputStream().use { output ->
                Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
                    .compress(
                        Bitmap.CompressFormat.PNG,
                        100,
                        output,
                    )
                output.toByteArray()
            }

        assertEquals(1, decodePng(bytes).width)
    }

    @Test
    fun imageRendersAndKeepsSurroundingContentOnFailure() {
        var events = 0
        composeRule.setContent {
            UiNodeContent(
                UiNode.Column(
                    listOf(
                        UiNode.Text("Still here"),
                        UiNode.Image(
                            "/emulators/emulator-5554/screenshot.png",
                            "Pixel",
                            UiEvent("[\"Tap\"]"),
                        ),
                    )
                ),
                {},
                { _, _ -> events++ },
                false,
                loadImage = { throw IllegalStateException("unavailable") },
            )
        }

        composeRule.onNodeWithText("Still here").assertTextContains("Still here")
        composeRule.onNodeWithText("Error: Pixel").assertTextContains("Error: Pixel")
        composeRule.onNodeWithText("Error: Pixel").performTouchInput { click() }
        assertEquals(0, events)
    }

    @Test
    fun weightedRowUsesProportionalWidths() {
        composeRule.setContent {
            UiNodeContent(
                UiNode.Row(
                    listOf(UiNode.Image("/left.png", "Left"), UiNode.Image("/right.png", "Right")),
                    listOf(2f, 1f),
                ),
                {},
                { _, _ -> },
                false,
                loadImage = { ImageBitmap(1, 1) },
            )
        }

        val left =
            composeRule.onNodeWithContentDescription("Left").fetchSemanticsNode().boundsInRoot.width
        val right =
            composeRule
                .onNodeWithContentDescription("Right")
                .fetchSemanticsNode()
                .boundsInRoot
                .width
        assertEquals(2f, left / right, 0.01f)
    }

    @Test
    fun weightedRowKeepsZeroWeightChildContentSized() {
        composeRule.setContent {
            Box(Modifier.width(300.dp).testTag("weighted-row")) {
                UiNodeContent(
                    UiNode.Row(
                        listOf(
                            UiNode.Text("Fixed"),
                            UiNode.Image("/rest.png", "Rest"),
                        ),
                        listOf(0f, 1f),
                    ),
                    {},
                    { _, _ -> },
                    false,
                    loadImage = { ImageBitmap(1, 1) },
                )
            }
        }

        val row = composeRule.onNodeWithTag("weighted-row").fetchSemanticsNode().boundsInRoot
        val fixed = composeRule.onNodeWithText("Fixed").fetchSemanticsNode().boundsInRoot
        val rest =
            composeRule.onNodeWithContentDescription("Rest").fetchSemanticsNode().boundsInRoot
        assertTrue(fixed.width < rest.width)
        assertEquals(row.right, rest.right, 1f)
    }

    @Test
    fun weightedColumnUsesProportionalHeights() {
        val overflowing = UiNode.Column(List(100) { UiNode.Text("Line $it") })
        composeRule.setContent {
            Box(Modifier.height(300.dp)) {
                UiNodeContent(
                    UiNode.Column(
                        listOf(overflowing, overflowing),
                        listOf(2f, 1f),
                    ),
                    {},
                    { _, _ -> },
                    false,
                )
            }
        }

        val regions = composeRule.onAllNodes(hasScrollAction()).fetchSemanticsNodes()
        assertEquals(2, regions.size)
        val heights = regions.map { it.boundsInRoot.height }.sortedDescending()
        assertEquals(2f, heights[0] / heights[1], 0.05f)
    }

    @Test
    fun weightedColumnScrollsOutputWithoutMovingControls() {
        val output = UiNode.Column(List(100) { UiNode.Text("Output $it") })
        composeRule.setContent {
            Box(Modifier.height(300.dp)) {
                UiNodeContent(
                    UiNode.Column(
                        listOf(
                            UiNode.Text("Worktree"),
                            output,
                            UiNode.Input("Commands", UiEvent("[\"Run\"]")),
                        ),
                        listOf(0f, 1f, 0f),
                    ),
                    {},
                    { _, _ -> },
                    false,
                )
            }
        }

        composeRule.onNodeWithText("Worktree").assertIsDisplayed()
        composeRule.onNodeWithTag("input").assertIsDisplayed()
        composeRule.onNode(hasScrollAction()).performScrollToNode(hasText("Output 99"))
        composeRule.onNodeWithText("Output 99").assertIsDisplayed()
        composeRule.onNodeWithTag("input").assertIsDisplayed()
    }

    @Test
    fun rootSplitKeepsWorktreeInputVisibleWithOverflowingOutput() {
        val worktree =
            UiNode.Column(
                listOf(
                    UiNode.Text("Worktree"),
                    UiNode.Column(List(100) { UiNode.Text("Root output $it") }),
                    UiNode.Input("Commands", UiEvent("[\"Run\"]")),
                ),
                listOf(0f, 1f, 0f),
            )
        composeRule.setContent {
            Box(Modifier.width(600.dp).height(300.dp)) {
                UiNodeContent(
                    UiNode.Row(
                        listOf(
                            UiNode.Column(listOf(UiNode.Text("Agent: Claude"), worktree)),
                            UiNode.Column(listOf(UiNode.Text("Emulators"))),
                        ),
                        listOf(2f, 1f),
                    ),
                    {},
                    { _, _ -> },
                    false,
                )
            }
        }

        composeRule.onNodeWithText("Agent: Claude").assertIsDisplayed()
        composeRule.onNodeWithText("Emulators").assertIsDisplayed()
        composeRule.onNodeWithTag("input").assertIsDisplayed()
        assertEquals(1, composeRule.onAllNodes(hasScrollAction()).fetchSemanticsNodes().size)
    }

    @Test
    fun boundedContentSupportsPullToRefresh() {
        var refreshed = false
        composeRule.setContent {
            RefreshableColumn(
                isRefreshing = false,
                onRefresh = { refreshed = true },
                modifier = Modifier.fillMaxSize().testTag("refresh"),
            ) {
                Box(Modifier.weight(1f)) {
                    UiNodeContent(UiNode.Text("Content"), {}, { _, _ -> }, false)
                }
            }
        }

        composeRule.onNodeWithTag("refresh").performTouchInput { swipeDown() }
        composeRule.runOnIdle { assertTrue(refreshed) }
    }

    @Test
    fun refreshMenuInvokesRootRefreshAction() {
        var refreshed = false
        composeRule.setContent { RefreshMenu { refreshed = true } }

        composeRule.onNodeWithText("Refresh").performClick()

        composeRule.runOnIdle { assertTrue(refreshed) }
    }

    @Test
    fun weightedContentScrollsAndSupportsPullToRefreshAtStart() {
        var refreshed = false
        val output = UiNode.Column(List(100) { UiNode.Text("Refresh output $it") })
        composeRule.setContent {
            RefreshableColumn(
                isRefreshing = false,
                onRefresh = { refreshed = true },
                modifier = Modifier.fillMaxSize(),
            ) {
                Box(Modifier.weight(1f)) {
                    UiNodeContent(
                        UiNode.Column(
                            listOf(output, UiNode.Input("Commands", UiEvent("[\"Run\"]"))),
                            listOf(1f, 0f),
                        ),
                        {},
                        { _, _ -> },
                        false,
                    )
                }
            }
        }

        val outputScroll =
            composeRule.onNode(
                hasScrollAction() and
                    hasAnyDescendant(hasText("Refresh output 0")) and
                    hasAnyDescendant(hasText("Commands")).not()
            )
        outputScroll.performScrollToNode(hasText("Refresh output 99"))
        composeRule.onNodeWithText("Refresh output 99").assertIsDisplayed()
        outputScroll.performScrollToNode(hasText("Refresh output 0"))
        outputScroll.performTouchInput { swipeDown() }
        composeRule.runOnIdle { assertTrue(refreshed) }
        composeRule.onNodeWithTag("input").assertIsDisplayed()
    }

    @Test
    fun imageTapMapsSourcePixelsAndRejectsMargins() {
        fun check(size: IntSize, point: Offset, x: Int, y: Int) {
            val value = JSONObject(requireNotNull(imageTapValue(1080, 1920, size, point)))
            assertEquals(x, value.getInt("x"))
            assertEquals(y, value.getInt("y"))
            assertEquals(1080, value.getInt("width"))
            assertEquals(1920, value.getInt("height"))
        }
        check(IntSize(270, 480), Offset(135f, 240f), 540, 960)
        check(IntSize(400, 480), Offset(200f, 240f), 540, 960)
        check(IntSize(270, 600), Offset(135f, 300f), 540, 960)
        check(IntSize(270, 480), Offset.Zero, 0, 0)
        check(IntSize(270, 480), Offset(269.99f, 479.99f), 1079, 1919)
        for (point in listOf(Offset(-1f, 0f), Offset(270f, 0f), Offset(0f, 480f))) {
            assertEquals(null, imageTapValue(1080, 1920, IntSize(270, 480), point))
        }
        assertEquals(null, imageTapValue(1080, 1920, IntSize(400, 480), Offset(64f, 240f)))
        assertEquals(null, imageTapValue(1080, 1920, IntSize(270, 600), Offset(135f, 59f)))
        assertEquals(null, imageTapValue(1080, 1920, IntSize.Zero, Offset.Zero))
    }

    @Test
    fun imageTapUsesCurrentStateAndIgnoresOtherGestures() {
        val first = UiEvent("""["Emulator_msg",["Tap","emulator-5554","__VALUE__"]]""")
        val second = UiEvent("""["Emulator_msg",["Tap","emulator-5556","__VALUE__"]]""")
        var node by mutableStateOf(UiNode.Image("/first.png", "Pixel", first))
        var busy by mutableStateOf(false)
        val loaded = CompletableDeferred<ImageBitmap>()
        val events = mutableListOf<Pair<UiEvent, JSONObject>>()
        composeRule.setContent {
            Box(Modifier.width(300.dp).height(300.dp), propagateMinConstraints = true) {
                UiNodeContent(
                    node,
                    {},
                    { event, value -> events.add(event to JSONObject(value)) },
                    busy,
                    loadImage = { src ->
                        if (src == "/first.png") loaded.await() else ImageBitmap(200, 100)
                    },
                )
            }
        }
        composeRule.onNodeWithText("Loading: Pixel").performTouchInput { click() }
        assertTrue(events.isEmpty())
        composeRule.runOnIdle { loaded.complete(ImageBitmap(100, 200)) }
        val image = composeRule.onNodeWithTag("image")
        image.performTouchInput { click(center) }
        assertEquals(first, events.single().first)
        assertEquals(50, events.single().second.getInt("x"))
        assertEquals(100, events.single().second.getInt("y"))
        image.performTouchInput { click(Offset(0f, centerY)) }
        image.performTouchInput {
            down(center)
            moveTo(center + Offset(width / 4f, 0f))
            moveTo(center)
            up()
        }
        image.performTouchInput {
            down(center)
            cancel()
        }
        assertEquals(1, events.size)
        composeRule.runOnIdle { busy = true }
        image.performTouchInput { click() }
        assertEquals(1, events.size)
        composeRule.runOnIdle {
            busy = false
            node = node.copy(event = second)
        }
        image.performTouchInput { click() }
        assertEquals(second, events.last().first)
        assertEquals(2, events.size)
        composeRule.runOnIdle { node = node.copy(src = "/second.png") }
        image.performTouchInput { click() }
        assertEquals(3, events.size)
        assertEquals(200, events.last().second.getInt("width"))
        assertEquals(100, events.last().second.getInt("height"))
        assertEquals(100, events.last().second.getInt("x"))
        assertEquals(50, events.last().second.getInt("y"))
        composeRule.runOnIdle { node = node.copy(event = null) }
        image.performTouchInput { click() }
        assertEquals(3, events.size)
    }

    @Test
    fun imageRefreshesWithoutSubmittingAnEvent() {
        var requests = 0
        var events = 0
        composeRule.setContent {
            UiNodeContent(
                UiNode.Image("/emulators/emulator-5554/screenshot.png", "Pixel"),
                { events++ },
                { _, _ -> events++ },
                false,
                loadImage = {
                    requests++
                    ImageBitmap(1, 1)
                },
            )
        }

        composeRule.onNodeWithTag("image").fetchSemanticsNode()
        composeRule.waitUntil(4_000) { requests >= 2 }
        assertEquals(0, events)
    }

    @Test
    fun tapResponseKeepsTheExistingImagePollingSchedule() {
        var requests = 0
        var events = 0
        val event = UiEvent("[\"Tap\"]")
        var label by mutableStateOf("Before tap")
        var busy by mutableStateOf(false)
        composeRule.mainClock.autoAdvance = false
        composeRule.setContent {
            UiNodeContent(
                UiNode.Image("/preview.png", label, event),
                {},
                { _, _ ->
                    events++
                    busy = true
                },
                busy,
                loadImage = {
                    requests++
                    ImageBitmap(100, 200)
                },
            )
        }
        composeRule.mainClock.advanceTimeBy(100)
        val image = composeRule.onNodeWithTag("image")
        image.performTouchInput { click() }
        composeRule.mainClock.advanceTimeByFrame()
        assertEquals(1, events)
        assertEquals(1, requests)
        composeRule.runOnIdle {
            label = "After tap"
            busy = false
        }
        composeRule.mainClock.advanceTimeBy(100)
        composeRule.onNodeWithContentDescription("After tap").assertIsDisplayed()
        assertEquals(1, requests)
        composeRule.mainClock.advanceTimeBy(3_000)
        composeRule.waitForIdle()
        assertEquals(2, requests)
        assertEquals(1, events)
    }
}
