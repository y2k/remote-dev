## 1. Page Routing Boundary

- [x] 1.1 Introduce the shared `Route` type and have `Worktrees` and `Worktree` return an optional route instead of page-specific action types; verify `dune build` succeeds.
- [x] 1.2 Add page entry functions so entering the worktree list owns its reload command, then make `Home` apply only routes and mapped child commands; verify no `Home` branch matches a page-local action or error constructor.

## 2. Event Ownership

- [x] 2.1 Split common event-envelope parsing from page-local event decoding, with each active page handling its valid, invalid, and no-op events; verify malformed envelopes still return `Bad_request`.
- [x] 2.2 Simplify `Home.update` to delegate only messages for the active page and treat mismatched internal messages as no-ops; verify the code has no screen-specific recovery branches.

## 3. Regression Coverage

- [x] 3.1 Update tests for page-owned routes and decoders while preserving select, load, back, run, output, and error behavior; verify `dune test` passes.
