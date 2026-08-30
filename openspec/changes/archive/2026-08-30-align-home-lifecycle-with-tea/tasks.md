## 1. Component lifecycle

- [x] 1.1 Replace each `Home_components` module's `initial` and `enter` pair with one `init` returning the same model and command, and verify focused initialization assertions pass without executing effects before `Cmd.run`.

## 2. Home composition

- [x] 2.1 Build `Home.init` and the server reset state from child `init` results while preserving emulator-before-worktrees command ordering, and verify the existing bootstrap success and failure assertions pass.
- [x] 2.2 Inline target component initialization in the corresponding `Home.update` navigation branches, remove `enter_worktrees`, `enter_worktree`, and `enter_new_worktree`, and verify selection, creation, completion, and Back navigation assertions preserve their models and commands.
- [x] 2.3 Update remaining direct test construction to use `init`, and verify no OCaml reference to `initial`, `enter`, or `enter_*` remains for `Home_components` lifecycle.

## 3. Verification

- [x] 3.1 Run `dune fmt` and `dune test`, and verify all OCaml tests pass with unchanged rendered UI documents and serialized messages.
