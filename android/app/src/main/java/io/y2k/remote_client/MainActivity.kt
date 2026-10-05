package io.y2k.remote_client

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.rememberScrollableState
import androidx.compose.foundation.gestures.scrollable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.android.Android
import io.ktor.client.request.get
import io.ktor.client.request.prepareGet
import io.ktor.client.request.preparePost
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsChannel
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.utils.io.readLine
import io.y2k.remote_client.ui.theme.MyApplicationTheme
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

enum class ThemeColor(val wireName: String) {
    Background("background"),
    Surface("surface"),
    SurfaceContainer("surfaceContainer"),
    Primary("primary"),
    PrimaryContainer("primaryContainer"),
    OutlineVariant("outlineVariant"),
}

data class UiPadding(val start: Int = 0, val top: Int = 0, val end: Int = 0, val bottom: Int = 0)

data class UiGap(val size: Int = 4, val color: ThemeColor? = null)

data class UiBorder(val width: Int, val color: ThemeColor)

sealed interface UiNode {
    data class Column(
        val children: List<UiNode>,
        val weights: List<Float>? = null,
        val stretch: Boolean = false,
        val background: ThemeColor? = null,
        val padding: UiPadding = UiPadding(),
        val gap: UiGap = UiGap(),
        val border: UiBorder? = null,
        val cornerRadius: Int = 0,
    ) : UiNode

    data class Row(
        val children: List<UiNode>,
        val weights: List<Float>? = null,
        val background: ThemeColor? = null,
        val padding: UiPadding = UiPadding(),
        val gap: UiGap = UiGap(),
        val border: UiBorder? = null,
        val cornerRadius: Int = 0,
        val horizontalScroll: Boolean = false,
    ) : UiNode

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

    data class VoiceInput(val event: UiEvent) : UiNode

    data class Image(
        val src: String,
        val label: String,
        val event: UiEvent? = null,
    ) : UiNode
}

data class UiEvent(val json: String)

internal val refreshEvent = UiEvent("""["Refresh"]""")

fun parseUiNode(json: String): UiNode = parseUiNode(JSONObject(json))

private fun JSONObject.spacingSize(key: String): Int {
    val value = opt(key)
    require((value is Int || value is Long) && (value as Number).toLong() in 0..Int.MAX_VALUE.toLong()) {
        "$key must be an integer in 0..2147483647"
    }
    return (value as Number).toInt()
}

private fun JSONObject.themeColor(key: String): ThemeColor? =
    if (!has(key)) null else ThemeColor.entries.firstOrNull { it.wireName == opt(key) }
        ?: throw IllegalArgumentException("$key must be a supported theme role")

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
            val weights =
                if (node.has("weights")) {
                    val values =
                        node.get("weights") as? JSONArray
                            ?: throw IllegalArgumentException("$type weights must be an array")
                    if (values.length() != parsedChildren.size) {
                        throw IllegalArgumentException("$type weights must match children")
                    }
                    List(values.length()) { index ->
                        val weight =
                            (values.get(index) as? Number)?.toFloat()
                                ?: throw IllegalArgumentException("$type weight must be a number")
                        if (!weight.isFinite() || weight < 0f) {
                            throw IllegalArgumentException("$type weight must be non-negative")
                        }
                        weight
                    }
                } else {
                    null
                }
            val background = node.themeColor("background")
            val padding = if (node.has("padding")) {
                val p = node.opt("padding") as? JSONObject
                    ?: throw IllegalArgumentException("padding must be an object")
                UiPadding(p.spacingSize("start"), p.spacingSize("top"), p.spacingSize("end"), p.spacingSize("bottom"))
            } else UiPadding()
            val gap = if (node.has("gap")) {
                val g = node.opt("gap") as? JSONObject
                    ?: throw IllegalArgumentException("gap must be an object")
                UiGap(g.spacingSize("size"), g.themeColor("color"))
            } else UiGap()
            val border = if (node.has("border")) {
                val b = node.opt("border") as? JSONObject
                    ?: throw IllegalArgumentException("border must be an object")
                UiBorder(b.spacingSize("width"), requireNotNull(b.themeColor("color")) { "border color is required" })
            } else null
            val cornerRadius = if (node.has("cornerRadius")) node.spacingSize("cornerRadius") else 0
            if (type == "column") {
                val stretch =
                    if (node.has("stretch")) {
                        node.get("stretch") as? Boolean
                            ?: throw IllegalArgumentException("column stretch must be a boolean")
                    } else {
                        false
                    }
                UiNode.Column(parsedChildren, weights, stretch, background, padding, gap, border, cornerRadius)
            } else {
                val horizontalScroll = if (node.has("horizontalScroll")) {
                    node.get("horizontalScroll") as? Boolean
                        ?: throw IllegalArgumentException("row horizontalScroll must be a boolean")
                } else false
                require(!horizontalScroll || weights == null) { "A horizontally scrolling row cannot have weights" }
                UiNode.Row(parsedChildren, weights, background, padding, gap, border, cornerRadius, horizontalScroll)
            }
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
        "voice_input" -> {
            require(!node.has("label") && !node.has("text")) {
                "Voice input cannot have label or text"
            }
            UiNode.VoiceInput(parseEvent(node, "Voice input"))
        }
        "image" -> {
            val src =
                node.get("src") as? String
                    ?: throw IllegalArgumentException("Image src must be a string")
            if (!src.startsWith("/") || src.startsWith("//")) {
                throw IllegalArgumentException("Image src must be backend-relative")
            }
            UiNode.Image(
                src,
                node.get("label") as? String
                    ?: throw IllegalArgumentException("Image label must be a string"),
                if (node.has("event")) parseEvent(node, "Image") else null,
            )
        }
        else -> throw IllegalArgumentException("Unsupported node type: $type")
    }
}

