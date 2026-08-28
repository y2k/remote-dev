## 1. Run Claude worktree creation

- [x] 1.1 Add a Runtime operation that starts a one-shot Claude CLI session from the repository root with the submitted worktree name passed through `Args`, and verify exact arguments plus successful and failed exit handling in `test/test_runtime.ml`.
- [x] 1.2 Make `New_worktree` reject an empty name and asynchronously report creation success or failure, and verify its UI document and error state in `test/test_remote_dev.ml`.

## 2. Refresh the worktree list

- [x] 2.1 Route a successful creation from the form to the preserved worktree list and invoke its existing reload command, while retaining the form on failure; verify the streamed documents show the refreshed list only on success in `test/test_remote_dev.ml`.
- [x] 2.2 Run `dune fmt` and `dune test` to verify formatting and the complete OCaml test suite.
