# Tasks

## 1. Shared service discovery and transport

- [x] 1.1 Implement registration decoding and read-only health discovery in `lib/runtime.ml`, with injectable registration/HTTP inputs for tests. Verify XDG/default paths, dynamic loopback endpoints, missing/invalid registration, PID/version mismatch, unavailable service, and bounded health timeout using isolated fixtures without real credentials or process startup.
- [x] 1.2 Replace fixed-port transport and environment-based authentication with the discovered endpoint and registration credentials. Verify Host/port selection, IPv4/IPv6/localhost handling, rejection of unsupported/nonlocal endpoints before credential transmission, absent versus empty passwords, ignored legacy environment overrides, and credential-free errors in transport/authentication tests.
- [x] 1.3 Integrate lazy discovery per session operation and document the V2 shared-service connection in README. Verify startup/directory-only operations perform no discovery, a subsequent operation sees a replaced registration, and failed writes are not automatically replayed; check documented commands against installed V2 help.

## 2. Session metadata, lists, and empty creation

- [x] 2.1 Replace V1 session decoding with V2 envelopes and `location.directory`, preserving normalized UI data and accepting missing title/agent/model. Verify existing titled sessions and untitled empty-session fixtures, including the display-only title fallback and protocol failures for missing required identity/location.
- [x] 2.2 Migrate the existing global list and add an exact-folder runtime list operation using server-side directory filtering, descending order, and limit 20. Verify encoded paths, one-page behavior despite a next cursor, empty results, and a fixture with more than 20 newer sessions in other directories, subdirectories, and worktrees; document the integration boundary with the dependent UI change.
- [x] 2.3 Add empty-session creation with `{location:{directory}}` and registration authentication. Verify one creation request, no prompt, optional defaults, exact returned identity/location, and no automatic retry after an ambiguous transport failure.

## 3. Transcript, state, and pending input

- [x] 3.1 Migrate detail metadata and transcript reads to V2 and follow ascending message pages using opaque cursors without combining cursor and order. Verify more than 50 mixed-type messages, role/content extraction, a nonempty last page followed by an empty page, absent next cursor, and failure on a later page without returning a successful partial transcript.
- [x] 3.2 Normalize active/retry state and session-scoped permission/form lists. Verify idle/busy/retry transitions, retry metadata with a completed attempt, stale retry on an inactive session, bounded retry reads for displayed active sessions only, and independent permission/form pending cases without controls for answering them. Update README's status and pending-input descriptions.

## 4. Input operations, interruption, and errors

- [x] 4.1 Migrate prompt and command bodies/status handling, retaining server-owned session configuration. Verify literal prompt preservation, `{text}` admission with HTTP 200, `{name,text}` commands with empty HTTP 204, no stale directory/workspace/model/agent overrides, and no command-to-prompt fallback.
- [x] 4.2 Decode V2 error tags rather than mapping every 404 to a missing session; migrate Stop to interruption with both boolean outcomes. Verify session/command/location error distinctions, malformed responses, redacted 401 diagnostics, and refresh after interruption that can legitimately remain busy.
- [x] 4.3 Adapt `lib/server.ml` and normalized-data consumers only as required, preserving TEA and existing navigation. Update server/UI fixtures in `test/test_remote_dev.ml`; verify prompt acceptance returns before generation, delayed slash callbacks leave Android events available, missing-session refresh returns to the list, and pending-input/Stop rendering remains correct. Update README operation examples and remove V1 endpoint/authentication instructions.

## 5. Integration verification and handoff

- [x] 5.1 Run `dune fmt`, `dune build`, and `dune test`; verify all host-side checks pass independently of Android availability and review the final diff for unintended navigation or Claude-mode changes.
- [x] 5.2 Perform read-only checks against the discovered running V2 service and record server version, authentication mode, folder-list behavior, and sanitized results. For live create/prompt/command/Stop checks, first agree on the disposable session, directory, actions, and retention; record executed results or explicitly document that these mutating checks remain unverified rather than claiming success.
- [x] 5.3 Deliver a handoff for `folder-sessions-in-tabs` with final runtime signatures, normalized data shapes, source/schema references, verification results, remaining limitations, and commit or changed-file list. Verify it explicitly identifies the required reconciliation of that change's authentication/default assumptions without editing or implementing the dependent change.

## Workflow follow-up

- Review these planning artifacts before explicitly starting apply.
- Reconcile the dependent UI change separately before its implementation, using the completed migration handoff.
