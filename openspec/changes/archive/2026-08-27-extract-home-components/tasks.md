## 1. Extract shared Elm primitives

- [x] 1.1 Move the generic `Cmd` type and its `none`, `run`, and `map` operations from `Home` into `Components`, and verify `Components.Cmd` exposes the same operations.

## 2. Extract home components

- [x] 2.1 Create `home_components.ml` with the current `Worktrees`, `New_worktree`, and `Worktree` modules, including their state, messages, views, commands, updates, and the worktree-root helper; verify it has no dependency on `Home`.
- [x] 2.2 Rewire `Home` to compose and lift messages from `Home_components` while retaining its root state, navigation, request decoding, session state, and stream helpers; verify existing UI JSON and command behavior remain unchanged.

## 3. Update references and verify

- [x] 3.1 Update OCaml test references to `Components.Cmd` and `Home_components` and verify the test sources compile.
- [x] 3.2 Run `dune fmt` and `dune test`; verify formatting succeeds and all existing tests pass.
