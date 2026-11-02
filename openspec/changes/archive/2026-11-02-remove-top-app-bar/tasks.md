# Tasks

Design was deliberately omitted under the schema's conditional guidance: this is a local removal using the existing Scaffold and refresh path, without architectural changes or unresolved technical decisions.

## 1. Remove the application header

- [x] 1.1 Remove the Scaffold topBar, RefreshMenu, and unused imports in `android/app/src/main/java/io/y2k/remote_client/MainActivity.kt`; keep safeDrawing insets, innerPadding consumption, and the existing pull-to-refresh callback. Verify there is no reserved header space and run `./gradlew :app:assembleDebug` from `android/`.
- [x] 1.2 Remove the obsolete `refreshMenuInvokesRootRefreshAction` test from `BackendUiParserTest.kt`, preserving the existing bounded-content and weighted-scroll pull-to-refresh checks. Verify instrumentation sources compile with `./gradlew :app:assembleDebugAndroidTest` from `android/`.

## 2. Integration verification and review

- [x] 2.1 Read and source the repository-root `.envrc`, require a nonempty ANDROID_SERIAL, and use only that device for focused instrumentation and UI checks. Verify header absence and reclaimed space in light/dark appearances, preserved safe insets and pane layout, pull-to-refresh after an error, and permission retry by pull-to-refresh on Android 17 when applicable. If the configured device is unavailable, record the blocked device checks while completing host checks.
- [x] 2.2 Review the implementation against the delta spec and fix all obvious or important findings before completion. Verify the final diff is limited to the header removal and related tests, and rerun affected checks after any fixes.

## Verification evidence

- Debug APK and instrumentation APK builds passed.
- Both focused pull-to-refresh instrumentation tests passed on the configured Android 13 device.
- Light/dark UI inspection showed content starting at y=60 immediately below the system status bar, with no app header or reserved gap; two-pane geometry and bottom input remained intact.
- A temporary build targeting unreachable loopback displayed the connection error without a header in both themes. After forwarding port 8080 to the backend, a downward swipe restored backend content, confirming recovery from error.
- Restored the normal backend build, original light appearance, and removed the temporary port forwarding.
- Android 17 permission retry is not applicable to this Android 13 device.
