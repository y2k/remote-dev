## 1. Cmd-only Page Outcomes

- [x] 1.1 Remove `Route` and make `Worktrees` and `Worktree` return a model plus the unchanged `Cmd`, verifying `dune build` succeeds.
- [x] 1.2 Make worktree selection return a `Cmd` that delivers an internal page navigation message, and verify the direct-update assertions pass with `dune test`.

## 2. Home Navigation

- [x] 2.1 Lift page navigation messages through the existing `Cmd.map` and have `Home` enter the selected worktree only from the active list, verifying the select HTTP assertion with `dune test`.
- [x] 2.2 Make `Home.Back` return a `Cmd` for an internal back-navigation message, preserving list reload after back and root no-op; verify the existing back assertions with `dune test`.
- [x] 2.3 Keep `dispatch` as the store-then-run-command loop and verify a completed Claude command still updates the active worktree document with `dune test`.

## 3. Regression Verification

- [x] 3.1 Update regression coverage for Cmd-only navigation outcomes while retaining the current JSON documents and event behavior; verify `dune test` passes.
- [x] 3.2 Run `dune fmt`, `dune build`, and `dune test` to verify formatting and the complete suite.
