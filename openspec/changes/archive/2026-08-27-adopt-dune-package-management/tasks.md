## 1. Dune dependency resolution

- [x] 1.1 Add a root `dune-workspace` that enables Dune Package Management and remove the `ppx_deriving_yojson` Git pin from `dune-project`; verify `dune pkg lock` recognizes the project configuration.
- [x] 1.2 Generate and commit `dune.lock`; verify it resolves `ppx_deriving_yojson` version `3.10.0` without a Git source.

## 2. Result codec compatibility

- [x] 2.1 Retain the manual `result_to_yojson` and `result_of_yojson` helpers and their direct tests; verify `dune build @all` succeeds using the lock directory.
- [x] 2.2 Run `dune test` and verify the direct and `Loaded`/`Finished` `Ok`/`Error` round-trip assertions preserve the existing JSON representation.

## 3. Documentation

- [x] 3.1 Update README prerequisites to require Dune rather than dependencies preinstalled from `remote_dev.opam`; verify the documented build command succeeds in the Dune-managed workspace.
