## 1. Runtime Boundary

- [x] 1.1 Replace the shared agent/root environment with provider-specific startup data, reject a positional root in OpenCode mode, and verify argument-parser tests cover both providers and invalid combinations.
- [x] 1.2 Add OpenCode global-session, status, pending-input, and textual-message JSON decoders plus prompt/command encoders, and verify focused runtime tests cover required fields, unknown fields, non-text parts, and shell-like prompt text.
- [x] 1.3 Add a testable HTTP request effect and its `httpun-eio` localhost client handler for status-checked OpenCode REST operations, including `/experimental/session` and exact directory encoding, and verify fake-effect tests cover success, connection failure, non-success status, directory query/header values, and malformed responses.

## 2. Session-Defined UI

- [x] 2.1 Add self-contained OpenCode Sessions and Session TEA components for list, transcript, status, needs-input, prompt, stop, and errors, and verify view/update tests cover empty, busy, retrying, blocked, and missing-session states.
- [x] 2.2 Make `Home` choose Claude worktree screens or OpenCode session screens from the immutable environment and route Back and root Refresh appropriately, and verify navigation tests prove Claude behavior is retained and OpenCode never exposes worktree or creation controls.

## 3. Server Operations

- [x] 3.1 Wire OpenCode list/detail/refresh/abort and ordinary `prompt_async` operations through finite TEA commands, and verify server tests cover immediate prompt completion, refreshed transcript/status, abort-then-reload, and ordinary UI errors without backend termination.
- [x] 3.2 Preserve slash parsing while dispatching `/command` in an application-scoped Eio fiber, report failures only on the still-selected session, and verify tests cover command arguments, lone `/`, no prompt fallback, navigation during execution, and late failure delivery.
- [x] 3.3 Keep the existing Claude CLI streaming route provider-specific and verify the current session capture, resume, output stream, worktree navigation, and failure tests still pass.

## 4. Android And Documentation

- [x] 4.1 Replace the Android client's hard-coded worktree load event with root Refresh and update parser/client tests to verify pull-to-refresh works for backend-defined screens without changing the UI node protocol.
- [x] 4.2 Update README startup, architecture, security, HTTP lifecycle, and UI examples for `opencode serve --hostname 127.0.0.1 --port 4096`, `opencode attach`, all-server session listing, manual refresh, status-only blocked sessions, and Claude-only positional roots; verify every documented command matches the implemented CLI.

## 5. Verification

- [x] 5.1 Run `dune fmt` and `dune test`, then verify the formatted backend diff and all OCaml checks succeed.
- [x] 5.2 Run the Android unit/instrumentation checks available in the project and `./gradlew assembleDebug -PbackendHost=192.168.0.15`, then verify the debug APK builds successfully.
