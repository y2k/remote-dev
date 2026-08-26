## 1. Message Unification

- [x] 1.1 Replace the `action` types in `Worktrees`, `New_worktree`, and `Worktree` with UI-emittable variants of their `msg` types; preserve input values during decoding and verify `dune build` succeeds.
- [x] 1.2 Remove `Home.event` and serialize mapped `Home.msg` values directly; route worktree selection and creation navigation in `Home.update` and verify the rendered JSON preserves every existing event object.

## 2. Regression Coverage

- [x] 2.1 Update `test/test_remote_dev.ml` to use the unified message constructors and remove assertions for deleted action-only transitions; verify the existing UI, navigation, validation, and streaming assertions still pass.
- [x] 2.2 Format and run the complete suite with `dune fmt` and `dune test`.
