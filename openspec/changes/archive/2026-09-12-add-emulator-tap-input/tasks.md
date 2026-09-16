## 1. Image event contract

- [x] 1.1 Extend the OCaml image component and Android image model/parser with an optional opaque event array, including event mapping and serialization. Update affected pattern matches and add focused assertions to the existing backend and Android tests verifying event preservation, unchanged images without events, and rejection of invalid image events.

## 2. Backend tap execution

- [x] 2.1 Add a runtime helper executing `adb -s <serial> shell input tap <x> <y>` through the existing process effect. Verify exact argv and nonzero-exit handling using the existing effect-based checks in `test/test_runtime.ml`.
- [x] 2.2 Add the preview-bound tap event, string JSON payload validation, selected/listed serial guard, command execution, and completion/error handling to the emulator TEA component; reject externally supplied new internal completion messages in `Server.decode`. Verify with existing backend tests that a valid POST performs one tap, malformed/out-of-bounds payloads and stale targets perform none, command failure is visible, and screen, selection, and list survive failure and retry.

## 3. Android tap submission

- [x] 3.1 Recognize completed single taps on decoded interactive images, map centered Fit coordinates to source pixels, and submit the unchanged event with a JSON-encoded string containing `x`, `y`, `width`, and `height` through the existing event callback and request lock. Preserve the content description and add a `ponytail:` comment describing the displayed-frame/rotation limit and when to revisit it. Verify scaled and letterboxed coordinate mapping, margins, current event/bitmap after a change, missing bitmap, cancelled/dragged gestures, and blocked taps in the existing Android test suite.
- [x] 3.2 Preserve the existing image source and three-second polling across successful tap responses without adding a refresh signal. Extend the existing image polling test to verify one tap event, no tap-triggered image request after the response, and continued scheduled refresh.

## 4. Documentation and integration verification

- [x] 4.1 Update the image-node and emulator sections in `README.md` with the optional event, exact string payload example, shared request blocking, and polling-only visual feedback. Verify that the documented envelope matches the backend decode test and does not imply immediate screenshot refresh.
- [x] 4.2 Run `dune fmt`, `make test`, and `./android/gradlew --no-daemon -p android :app:assembleDebug :app:connectedDebugAndroidTest` with the configured Android SDK/backendHost and a connected test device. Smoke-test a tap on a selected emulator, visual feedback on the next scheduled screenshot, and an ADB failure with the surrounding UI preserved; record command results and any environment blocker.

## Verification results

- `dune fmt` and `make test`: passed. `dune build bin/main.exe`: passed for the live smoke check.
- `./android/gradlew --no-daemon -p android :app:assembleDebug :app:connectedDebugAndroidTest`: passed; 28 tests on Tablet (Android 17, emulator-5554).
- Android gesture and controlled-clock tests verify coordinate mapping, margins, cancellation, state changes, request blocking, and continued three-second polling without a response-triggered fetch.
- Live HTTP/ADB smoke: selected emulator-5554, submitted the image's advertised event, opened Network & internet in Settings, and verified the PNG fetched three seconds later reflected the navigation.
- Injected ADB exit code 1 at the external-process boundary: the returned UI displayed the tap error while retaining the surrounding screen and identical preview node. The temporary smoke server was stopped afterward.
- `git diff --check`: passed. No environment blockers remain.
