package io.y2k.remote_client

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.MotionEvent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PlainTooltip
import androidx.compose.material3.Text
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipAnchorPosition
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.findViewTreeLifecycleOwner
import kotlinx.coroutines.withTimeoutOrNull

internal class VoiceRecording(
    private val onResult: (String) -> Unit,
    private val stop: () -> Unit,
    private val dispose: () -> Unit,
) {
    var active by mutableStateOf(true)
        private set
    var listening by mutableStateOf(true)
        private set
    var holding by mutableStateOf(true)
        private set
    private var text: String? = null

    fun endOfSpeech() { listening = false }

    fun result(value: String?) {
        if (!active || text != null) return
        listening = false
        if (value.isNullOrBlank()) { cancel(); return }
        text = value
        submitIfReleased()
    }

    fun release() {
        if (!active || !holding) return
        holding = false
        val wasListening = listening
        listening = false
        if (wasListening) stop()
        submitIfReleased()
    }

    private fun submitIfReleased() {
        val value = text ?: return
        if (!active || holding) return
        cancel()
        onResult(value)
    }

    fun cancel() {
        if (!active) return
        active = false
        listening = false
        text = null
        dispose()
    }
}

@OptIn(ExperimentalComposeUiApi::class, ExperimentalMaterial3Api::class)
@Composable
fun VoiceInputButton(enabled: Boolean, onResult: (String) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val lifecycle = checkNotNull(LocalView.current.findViewTreeLifecycleOwner()).lifecycle
    val available = remember(context) { SpeechRecognizer.isRecognitionAvailable(context) }
    val submit by rememberUpdatedState(onResult)
    val currentlyEnabled by rememberUpdatedState(enabled)
    var recording by remember { mutableStateOf<VoiceRecording?>(null) }
    var error by remember { mutableStateOf<Pair<String, Any>?>(null) }
    val tooltip = rememberTooltipState(isPersistent = true)
    fun showError(message: String) {
        error = message to Any() // Repeated messages restart the display time.
    }
    LaunchedEffect(error) {
        if (error != null) {
            try {
                withTimeoutOrNull(2_000) { tooltip.show() }
            } finally {
                tooltip.dismiss()
            }
        }
    }
    var resumed by remember { mutableStateOf(lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        if (!it) showError("Microphone permission required")
        // A new press is required after the permission dialog closes.
    }

    DisposableEffect(lifecycle, enabled) {
        if (!enabled) recording?.cancel()
        val observer = LifecycleEventObserver { _, _ ->
            resumed = lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
            if (!resumed) recording?.cancel()
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            recording?.cancel()
        }
    }

    fun start() {
        if (!currentlyEnabled || !resumed || !available || recording?.active == true) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permission.launch(Manifest.permission.RECORD_AUDIO)
            return
        }
        error = null
        try {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
            val session = VoiceRecording(
                onResult = { if (currentlyEnabled && resumed) submit(it) },
                stop = { recognizer.stopListening() },
                dispose = { recognizer.cancel(); recognizer.destroy() },
            )
            recording = session
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() { if (session.active) session.endOfSpeech() }
                override fun onPartialResults(partialResults: Bundle?) = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit
                override fun onResults(results: Bundle?) {
                    session.result(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull())
                }
                override fun onError(code: Int) {
                    if (!session.active) return
                    session.cancel()
                    showError("Voice input error ($code)")
                }
            })
            // ponytail: the service may finish on a pause; use continuous capture if speech
            // across long pauses must be recorded until release.
            recognizer.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ru-RU"))
        } catch (failure: Exception) {
            recording?.cancel()
            showError(failure.message ?: "Unable to start voice input")
        }
    }

    val active = recording?.active == true
    val listening = active && recording?.listening == true
    val usable = enabled && available && resumed
    val description = when {
        !available -> "Speech recognition unavailable"
        active && recording?.holding == true -> "Release to finish"
        active -> "Recognizing speech"
        else -> "Hold to speak"
    }
    val colors = MaterialTheme.colorScheme
    TooltipBox(
        modifier = modifier,
        positionProvider = TooltipDefaults.rememberTooltipPositionProvider(TooltipAnchorPosition.Above),
        tooltip = { error?.let { PlainTooltip { Text(it.first) } } },
        state = tooltip,
        focusable = false,
        enableUserInput = false,
    ) {
        Box(Modifier.size(48.dp).testTag("voice_input")
            .background(when {
                listening -> colors.errorContainer
                usable -> colors.primaryContainer
                else -> colors.surfaceVariant
            }, RoundedCornerShape(12.dp))
            .pointerInteropFilter { event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        if (!usable || active) false else { start(); true }
                    }
                    MotionEvent.ACTION_UP -> { recording?.release(); true }
                    MotionEvent.ACTION_CANCEL -> { recording?.cancel(); true }
                    else -> true
                }
            }
            .semantics {
                role = Role.Button
                contentDescription = description
                if (!usable || (active && recording?.holding != true)) disabled()
                // Accessibility activation uses two clicks in place of a pointer hold.
                onClick(label = if (active) "Finish recording" else "Start recording") {
                    if (!usable) false
                    else if (active) { recording?.release(); true }
                    else { start(); true }
                }
            }.padding(12.dp)) {
            if (active && !listening && recording?.holding != true) {
                CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
            } else {
                Icon(painterResource(android.R.drawable.ic_btn_speak_now), null,
                    tint = if (listening) colors.onErrorContainer else colors.onPrimaryContainer)
            }
        }
    }
}
