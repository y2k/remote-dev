## 1. Compiler warnings

- [x] 1.1 Add the inherited root Dune environment with the selected unused-entity warnings enabled and fatal; verify `dune build --verbose` passes the warning flags to every project target.
- [x] 1.2 Resolve any diagnostics exposed by the stricter configuration; verify `dune build` succeeds.

## 2. Dependency hygiene

- [x] 2.1 Add `dune build @unused-libs` to the `test` Make target; verify `make test` succeeds and includes the unused-library check.
