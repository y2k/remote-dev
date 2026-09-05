## 1. Local Result Codecs

- [x] 1.1 Add `lib/result_yojson.ml` with polymorphic `result_to_yojson` and `result_of_yojson` functions that preserve the two-element `Ok`/`Error` arrays, reject malformed shapes, and mark the generic decode error limit with a `ponytail:` comment; verify `dune fmt` succeeds.
- [x] 1.2 Open `Result_yojson` in `lib/home_components.ml` so the official PPX can resolve the conventional codec names; verify all four result-bearing message types remain covered by the generated codecs with `dune build @all`.

## 2. Official PPX Dependency

- [x] 2.1 Remove the `ppx_deriving_yojson` Git pin from `dune-project`, run `dune pkg lock`, and verify the lock diff resolves official version `3.10.0` without a Git source while leaving unrelated packages unchanged.
- [x] 2.2 Run `dune pkg validate-lockdir` and `dune build @all` to verify the regenerated lock directory and the build against the official PPX.

## 3. Regression Coverage

- [x] 3.1 Add direct assertions in `test/test_remote_dev.ml` for encoding and decoding both result constructors and rejecting malformed result JSON; verify them with `dune exec test/test_remote_dev.exe -- "$(pwd)"`.
- [x] 3.2 Run `dune fmt` and `dune test` to verify formatting, message round trips, malformed event handling, and the full existing test suite.
