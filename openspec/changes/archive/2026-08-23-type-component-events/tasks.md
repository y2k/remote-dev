## 1. Typed Component Tree

- [x] 1.1 Replace immediate JSON construction in `Components` with a generic event-parameterized UI tree and verify `button` and `edit` accept a concrete OCaml event type.
- [x] 1.2 Add recursive event mapping and JSON serialization through a supplied event encoder, and verify the current button, input, layout, and text JSON shapes with assertions.

## 2. Page Actions and Transport Boundary

- [x] 2.1 Define page-local action types and update `Worktrees.view` and `Worktree.view` to pass typed actions directly to `Components`, verifying no view constructs a JSON event object.
- [x] 2.2 Lift active-page actions into `Home`, serialize them only while producing the HTTP response, and verify `select_worktree` and `run_claude` retain their current JSON event objects.
- [x] 2.3 Preserve page-local HTTP decoding and existing `load`, `back`, input-value, invalid-event, command, and routing behavior; verify it with the existing regression assertions.

## 3. Verification

- [x] 3.1 Run `dune fmt` and `dune test` successfully.
