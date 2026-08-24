## 1. Creation UI

- [x] 1.1 Add a separate `New_worktree` component and its screen state, make `New` emit its event, and render one branch-name input; verify the backend UI document contains the expected events.
- [x] 1.2 Handle branch-name submission as a no-effect stub and route `back` from the creation screen to the worktree list; verify neither path invokes `Runtime` or changes the listed worktrees.

## 2. Verification

- [x] 2.1 Extend backend UI checks for opening creation, submitting a branch name, and returning with `back`; run `dune fmt` and `dune test`.
