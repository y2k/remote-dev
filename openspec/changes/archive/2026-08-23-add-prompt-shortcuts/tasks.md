## 1. Worktree prompt state

- [x] 1.1 Add the selected-worktree prompt state, initialize it to an explicit empty string, and render it as the `Command2` input text; verify the worktree document includes `"text":""` after selection.
- [x] 1.2 Add typed shortcut button events and page-local handling that replaces the prompt state with `/igor-pending-reviews` or `/igor-restart-mr-tests` without invoking Claude; verify each event returns the matching `Command2` text and no output.

## 2. Verification

- [x] 2.1 Extend the OCaml assertions for shortcut event advertisement, default empty input text, and both shortcut transitions; run `dune fmt` and `dune test`.
