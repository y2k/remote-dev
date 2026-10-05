package io.y2k.remote_client

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import org.json.JSONObject

internal val LocalUiDocument = staticCompositionLocalOf<Any?> { null }

@Composable
private fun themeColor(role: ThemeColor?): Color {
    val colors = MaterialTheme.colorScheme
    return when (role) {
        null -> Color.Transparent
        ThemeColor.Background -> colors.background
        ThemeColor.Surface -> colors.surface
        ThemeColor.SurfaceContainer -> colors.surfaceContainer
        ThemeColor.Primary -> colors.primary
        ThemeColor.PrimaryContainer -> colors.primaryContainer
        ThemeColor.OutlineVariant -> colors.outlineVariant
    }
}

@Composable
private fun Modifier.containerDecoration(role: ThemeColor?, border: UiBorder?, radius: Int): Modifier {
    val shape = if (radius > 0) RoundedCornerShape(radius.dp) else RectangleShape
    return (if (radius > 0) clip(shape) else this)
        .then(if (border != null && border.width > 0) Modifier.border(border.width.dp, themeColor(border.color), shape) else Modifier)
        .then(if (role != null) Modifier.background(themeColor(role), shape) else Modifier)
}

private class GapDrawing(val count: Int, val horizontal: Boolean, val rtl: Boolean) {
    private var coordinates: LayoutCoordinates? = null
    private val bounds = mutableStateMapOf<Int, Rect>()

    fun child(index: Int): Modifier = Modifier.onPlaced { child ->
        coordinates?.takeIf { it.isAttached }?.let { parent ->
            // Bounding boxes collapse to Rect.Zero for zero-sized children; their
            // position still defines the adjacent gap in a constrained layout.
            bounds[index] = Rect(parent.localPositionOf(child, Offset.Zero),
                Size(child.size.width.toFloat(), child.size.height.toFloat()))
        }
    }.layout { measurable, constraints ->
        val child = measurable.measure(constraints)
        // Observe the allocated slot, even if a control's minimum touch target
        // measures larger than the remaining space and overflows that slot.
        layout(child.width, child.height) { child.placeRelative(0, 0) }
    }

    fun modifier(color: Color): Modifier = Modifier.onPlaced { coordinates = it }.drawBehind {
        for (index in 0 until count - 1) {
            val a = bounds[index] ?: continue
            val b = bounds[index + 1] ?: continue
            val limit = if (horizontal) size.width else size.height
            val start = (if (!horizontal) a.bottom else if (rtl) b.right else a.right).coerceIn(0f, limit)
            val end = (if (!horizontal) b.top else if (rtl) a.left else b.left).coerceIn(0f, limit)
            if (end > start) {
                drawRect(color,
                    topLeft = if (horizontal) Offset(start, 0f) else Offset(0f, start),
                    size = if (horizontal) Size(end - start, size.height) else Size(size.width, end - start))
            }
        }
    }
}

@Composable
private fun rememberGapDrawing(node: UiNode, gap: UiGap, count: Int, horizontal: Boolean): GapDrawing? {
    if (gap.color == null || gap.size == 0 || count < 2) return null
    val direction = LocalLayoutDirection.current
    return remember(node, direction, LocalUiDocument.current) {
        GapDrawing(count, horizontal, direction == LayoutDirection.Rtl)
    }
}

