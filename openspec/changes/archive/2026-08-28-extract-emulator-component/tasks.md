## 1. Emulator Component

- [x] 1.1 Add the `Emulator` TEA module in `lib/home_components.ml` with its own model, messages, view, enter command, and update logic; verify focused assertions cover successful and failed loading, default selection, valid selection, unknown serial rejection, empty state, and image source.
- [x] 1.2 Replace the emulator fields and messages in `Worktree` with the nested component and lift its view and commands through `Components.map` and `Cmd.map`; verify worktree entry produces a lifted load result and emulator button events round-trip through `Home.msg`.

## 2. Integration Verification

- [x] 2.1 Update existing `test/test_remote_dev.ml` model and message expectations for the nested component; verify Claude updates preserve emulator state, emulator updates preserve worktree state, and the existing emulator UI behavior remains covered.
- [x] 2.2 Run `dune fmt` and `dune test`; verify formatting succeeds and the complete OCaml test suite passes without changes to `Runtime`, `Server`, the SDUI protocol, or Android code.
