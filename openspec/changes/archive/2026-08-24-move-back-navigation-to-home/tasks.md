## 1. Home-Owned Back Navigation

- [x] 1.1 Add a `Home.Back` message and have `Home.decode` intercept the `back` event before delegating all other events to the active page; verify with `dune build`.
- [x] 1.2 Handle `Home.Back` in `Home.update` by retaining the root worktree list or returning from a selected worktree through Home navigation; remove page-level `back` messages and decoder branches; verify with `dune build`.

## 2. Regression Coverage

- [x] 2.1 Update navigation tests to target `Home.Back` and assert JSON `back` returns the same document as before from both the selected worktree and root list; verify with `dune test`.
- [x] 2.2 Run `dune fmt` and `dune test` after resolving any overlap with `refactor-stack-navigation`, preserving `Home.Back` as the navigation entry point; verify both commands succeed.