@Composable
fun UiNodeContent(
    node: UiNode,
    onButtonEvent: (UiEvent) -> Unit,
    onInputEvent: (UiEvent, String) -> Unit,
    eventInProgress: Boolean,
    loadImage: suspend (String) -> ImageBitmap = { error("No image loader") },
    modifier: Modifier = Modifier,
) {
    when (node) {
        is UiNode.Column -> {
            val gaps = rememberGapDrawing(node, node.gap, node.children.size, horizontal = false)
            Column(
                modifier =
                    (if (node.weights == null) modifier else modifier.fillMaxHeight()).then(
                        if (node.stretch) Modifier.fillMaxWidth() else Modifier
                    ).containerDecoration(node.background, node.border, node.cornerRadius).padding(
                        node.padding.start.dp, node.padding.top.dp, node.padding.end.dp, node.padding.bottom.dp,
                    ).then(gaps?.modifier(themeColor(node.gap.color)) ?: Modifier),
                verticalArrangement = Arrangement.spacedBy(node.gap.size.dp),
            ) {
                node.children.forEachIndexed { index, child ->
                    val weight = node.weights?.get(index) ?: 0f
                    if (weight == 0f && !node.stretch) {
                        UiNodeContent(
                            child,
                            onButtonEvent,
                            onInputEvent,
                            eventInProgress,
                            loadImage,
                            modifier = gaps?.child(index) ?: Modifier,
                        )
                    } else {
                        val childModifier = gaps?.child(index) ?: Modifier
                        val modifier =
                            if (weight > 0f) {
                                childModifier.weight(weight).verticalScroll(rememberScrollState())
                            } else {
                                childModifier
                            }
                        Box(
                            modifier =
                                modifier.then(
                                    if (node.stretch) Modifier.fillMaxWidth() else Modifier
                                ),
                            propagateMinConstraints = node.stretch,
                        ) {
                            UiNodeContent(
                                child,
                                onButtonEvent,
                                onInputEvent,
                                eventInProgress,
                                loadImage,
                            )
                        }
                    }
                }
            }
        }
        is UiNode.Row -> {
            val gaps = rememberGapDrawing(node, node.gap, node.children.size, horizontal = true)
            Row(
                modifier = (if (node.weights == null) modifier else modifier.fillMaxWidth())
                    .then(if (node.horizontalScroll) Modifier.horizontalScroll(rememberScrollState()) else Modifier)
                    .containerDecoration(node.background, node.border, node.cornerRadius).padding(
                        node.padding.start.dp, node.padding.top.dp, node.padding.end.dp, node.padding.bottom.dp,
                    ).then(gaps?.modifier(themeColor(node.gap.color)) ?: Modifier),
                horizontalArrangement = Arrangement.spacedBy(node.gap.size.dp),
            ) {
                if (node.weights == null) {
                    node.children.forEachIndexed { index, child ->
                        UiNodeContent(child, onButtonEvent, onInputEvent, eventInProgress, loadImage,
                            modifier = gaps?.child(index) ?: Modifier)
                    }
                } else {
                    node.children.zip(node.weights).forEachIndexed { index, (child, weight) ->
                        if (weight == 0f) {
                            UiNodeContent(
                                child,
                                onButtonEvent,
                                onInputEvent,
                                eventInProgress,
                                loadImage,
                                modifier = gaps?.child(index) ?: Modifier,
                            )
                        } else {
                            Box((gaps?.child(index) ?: Modifier).weight(weight), propagateMinConstraints = true) {
                                UiNodeContent(
                                    child,
                                    onButtonEvent,
                                    onInputEvent,
                                    eventInProgress,
                                    loadImage,
                                )
                            }
                        }
                    }
                }
            }
        }
        is UiNode.Text ->
            Text(
                modifier = modifier,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
                text = node.text,
            )
        is UiNode.Button ->
            Button(
                modifier = modifier,
                enabled = !eventInProgress,
                onClick = { node.event?.let(onButtonEvent) },
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(text = node.label)
            }
        is UiNode.Input -> {
            var value by remember(node, LocalUiDocument.current) { mutableStateOf(node.text) }
            TextField(
                value = value,
                onValueChange = { value = it },
                label = { Text(node.label) },
                singleLine = true,
                enabled = !eventInProgress,
                shape = RoundedCornerShape(16.dp),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                    disabledContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    disabledIndicatorColor = Color.Transparent,
                ),
                trailingIcon = {
                    FilledIconButton(
                        onClick = { if (!eventInProgress) onInputEvent(node.event, value) },
                        enabled = !eventInProgress,
                        modifier = Modifier.size(48.dp),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Icon(
                            painterResource(R.drawable.ic_arrow_up),
                            contentDescription = "Submit ${node.label}",
                        )
                    }
                },
                modifier =
                    modifier.testTag("input").onPreviewKeyEvent {
                        if (it.type == KeyEventType.KeyUp && it.key == Key.Enter) {
                            if (!eventInProgress) onInputEvent(node.event, value)
                            true
                        } else {
                            false
                        }
                    },
            )
        }
        is UiNode.Image -> ImageContent(node, loadImage, onInputEvent, eventInProgress, modifier)
        is UiNode.VoiceInput -> key(node, LocalUiDocument.current) {
            VoiceInputButton(enabled = !eventInProgress, onResult = { onInputEvent(node.event, it) }, modifier = modifier)
        }
    }
}

