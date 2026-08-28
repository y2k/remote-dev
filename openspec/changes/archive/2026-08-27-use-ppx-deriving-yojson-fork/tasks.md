## 1. Forked Dependency

- [x] 1.1 Fix the fork's generated result constructors for enclosing `Error` constructor collisions and add a regression test.
- [x] 1.2 Add a project-level Dune pin for `y2k/ppx_deriving_yojson`, regenerate `dune.lock`, and verify `ppx_deriving_yojson.dev.pkg` records Git commit `b10a96d` and `dune pkg validate-lockdir` succeeds.

## 2. Builtin Result Codecs

- [x] 2.1 Remove the application-local result codec helpers and their direct tests, add a `Home.decode` assertion for a malformed result event returning `Error _`, and verify no references to the removed helpers remain.
- [x] 2.2 Run `dune fmt`, `dune build @all`, and `dune test`; verify `Loaded` and `Finished` round trips retain the `Ok`/`Error` JSON arrays and malformed result input produces a decode error.

## 3. Documented Build

- [x] 3.1 Run `make build` and verify the documented Dune-managed build succeeds with the forked package lock.
