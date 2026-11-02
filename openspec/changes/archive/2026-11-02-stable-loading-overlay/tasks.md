# Tasks

## 1. Stable loading overlay

- [x] 1.1 Replace the Content branch's loading text with a Material3 linear indicator in a matchParentSize overlay inside the existing Box; verify `./gradlew :app:assembleDebug :app:testDebugUnitTest` from android succeeds.
- [x] 1.2 Read and source the root .envrc and use only its nonempty ANDROID_SERIAL for device checks. Verify repeated requests with unchanged content preserve bounds before, during and after loading; check stream completion and failure dismiss the indicator. Record device unavailability if these checks are blocked.
- [x] 1.3 Review the implementation diff for layout sizing, overlay drawing order and unchanged request handling; fix all obvious or important findings and verify `git diff --check` succeeds.

## Verification notes

- Android debug build and existing unit tests passed.
- Updated APK checked on the device selected by the root .envrc (`192.168.0.11:5555`). Started the local backend and verified repeated refresh requests. Temporarily served its unchanged UI document through a controlled NDJSON response and a delayed HTTP 503 response. Layout assertions confirmed stable content bounds `[27,204][2533,1564]` across stream completion, unchanged tab/emulator anchors, progress present while pending and absent after completion/failure, and retained content with an error. Screenshots visually confirmed no content shift. The normal backend was restored and left running; a final refresh succeeded.
- Reviewed the diff: matchParentSize excludes the overlay from parent sizing, the indicator draws after content, and request handling is unchanged. `git diff --check` passed.
