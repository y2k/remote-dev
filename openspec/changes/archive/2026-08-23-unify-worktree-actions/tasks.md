## 1. Worktree event flow

- [x] 1.1 Replace `Run` and `Prompt_selected` with one `Worktree.msg` variant carrying the decoded `action` and envelope value; preserve all existing event encodings, prompt updates, command execution, and error results, then verify `dune build` succeeds.

## 2. Verification

- [x] 2.1 Update direct `Worktree.update` assertions to use the unified message and retain coverage of prompt shortcuts, successful command completion, and missing command values; run `dune fmt` and `dune test`.
