## 1. PPX Setup

- [x] 1.1 Add `ppx_variants_conv` to `dune-project` dependencies and the library `(pps ...)`, install the resolved project dependencies, and verify `dune build @install` succeeds with generated package metadata containing the new dependency.

## 2. Selective Derivation

- [x] 2.1 Add `variants` alongside `yojson` derivation on `Home.msg`, replace its `Components.map` and `Cmd.map` wrapper lambdas with the generated constructor functions, and verify the library builds without generated-name conflicts.
- [x] 2.2 Add `variants` alongside `yojson` derivation on `Worktree.msg`, replace its `Emulator_msg` wrapper lambdas with the generated constructor function, and verify no unrelated `msg` type receives the derivation.

## 3. Verification

- [x] 3.1 Run `dune fmt` and `dune test`; verify formatting is clean and existing message JSON round-trip, component mapping, command mapping, and server behavior checks pass unchanged.
