package io.y2k.remote_client

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay

@Composable
fun UiNodeContent(
    node: UiNode,
    onButtonEvent: (UiEvent) -> Unit,
    onInputEvent: (UiEvent, String) -> Unit,
    eventInProgress: Boolean,
    loadImage: suspend (String) -> ImageBitmap = { error("No image loader") },
) {
    when (node) {
        is UiNode.Column ->
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                node.children.forEach {
                    UiNodeContent(it, onButtonEvent, onInputEvent, eventInProgress, loadImage)
                }
            }
        is UiNode.Row ->
            Row(
                modifier = if (node.weights == null) Modifier else Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (node.weights == null) {
                    node.children.forEach {
                        UiNodeContent(it, onButtonEvent, onInputEvent, eventInProgress, loadImage)
                    }
                } else {
                    node.children.zip(node.weights).forEach { (child, weight) ->
                        Box(Modifier.weight(weight)) {
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
        is UiNode.Text ->
            Text(
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.primary,
                text = node.text,
            )
        is UiNode.Button ->
            Button(
                enabled = !eventInProgress,
                onClick = { node.event?.let(onButtonEvent) },
            ) {
                Text(text = node.label)
            }
        is UiNode.Input -> {
            var value by remember(node) { mutableStateOf(node.text) }
            TextField(
                value = value,
                onValueChange = { value = it },
                label = { Text(node.label) },
                singleLine = true,
                enabled = !eventInProgress,
                modifier =
                    Modifier.testTag("input").onPreviewKeyEvent {
                        if (it.type == KeyEventType.KeyUp && it.key == Key.Enter) {
                            if (!eventInProgress) onInputEvent(node.event, value)
                            true
                        } else {
                            false
                        }
                    },
            )
        }
        is UiNode.Image -> ImageContent(node, loadImage)
    }
}

@Composable
private fun ImageContent(node: UiNode.Image, loadImage: suspend (String) -> ImageBitmap) {
    var bitmap by remember(node.src) { mutableStateOf<ImageBitmap?>(null) }
    var error by remember(node.src) { mutableStateOf(false) }

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
                modifier = Modifier.fillMaxWidth().testTag("image"),
            )
        error -> Text("Error: ${node.label}")
        else -> Text("Loading: ${node.label}")
    }
}
