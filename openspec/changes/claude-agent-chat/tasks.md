## 1. Feasibility gate — before replacing the current Claude flow

Blocked on 2026-09-09 at task 1.1: Claude Code 2.1.266 explicitly reports that development channels are blocked by organization policy and inbound messages will be silently dropped. An administrator must enable Channels before registration can be verified. Public MCP handshake alone succeeded but is not channel registration. See the experiment evidence in `design.md`; no task is complete and sections 2–5 remain gated.

User update: administrators will not enable Channels. Work is paused pending the user's choice of an alternative integration; no alternative has been accepted. Read `handoff.md` before resuming. Do not retry the current gate or implement sections 2–5 until the approach and affected artifacts are revised.

- [ ] 1.1 After leaving explore mode, agree on disposable session launch/configuration scope and establish an isolated Channels + Hooks setup; verify and record the installed Claude version, effective channel availability, enrollment flags, and successful public channel registration without changing production sessions.
- [ ] 1.2 Prove the smallest public stdio MCP bridge can deliver text and receive `reply` from the same enrolled Claude process while idle and busy; verify with a runnable controlled check, record notification acknowledgment limits, and establish whether native OCaml works or a documented SDK dependency is necessary.
- [ ] 1.3 Prove session-to-channel identity using two enrolled sessions in the same directory and lifecycle changes including clear, explicit resume, and background handoff; verify no cross-session delivery and that ambiguous identity disables sending rather than guessing by directory.
- [ ] 1.4 Prove public history reading plus live assistant-text observation with terminal and channel messages; verify a controlled conversation appears in order, including repeated identical text, without duplicate replies or lost text when persisted history catches up, and record the selected reader/dependencies.
- [ ] 1.5 Prove public tool-permission relay and user-question handling; verify allow, deny, choices, local-first answers, stale responses, and disconnect behavior against disposable requests without permission bypass or private protocols.
- [ ] 1.6 Establish the minimal authenticated single-client and verified local-ingress mechanism; verify unauthorized submissions and forged session registrations cannot control an agent, and record the concrete protocol and configuration before production implementation.
- [ ] 1.7 Record the gate results, tested public contracts, remaining limits, and concrete integration choices in `design.md`; verify every mandatory acceptance row passes before proceeding to sections 2–5. If one fails, leave those sections blocked and return to the user rather than substituting a reduced feature or private API.

## 2. Discovery and enrolled-session integration — requires gate success

- [ ] 2.1 Add all-project Claude discovery at the existing runtime process boundary using `claude agents --json`; verify representative interactive/background entries, optional metadata, empty results, malformed data, command failures, and absence of directory/completed-session flags in `test/test_runtime.ml`.
- [ ] 2.2 Implement the gate-verified channel bridge, local hook ingress, and connection-to-session association; verify authenticated registration, precise routing between two sessions, unsupported/policy-rejected enrollment, and invalidation after identity changes with focused protocol checks.
- [ ] 2.3 Implement the gate-verified history reader and live-text reconciliation; verify prior terminal messages, channel-originated messages, intermediate-to-final replacement, repeated text, and absence of tool-detail noise using the controlled traces from section 1.
- [ ] 2.4 Implement message handoff and delivery uncertainty without automatic replay; verify busy delivery returns promptly, shell-like text remains literal, partial failure preserves retry text, and reconnect does not resend or spawn/resume Claude.
- [ ] 2.5 Implement session-bound permission decisions and question answers using the verified public mechanisms; verify unauthorized, stale, already-resolved, and wrong-session responses cannot affect another request, while valid allow/deny and question answers work.

## 3. Backend-defined agent list and chat

- [ ] 3.1 Replace the Claude root branch in `lib/home.ml` with a TEA agent-list component using the existing component patterns; verify all-project rows, disconnected labels without chat actions, initial-load errors, Back, Refresh, and legacy positional-root compatibility in backend tests.
- [ ] 3.2 Add the enrolled-agent chat and pending-input TEA sections in `lib/home_components.ml`; verify prior history remains after submission, the composer stays visible, pending decisions target the selected session, and no interrupt or agent-launch controls appear.
- [ ] 3.3 Connect external integration events to confirmed server state while keeping UI requests finite in `lib/server.ml`; verify input, pending decisions, and Back complete while Claude is busy and local integration ingress is separate from the UI event surface.
- [ ] 3.4 Implement disconnected-chat behavior; verify displayed history and draft remain, unavailable actions are disabled, recovery neither replays text nor resumes agents, and Back reloads discovery so completed entries disappear when no longer returned.
- [ ] 3.5 Remove the retired worktree screens, shortcuts, creation actions, and Claude prompt-spawning path after tracing their remaining callers; verify stale worktree events cannot launch processes or alter directories and update old worktree/resume tests to the replacement behavior.

## 4. Android observation and interaction

- [ ] 4.1 Add automatic finite observation of the selected Claude chat in `MainActivity.kt` while preserving serialized user actions; verify intermediate output appears before turn completion, updates do not overwrite drafts, stale reads cannot undo navigation, and OpenCode remains manually refreshed.
- [ ] 4.2 Wire the gate-selected client authentication and preserve chat/input on backend transport failure; verify unauthorized control is rejected and a failed or ambiguous submission is not automatically retried.

## 5. Integration verification and enrollment documentation

- [ ] 5.1 Update `README.md` with the experimentally verified setup, enrollment flags, client binding, supported Claude version, all-project discovery, legacy-root semantics, public preview restrictions, local-only trust dialogs, and explicit rollback steps; verify the documented sequence against a disposable enrolled session.
- [ ] 5.2 Run `dune fmt` after OCaml changes, `make test`, and `./gradlew testDebugUnitTest assembleDebug` from `android`; verify formatting/build/tests pass and retained OpenCode and emulator checks remain green.
- [ ] 5.3 Exercise the full Android-to-Claude flow with enrolled and unenrolled agents from multiple projects: history, live text, busy messages, permissions/questions, Back/Refresh, disconnection, and manual retry; record evidence that no second Claude prompt process or worktree is created and that production acceptance matches the feasibility results.
