## 1. Reference implementation and agreed simplification

- [x] 1.1 Inspect the reference SpeechInput.kt, ChatInput.kt, manifest, Gradle dependencies, and theme; verify by source inspection and record the native recognition flow, permissions, styling, and early-completion limitation in design.md. Device verification is recorded below.
- [x] 1.2 Reconcile the artifacts with the user's choice of the simplest implementation; verify design.md selects native SpeechRecognizer with ru-RU, permits service-driven early completion, and requires holding an early result until release without automatic restart.

## 2. Add the reusable UI node

- [x] 2.1 Add the event-only voice input constructor, event mapping, and JSON encoding in `lib/components.ml`; verify a focused existing-style OCaml test covers nested event mapping and output without text or label using `dune test`.
- [x] 2.2 Add the Android `voice_input` model and parser with required array event and rejection of label/text; verify valid nested nodes and malformed input in `BackendUiParserTest.kt`.
- [x] 2.3 Place the voice node to the right of Commands in Worktree.view and Prompt in Session.view using row weights [1; 0]; reuse Worktree.Set_prompt and add Session.Set_prompt to replace prompt with no command effect. Verify both rendered trees and pure updates in focused OCaml checks, including that voice input does not run or submit an agent prompt.

## 3. Implement the isolated voice component

- [x] 3.1 Implement `VoiceInputButton.kt` with native SpeechRecognizer, ru-RU, and the first final alternative, and connect it in `UiNodeContent.kt`; add a ponytail: comment documenting service-driven early completion and when to revisit continuous capture. Verify in a focused runnable component check that release stops still-active capture, both result/release orderings emit once, partial results emit nothing, and pauses never trigger automatic restart.
- [x] 3.2 Declare RECORD_AUDIO and the RecognitionService query; implement runtime permission, service availability, cleanup, cancellation, busy-state handling, and visible failure feedback. Verify unavailable recognition, denial, permission granted after release, gesture cancellation (including a retained final result), backgrounding, node replacement, another event starting, and late callbacks do not capture unexpectedly or submit stale text.
- [x] 3.3 Provide the fixed system microphone icon in a 48 dp control with 12 dp corners and padding, recording/recognition indicators, and accessible action semantics without a visible caption or text-setting API; verify rendered semantics and inspect the control against the original on an Android device.
- [x] 3.4 Verify successful voice responses replace the input's local draft, including a repeated result equal to the previous server prompt after local editing. If needed, reset input state on accepted document identity rather than structural node equality, while retaining the draft during requests and on failure. Add a runnable Android regression check covering this case and verify editing followed by Enter submits the edited value.

## 4. Verify integration

- [x] 4.1 Run `dune fmt`, `make test`, and `./android/gradlew --no-daemon -p android :app:assembleDebug :app:connectedDebugAndroidTest` with the configured backend host and a test device; verify the component and existing parser/event regression checks pass.
- [x] 4.2 Exercise both Worktree Commands and OpenCode session Prompt on a microphone-capable device with a recognition service: verify the microphone is on the right, hold and speak Russian, release, and verify the event replaces the field without submitting to the agent. Edit the text and verify Enter submits the current value. Check pauses during a hold and ensure an early final result is not sent before release; verify silence, denial, cancellation, and navigation produce no voice event. Record observed results.

## Verification notes

- `make test` passed, including nested voice event mapping, both prompt rows, and effect-free Set_prompt updates.
- `:app:testDebugUnitTest` passed; VoiceRecordingTest covers both result/release orders, exactly-once submission, empty results, cancellation, and late results.
- `:app:assembleDebug :app:connectedDebugAndroidTest` passed with 29 tests on emulator-5554 (Tablet, Android 17). The regression check renders the voice node, rejects malformed nodes, preserves an in-flight draft, replaces it with a repeated server result, and submits the subsequently edited value with Enter.
- The user confirmed the error tooltip works and explicitly accepted the remaining QA checks as passed. Tasks 3.2, 3.3, and 4.2 are closed on that basis; the assistant did not independently rerun the live device scenarios.
