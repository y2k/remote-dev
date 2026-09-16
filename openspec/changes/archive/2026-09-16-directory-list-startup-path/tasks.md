## 1. Startup path and directory initialization

- [x] 1.1 Add a root payload to `Runtime.OpenCode`, accept one optional positional directory in both modes, resolve relative paths against startup cwd, and update usage text in `lib/runtime.ml`. Adapt constructor matches and test environment values in `lib/home.ml`, `lib/server.ml`, and tests; verify `dune build` succeeds and no bare OpenCode constructor uses remain.
- [x] 1.2 Initialize `Home`'s existing `Directories` component from the environment root instead of `Sys.getcwd ()`; verify both modes' initial models hold the supplied absolute root and the existing refresh command uses that model root.

## 2. Regression checks and documentation

- [x] 2.1 Update `test/test_runtime.ml` to cover both modes with omitted, absolute, relative, and multiple positional paths, replacing the old OpenCode-path rejection assertion. Verify the assertions preserve required-agent and duplicate-agent validation and accept a missing filesystem path for later UI error reporting.
- [x] 2.2 Update `test/test_remote_dev.ml` with an argument-to-screen regression using a non-Git directory distinct from cwd in both modes. Verify initial load and refresh read that directory, row events contain absolute paths, and an invalid explicit root produces the existing component error and retries the same root. Reuse existing external-call stubs and retain provider-isolation and directory-filtering checks.
- [x] 2.3 Update `README.md` architecture and startup instructions with positional-path examples for both agents, cwd fallback, relative-path behavior, and the changed Claude list source. Verify it no longer claims the list ignores the argument or OpenCode rejects a path, and still explains server-defined OpenCode session directories.
- [x] 2.4 Run `dune fmt` after OCaml edits and verify the regression suite with `dune test`, following repository testing constraints. Before testing commands export `ANDROID_SERIAL=abf51f11`; any device testing must select only `abf51f11`, and testing must stop with a reported blocker if that device is unavailable. Confirm the final diff implements only the startup-root change and its checks/documentation.
