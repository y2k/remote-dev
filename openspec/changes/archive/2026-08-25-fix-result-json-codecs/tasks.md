## 1. Result JSON codecs

- [x] 1.1 Implement `result_to_yojson` and `result_of_yojson` with the canonical `ppx_deriving_yojson` two-element `Ok`/`Error` array format; return a decode error for malformed result JSON and verify the library builds with `dune build @all`.

## 2. Regression coverage

- [x] 2.1 Add assertions that result-bearing `Loaded` and `Finished` messages serialize and deserialize for both `Ok` and `Error`, and that malformed result JSON returns an error without raising; verify with `dune exec test/test_remote_dev.exe -- "$(pwd)"`.
- [x] 2.2 Format the OCaml sources with `dune fmt` and run `dune exec test/test_runtime.exe -- "$(pwd)"` to confirm the existing runtime behavior remains intact.