private fun parseEvent(node: JSONObject, nodeName: String): UiEvent {
    val value =
        node.get("event") as? JSONArray
            ?: throw IllegalArgumentException("$nodeName event must be an array")
    return UiEvent(value.toString())
}

fun eventRequest(event: UiEvent, value: String?): String =
    JSONObject()
        .put("event", JSONArray(event.json))
        .put("value", value ?: JSONObject.NULL)
        .toString()

fun decodePng(bytes: ByteArray): ImageBitmap =
    (BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalArgumentException("Unable to decode image"))
        .asImageBitmap()

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
    val backEvent = UiEvent("""["Back"]""")

    fun sendRequest(refreshing: Boolean = false, request: suspend () -> Unit) {
        if (eventInProgress) return
        scope.launch {
            eventInProgress = true
            eventError = null
            val previous = state
            if (previous !is ScreenState.Content) state = ScreenState.Loading
            try {
                request()
            } catch (error: Exception) {
                error.printStackTrace() // FIXME:
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

    suspend fun renderResponse(response: io.ktor.client.statement.HttpResponse) {
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

    suspend fun loadImage(src: String): ImageBitmap =
        decodePng(client.get(BuildConfig.BACKEND_URL.removeSuffix("/") + src).body())

    fun sendEvent(event: UiEvent, value: String?, refreshing: Boolean = false) {
        sendRequest(refreshing) {
            client
                .preparePost(BuildConfig.BACKEND_URL) {
                    contentType(io.ktor.http.ContentType.Application.Json)
                    setBody(eventRequest(event, value))
                }
                .execute(::renderResponse)
        }
    }

    fun loadInitial() {
        sendRequest {
            client.prepareGet(BuildConfig.BACKEND_URL).execute(::renderResponse)
        }
    }

    BackHandler(enabled = state is ScreenState.Content) {
        if (!eventInProgress) sendEvent(backEvent, null)
    }

    LaunchedEffect(allowed) {
        if (allowed) loadInitial()
    }

    fun refresh() {
        if (allowed) {
            if (!eventInProgress) {
                isRefreshing = true
                sendEvent(refreshEvent, null, refreshing = true)
            }
        } else {
            requestPermission.launch(Manifest.permission.ACCESS_LOCAL_NETWORK)
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        contentWindowInsets = WindowInsets.safeDrawing,
        topBar = {
            TopAppBar(
                title = { Text("remote_dev") },
                actions = { RefreshMenu(::refresh) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        RefreshableColumn(
            modifier =
                Modifier.fillMaxSize()
                    .padding(horizontal = 12.dp)
                    .padding(innerPadding)
                    .consumeWindowInsets(innerPadding)
                    .background(MaterialTheme.colorScheme.background),
            isRefreshing = isRefreshing,
            onRefresh = ::refresh,
        ) {
            if (!allowed) {
                Text("Error: Local network permission required")
            } else {
                when (val current = state) {
                    ScreenState.Loading -> Text("Loading...")
                    is ScreenState.Content -> {
                        if (eventInProgress) Text("Loading...")
                        Box(Modifier.weight(1f)) {
                            CompositionLocalProvider(LocalUiDocument provides current) {
                                UiNodeContent(
                                    node = current.node,
                                    onButtonEvent = { event -> sendEvent(event, null) },
                                    onInputEvent = { event, value -> sendEvent(event, value) },
                                    eventInProgress = eventInProgress,
                                    loadImage = ::loadImage,
                                )
                            }
                        }
                        eventError?.let { Text("Error: $it") }
                    }
                    is ScreenState.Error -> Text("Error: ${current.message}")
                }
            }
        }
    }
}

@Composable
internal fun RefreshMenu(onRefresh: () -> Unit) {
    TextButton(onClick = onRefresh) { Text("Refresh") }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun RefreshableColumn(
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    PullToRefreshBox(isRefreshing = isRefreshing, onRefresh = onRefresh, modifier = modifier) {
        Column(
            modifier =
                Modifier.fillMaxSize()
                    .scrollable(rememberScrollableState { 0f }, Orientation.Vertical),
            content = content,
        )
    }
}

private sealed interface ScreenState {
    data object Loading : ScreenState

    class Content(val node: UiNode) : ScreenState

    data class Error(val message: String) : ScreenState
}
