package io.y2k.remote_client

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

@Composable
fun UiNodeContent(
    node: UiNode,
    onButtonEvent: (UiEvent) -> Unit,
    onInputEvent: (UiEvent, String) -> Unit,
    eventInProgress: Boolean,
) {
    when (node) {
        is UiNode.Column ->
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                node.children.forEach {
                    UiNodeContent(it, onButtonEvent, onInputEvent, eventInProgress)
                }
            }
        is UiNode.Row ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                node.children.forEach {
                    UiNodeContent(it, onButtonEvent, onInputEvent, eventInProgress)
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
    }
}
