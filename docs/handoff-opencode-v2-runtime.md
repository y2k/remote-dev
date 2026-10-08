# OpenCode V2 runtime handoff

Migration: `migrate-opencode-v2-api`. Consumer: `folder-sessions-in-tabs`.

## Runtime interface

All operations live in `lib/runtime.ml` and execute inside
`Runtime.with_opencode_http ~net ~clock (fun () -> ...)`:

```ocaml
load_opencode_sessions : unit -> opencode_session list
load_opencode_folder_sessions : string -> opencode_session list
create_opencode_session : string -> opencode_session
load_opencode_detail : opencode_session -> opencode_detail
submit_opencode_prompt : opencode_session -> string -> unit
submit_opencode_command : opencode_session -> string -> string -> unit
abort_opencode : opencode_session -> unit
```

Each operation rediscovers the existing shared service. Startup and directory
listing do not discover or start it. Failed writes are never replayed.
`Runtime.with_http` supplies isolated HTTP fixtures and skips discovery;
`with_opencode_service ~clock ~read ~request` tests discovery and authentication.

Folder listing uses exact server-side `directory` filtering, descending update
order, and limit 20; it does not follow the next cursor. Creation sends only
`{location:{directory}}` and returns the server identity, without prompting.

Normalized records retain their existing UI shape:

- Session: `id`, `title`, `directory`, optional `workspace`, optional `agent`,
  optional `(provider, model, variant)` model, and `Idle | Busy | Retry of string`.
- `workspace` is `None` in V2. Missing title displays `Без названия` without a
  server rename. Missing agent/model remain `None`.
- Detail: `session`, chronological `messages`, and `needs_input`.
- Message: `role = User | Assistant`, `text`; reasoning/tools/system records
  are excluded. All message pages are read before returning a detail.
- Active execution determines busy state; the latest assistant retry metadata
  determines retry only while active. Permissions/forms determine pending input.
- `OpenCode_not_found` means a tagged missing session, not every HTTP 404.
  Command/location failures remain operation errors. Interruption may leave the
  subsequent refresh busy while cleanup completes.

## Required reconciliation before dependent apply

The dependent change's planning artifacts still assume legacy authentication
and session defaults. Reconcile them separately before implementation:

1. Replace fixed-port/environment-password assumptions with registration-based
   discovery and Basic `opencode` authentication. An absent password omits auth;
   an empty password is transmitted. Backend overrides are ignored.
2. Accept missing title, agent, and model after empty creation. Do not insert
   client defaults or send stale session configuration on subsequent input.
3. Connect folder navigation and creation controls to the operations above using
   TEA; preserve the returned session identity and refresh from server state.

## Verification, 2026-10-08

- `dune build`, `dune test`, `dune fmt`: passed.
- Isolated tests cover discovery, dynamic IPv4/IPv6/localhost transport, auth,
  timeout, exact-folder filtering requests, creation, transcript pagination,
  retry/pending states, prompt admission, commands, interruption, and tagged
  errors. Server tests cover admission without generation, delayed callbacks,
  missing-session navigation and rendering.
- Running service: **2.0.25**, registered PID matched `/api/info`, Basic auth
  from registration. No credentials or transcripts were printed.
- Read-only HTTP checks: 15 repository-folder sessions, all exact directory
  matches in descending update order; metadata/message/permission/form and
  active-map envelopes matched the contract.
- Actual OCaml runtime read-only check passed for global/folder lists and one
  complete session detail. Repeat explicitly with:
  `REMOTE_DEV_LIVE_READ_ONLY=1 dune exec test/test_opencode.exe`.
- **Live create/prompt/command/Stop remain unverified.** The user chose to record
  this limitation rather than perform mutating checks. No disposable session
  was created; no live input or interruption was sent.
- No Android device operations were performed; host checks are device-independent.

## Sources and changed files

Contract investigation used OpenCode 2.0.24, then read-only verification on
2.0.25. References:

- https://opencode.ai/v2/docs/api
- https://opencode.ai/v2/openapi.json and the running service's `/openapi.json`
- https://github.com/anomalyco/opencode/tree/v2.0.24/packages/server/src/handlers
- https://github.com/anomalyco/opencode/blob/v2.0.24/packages/client/src/service-probe.ts
- https://github.com/anomalyco/opencode/blob/v2.0.24/packages/core/src/session/store.ts
- `openspec/changes/migrate-opencode-v2-api/design.md`

Uncommitted implementation: `lib/runtime.ml`, `lib/server.ml`, `bin/main.ml`,
`test/test_opencode.ml`, `test/test_runtime.ml`, `test/test_remote_dev.ml`,
`test/dune`, `README.md`, this handoff and migration planning artifacts.
The dependent change's artifacts and UI have not been edited.
