# Tasks

## 1. Folder-scoped OpenCode operations

- [x] 1.1 Confirm the V2 contract from migration `401b293` and `docs/handoff-opencode-v2-runtime.md`; record verified routes, parameters, response shapes, version, and registration authentication in design.md. Verified against migrated runtime and passing `dune exec test/test_opencode.exe`.
- [x] 1.2 Reuse `Runtime.load_opencode_folder_sessions` from the migration. Verify existing `test/test_opencode.ml` fixtures cover exact filtering before limit, subdirectories, worktrees, newer unrelated sessions, the global active map and retry detail reads limited to displayed active sessions.
- [x] 1.3 Reuse `Runtime.create_opencode_session` from the migration. Verify existing runtime fixtures cover request encoding, registration authentication, absent title/agent/model, failure propagation, and no automatic prompt or creation retry.

## 2. Tab-local navigation and session creation

- [x] 2.1 Extend `Project_tabs` in `lib/home_components.ml` with per-tab directory/list/chat state while retaining shared directory data and existing tab identities and close-selection rules. Reuse `Sessions` and `Session`, reordering component definitions if necessary. Verify initial empty tabs, creation, switching without loads, and closing a chat without deleting or aborting its session in `test/test_remote_dev.ml` and `test/test_folder_tabs.ml`.
- [x] 2.2 Route listed-directory selection into the originating tab's folder session list and session-row selection into its chat; delegate root Back and Refresh from `lib/home.ml` to the active screen. Verify the full forward/back path, unknown-path rejection, independent tab state, active-screen-only refresh, preserved emulator state, and unchanged Claude directory clicks.
- [x] 2.3 Add folder context, loading/error presentation, and the top «Создать новую сессию» control to `Sessions`. On success, retain the new session in the bounded list and open its empty chat; prevent concurrent duplicate creation and preserve rows on failure. Verify empty and populated lists, initial load failure, refresh recovery, creation failure, successful creation followed by Back, and detail-load failure without repeated creation.
- [x] 2.4 Update README navigation and usage sections for folder-local sessions, the inherited 20-session limit, creation, per-tab state, Back, and screen-specific Refresh. Verify the documented flow matches the component scenarios and remove superseded claims about log-only OpenCode clicks and inaccessible session screens.

## 3. Addressed events and existing chat operations

- [x] 3.1 Carry tab and applicable screen/session identity through nested UI events and command results. Ignore results for closed tabs or replaced screens, and reject client-submitted internal results in `lib/server.ml`. Verify forged nested events, late loads, navigation away, and tab closure in backend tests.
- [x] 3.2 Adapt ordinary prompt and background slash-command dispatch to nested tab chats, retaining the originating tab/session for completion. Verify JSON acceptance responses, asynchronous command execution, failure after switching tabs, and completion after closing the originating tab without affecting another chat.
- [x] 3.3 Exercise existing chat features through the new tab event path: prompt submission, voice draft, transcript refresh, Stop, pending-input notice, and missing-session return to the correct folder list. Verify request targets and UI state with the existing mocked HTTP and server test helpers.
- [x] 3.4 Update README protocol examples for nested tab-content events and internal-result rejection. Verify examples against serialized advertised events and confirm Android still uses generic root Back/Refresh and existing UI nodes.

## 4. Integration verification

- [x] 4.1 Run `dune fmt`, `dune build`, and `dune test`; resolve failures and confirm all host-side checks pass independently of Android device availability.
- [x] 4.2 Exercise the complete folder → sessions → existing/new chat flow with a compatible OpenCode server, including an empty folder, an unavailable server, and two tabs. Verify exact-folder results and that creation opens the returned session without an initial prompt; report any unavailable live-server checks explicitly.
- [x] 4.3 If device `abf51f11` is available, set `ANDROID_SERIAL=abf51f11` before device operations and smoke-test navigation, the top creation control, tab switching, and the unchanged emulator pane. Use only that device; if unavailable, report the device check as blocked and retain the completed host-side results.

## Verification notes — 2026-10-08

- `dune fmt`, `dune build`, and `dune test` passed after implementation and the review fix.
- `REMOTE_DEV_LIVE_READ_ONLY=1 dune exec test/test_opencode.exe` passed: 17 exact-folder sessions.
- Live HTTP UI smoke test used the built backend and registered V2 service with an isolated empty folder and mocked adb transport. Verified creation without a prompt, opening the returned session, independent tabs, registration-unavailable error and recovery. The disposable session was deleted; no live prompt, command, or interruption was sent. Script used: `/private/var/folders/vy/q595y6l936gggt042s884ww00000gn/T/opencode/folder-tabs-live.py` (temporary verification artifact).
- Fresh-context review found a stuck creation indicator after navigating to an existing chat during creation. A regression failed before the fix and passed after clearing invalidated list operation state when saving it for Back. Full suite passed. No other review findings remained.
- Device check 4.3 initially blocked by disconnection; completed on 2026-10-09 after `abf51f11` was connected. With `ANDROID_SERIAL` set and explicit device selection, the installed Android client verified folder → empty list → creation → empty chat, switching to a second tab and back with chat retained, system Back to sessions and directories, list Refresh, and reopening the session. UI layouts confirmed the emulator pane stayed unchanged throughout; no emulator was launched. The disposable session's empty message list was confirmed through V2 and the session deleted afterward.
