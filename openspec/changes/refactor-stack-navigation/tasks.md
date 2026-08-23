## 1. Stack Navigation

- [ ] 1.1 Replace `Home`'s single current screen with a non-empty stack and make rendering, decoding, and page-message dispatch operate on its top screen; verify with `dune build`.
- [ ] 1.2 Push a newly entered worktree screen when a worktree is selected, and pop it on `back` without entering or loading a new worktree-list screen; verify with `dune test`.
- [ ] 1.3 Preserve the existing no-op behavior for `back` at the root worktree list; verify with the affected navigation test.

## 2. Regression Coverage

- [ ] 2.1 Add a navigation test that selects a worktree from a populated list then returns, asserting that the original list model is restored and no reload command is scheduled; verify with `dune test`.
- [ ] 2.2 Run `dune fmt` and `dune test` to verify formatting and the complete test suite.
