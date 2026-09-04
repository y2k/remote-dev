## 1. Startup Agent Environment

- [x] 1.1 Add the required lowercase `--agent claude|opencode` option and optional repository-root argument with the OCaml `Arg` module, pass one immutable environment into the server and TEA functions, and verify parser checks cover both agents, the cwd default, an explicit root, and missing or invalid agents.
- [x] 1.2 Render the static agent label on every screen, expose worktree creation and Claude shortcuts only in Claude mode, prevent OpenCode mode from reaching Claude worktree creation, and verify both mode-specific UI trees and the no-mixed-CLI invariant.

## 2. Session-Aware Prompt Dispatch

- [x] 2.1 Replace the Claude-specific prompt message with a handler-based generic prompt message, add the hidden optional session ID to selected-worktree state, preserve it while clearing the previous response, and verify first, continued, failed, and Back-reset transitions.
- [x] 2.2 Generalize the server prompt stream request to capture the startup agent and current session ID, apply session-ID updates without emitting duplicate UI documents, and verify ordinary execution failures remain UI errors while fatal protocol exceptions escape and terminate the backend path.

## 3. CLI Process Protocols

- [x] 3.1 Extend the Claude stream adapter to extract and validate its session ID and add explicit resume arguments without changing cwd, prompt quoting, streaming deltas, or permissions; verify fresh, resumed, unsuccessful, malformed, missing-ID, and mismatched-ID fake process streams.
- [x] 3.2 Add the OpenCode 1.18.20 JSON adapter and argument-safe `opencode run` invocation with `--dir`, `--format json`, `--auto`, optional `--session`, and prompt versus slash-command routing; verify completed text order, session capture/resume, a lone slash, command arguments, unknown events, no command fallback, ordinary process failure, and fatal protocol violations with fake processes.

## 4. Contracts And Verification

- [x] 4.1 Update Makefile argument forwarding and README startup examples, conditional CLI prerequisites, OpenCode worktree/streaming limits, session lifetime, and trusted-LAN warning for `--auto`; verify the documented commands include the required agent and optional root.
- [x] 4.2 Run `dune fmt`, `dune test`, and strict OpenSpec validation; verify no Android production change or real authenticated CLI invocation is required.