@Composable
private fun ImageContent(
    node: UiNode.Image,
    loadImage: suspend (String) -> ImageBitmap,
    onInputEvent: (UiEvent, String) -> Unit,
    eventInProgress: Boolean,
    modifier: Modifier,
) {
    var bitmap by remember(node.src) { mutableStateOf<ImageBitmap?>(null) }
    var error by remember(node.src) { mutableStateOf(false) }
    val submit by rememberUpdatedState(onInputEvent)

    LaunchedEffect(node.src) {
        while (true) {
            try {
                bitmap = loadImage(node.src)
                error = false
            } catch (exception: Exception) {
                if (exception is CancellationException) throw exception
                error = true
            }
            delay(3_000)
        }
    }

    when {
        bitmap != null ->
            Image(
                bitmap = requireNotNull(bitmap),
                contentDescription = node.label,
                contentScale = ContentScale.Fit,
                modifier =
                    modifier.fillMaxWidth().testTag("image").pointerInput(
                        node.event,
                        bitmap,
                        eventInProgress,
                    ) {
                        val event = node.event ?: return@pointerInput
                        val image = bitmap ?: return@pointerInput
                        if (eventInProgress) return@pointerInput
                        awaitEachGesture {
                            val down = awaitFirstDown()
                            if (
                                imageTapValue(image.width, image.height, size, down.position) ==
                                    null
                            )
                                return@awaitEachGesture
                            down.consume()
                            do {
                                val change =
                                    awaitPointerEvent().changes.singleOrNull()
                                        ?: return@awaitEachGesture
                                if (
                                    change.id != down.id ||
                                        change.isConsumed ||
                                        (change.position - down.position).getDistance() >
                                            viewConfiguration.touchSlop
                                )
                                    return@awaitEachGesture
                                if (!change.pressed) {
                                    change.consume()
                                    imageTapValue(image.width, image.height, size, change.position)
                                        ?.let {
                                            submit(event, it)
                                        }
                                    return@awaitEachGesture
                                }
                            } while (
                                awaitPointerEvent(PointerEventPass.Final).changes.none {
                                    it.isConsumed
                                }
                            )
                        }
                    },
            )
        error -> Text("Error: ${node.label}", modifier)
        else -> Text("Loading: ${node.label}", modifier)
    }
}

internal fun imageTapValue(width: Int, height: Int, size: IntSize, point: Offset): String? {
    if (size.width <= 0 || size.height <= 0) return null
    // ponytail: coordinates describe the displayed frame; add frame/rotation validation if input
    // must remain accurate while the emulator changes orientation between screenshots.
    val scale = minOf(size.width.toFloat() / width, size.height.toFloat() / height)
    val x = (point.x - (size.width - width * scale) / 2) / scale
    val y = (point.y - (size.height - height * scale) / 2) / scale
    if (x < 0 || y < 0 || x >= width || y >= height) return null
    return JSONObject()
        .put("x", x.toInt().coerceAtMost(width - 1))
        .put("y", y.toInt().coerceAtMost(height - 1))
        .put("width", width)
        .put("height", height)
        .toString()
}
