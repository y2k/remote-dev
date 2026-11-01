package io.y2k.remote_client

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.IntSize

@Composable
internal fun TabStripContent(
    node: UiNode.TabStrip,
    onEvent: (UiEvent) -> Unit,
    eventInProgress: Boolean,
    modifier: Modifier = Modifier,
) {
    val colors = MaterialTheme.colorScheme
    var viewport by remember { mutableStateOf(IntSize.Zero) }
    Row(
        modifier.fillMaxWidth().background(colors.surfaceContainerLow).drawWithContent {
            drawContent()
            drawRect(colors.outlineVariant, Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
        }.padding(horizontal = 12.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            Modifier.weight(1f).onSizeChanged { viewport = it }
                .horizontalScroll(rememberScrollState()).selectableGroup(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            node.tabs.forEach { tab ->
                key(tab.id) {
                    val requester = remember { BringIntoViewRequester() }
                    var measured by remember { mutableStateOf(IntSize.Zero) }
                    LaunchedEffect(tab.selected, measured, viewport) {
                        if (tab.selected && measured.width > 0 && viewport.width > 0) {
                            requester.bringIntoView(Rect(0f, 0f,
                                minOf(measured.width, viewport.width).toFloat(), measured.height.toFloat()))
                        }
                    }
                    Row(
                        Modifier.bringIntoViewRequester(requester).onSizeChanged { measured = it }
                            .background(if (tab.selected) colors.surface else Color.Transparent)
                            .drawWithContent {
                                drawContent()
                                if (tab.selected) drawRect(colors.primary, size = Size(size.width, 2.dp.toPx()))
                            },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            Modifier.selectable(tab.selected, enabled = !eventInProgress, role = Role.Tab,
                                onClick = { onEvent(tab.selectEvent) })
                                .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
                                .padding(horizontal = 12.dp, vertical = 4.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(tab.label, style = MaterialTheme.typography.labelLarge,
                                modifier = Modifier.width(IntrinsicSize.Max),
                                color = if (tab.selected) colors.primary else colors.onSurfaceVariant,
                                maxLines = 1)
                        }
                        IconButton(onClick = { onEvent(tab.closeEvent) }, enabled = !eventInProgress,
                            modifier = Modifier.size(48.dp)) {
                            Icon(painterResource(R.drawable.ic_close), "Close ${tab.label}",
                                Modifier.size(16.dp), tint = colors.onSurfaceVariant)
                        }
                    }
                }
            }
        }
        IconButton(onClick = { onEvent(node.addEvent) }, enabled = !eventInProgress,
            modifier = Modifier.size(48.dp).clip(RoundedCornerShape(8.dp))) {
            Icon(painterResource(R.drawable.ic_add), "Add tab", Modifier.size(20.dp), tint = colors.onSurfaceVariant)
        }
    }
}
