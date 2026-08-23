## 1. Message Routing

- [x] 1.1 Replace flat page-event variants in `Home.msg` with nested `Worktrees_msg` and `Worktree_msg` variants, update `decode` to construct them, and verify all advertised event types still decode successfully.
- [x] 1.2 Simplify `Home.update` to delegate nested page messages through the existing page adapters while preserving root `Load`, root `Error`, navigation actions, and inactive-page error handling; verify the existing `back`, worktree selection, and command paths return the same documents.

## 2. Verification

- [x] 2.1 Update direct `Home.msg` test construction for the nested variants and verify `dune fmt && dune test` passes.
