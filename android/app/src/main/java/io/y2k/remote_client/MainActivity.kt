package io.y2k.remote_client

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import io.ktor.client.HttpClient
import io.ktor.client.engine.android.Android
import io.ktor.client.request.preparePost
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsChannel
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.y2k.remote_client.ui.theme.MyApplicationTheme
import io.ktor.utils.io.readLine
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

sealed interface UiNode {
    data class Column(val children: List<UiNode>) : UiNode

    data class Row(val children: List<UiNode>) : UiNode

    data class Text(val text: String) : UiNode

    data class Button(
        val label: String,
        val event: UiEvent? = null,
    ) : UiNode

    // ponytail: an input submits only its own value; add form data when an event needs multiple
    // fields.
    data class Input(
        val label: String,
        val event: UiEvent,
        val text: String = "",
    ) : UiNode
}

data class UiEvent(val json: String)

fun parseUiNode(json: String): UiNode = parseUiNode(JSONObject(json))

private fun parseUiNode(node: JSONObject): UiNode {
    val type = node.get("@type") as? String ?: throw IllegalArgumentException("Missing @type")
    return when (type) {
        "column",
        "row" -> {
            val children =
                node.get("children") as? JSONArray
                    ?: throw IllegalArgumentException("$type children must be an array")
            val parsedChildren =
                List(children.length()) { index ->
                    val child =
                        children.get(index) as? JSONObject
                            ?: throw IllegalArgumentException("$type child must be an object")
                    parseUiNode(child)
                }
            if (type == "column") UiNode.Column(parsedChildren) else UiNode.Row(parsedChildren)
        }
        "text" ->
            UiNode.Text(
                node.get("text") as? String
                    ?: throw IllegalArgumentException("Text must be a string")
            )
        "button" -> {
            val event =
                if (node.has("event")) {
                    parseEvent(node, "Button")
                } else {
                    null
                }
            UiNode.Button(
                node.get("label") as? String
                    ?: throw IllegalArgumentException("Button label must be a string"),
                event,
            )
        }
        "input" ->
            UiNode.Input(
                node.get("label") as? String
                    ?: throw IllegalArgumentException("Input label must be a string"),
                parseEvent(node, "Input"),
                if (node.has("text")) {
                    node.get("text") as? String
                        ?: throw IllegalArgumentException("Input text must be a string")
                } else {
                    ""
                },
            )
        else -> throw IllegalArgumentException("Unsupported node type: $type")
    }
}

private fun parseEvent(node: JSONObject, nodeName: String): UiEvent {
    val value =
        node.get("event") as? JSONObject
            ?: throw IllegalArgumentException("$nodeName event must be an object")
    return UiEvent(value.toString())
}

fun eventRequest(event: UiEvent, value: String?): String =
    JSONObject().put("event", JSONObject(event.json)).put("value", value ?: JSONObject.NULL).toString()

class MainActivity : ComponentActivity() {
    private val client = HttpClient(Android)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                App(client)
            }
        }
    }

    override fun onDestroy() {
        client.close()
        super.onDestroy()
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun App(client: HttpClient) {
    val context = LocalContext.current
    var allowed by remember {
        mutableStateOf(
            Build.VERSION.SDK_INT < 37 ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_LOCAL_NETWORK,
                ) == PackageManager.PERMISSION_GRANTED
        )
    }
    val requestPermission =
        rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
            allowed = it
        }

    LaunchedEffect(Unit) {
        if (!allowed) requestPermission.launch(Manifest.permission.ACCESS_LOCAL_NETWORK)
    }

    var state by remember { mutableStateOf<ScreenState>(ScreenState.Loading) }
    var isRefreshing by remember { mutableStateOf(false) }
    var eventInProgress by remember { mutableStateOf(false) }
    var eventError by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val loadEvent = UiEvent("""{"type":"load"}""")
    val backEvent = UiEvent("""{"type":"back"}""")

    fun sendEvent(event: UiEvent, value: String?, refreshing: Boolean = false) {
        if (eventInProgress) return
        scope.launch {
            eventInProgress = true
            eventError = null
            val previous = state
            if (previous !is ScreenState.Content) state = ScreenState.Loading
            try {
                client
                    .preparePost(BuildConfig.BACKEND_URL) {
                        contentType(io.ktor.http.ContentType.Application.Json)
                        setBody(eventRequest(event, value))
                    }.execute { response ->
                    if (response.headers[HttpHeaders.ContentType]?.startsWith("application/x-ndjson") == true) {
                        val body = response.bodyAsChannel()
                        while (true) {
                            val line = body.readLine() ?: break
                            if (line.isNotEmpty()) {
                                state = ScreenState.Content(parseUiNode(line))
                                withFrameNanos {}
                            }
                        }
                    } else {
                        state = ScreenState.Content(parseUiNode(response.bodyAsText()))
                    }
                }
            } catch (error: Exception) {
                if (previous is ScreenState.Content) {
                    state = previous
                    eventError = error.message ?: "Unable to submit event"
                } else {
                    state = ScreenState.Error(error.message ?: "Unable to load UI")
                }
            } finally {
                eventInProgress = false
                if (refreshing) isRefreshing = false
            }
        }
    }

    BackHandler(enabled = state is ScreenState.Content) {
        if (!eventInProgress) sendEvent(backEvent, null)
    }

    LaunchedEffect(allowed) {
        if (allowed) sendEvent(loadEvent, null)
    }

    fun refresh() {
        if (allowed) {
            if (!eventInProgress) {
                isRefreshing = true
                sendEvent(loadEvent, null, refreshing = true)
            }
        } else {
            requestPermission.launch(Manifest.permission.ACCESS_LOCAL_NETWORK)
        }
    }

    Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
        PullToRefreshBox(
            modifier =
                Modifier.fillMaxSize()
                    .padding(horizontal = 4.dp)
                    .padding(innerPadding)
                    .background(MaterialTheme.colorScheme.background),
            isRefreshing = isRefreshing,
            onRefresh = ::refresh,
        ) {
            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                if (!allowed) {
                    Text("Error: Local network permission required")
                } else {
                    when (val current = state) {
                        ScreenState.Loading -> Text("Loading...")
                        is ScreenState.Content -> {
                            if (eventInProgress) Text("Loading...")
                            UiNodeContent(
                                node = current.node,
                                onButtonEvent = { event -> sendEvent(event, null) },
                                onInputEvent = { event, value -> sendEvent(event, value) },
                                eventInProgress = eventInProgress,
                            )
                            eventError?.let { Text("Error: $it") }
                        }
                        is ScreenState.Error -> Text("Error: ${current.message}")
                    }
                }
            }
        }
    }
}

private sealed interface ScreenState {
    data object Loading : ScreenState

    data class Content(val node: UiNode) : ScreenState

    data class Error(val message: String) : ScreenState
}
