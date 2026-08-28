## 1. Component input dispatch

- [ ] 1.1 Change `Components.Edit` and `edit` to store a string-to-message builder, compose it in `Components.map`, and verify nested mapped inputs produce the fully lifted message.
- [ ] 1.2 Serialize each input as a revision-bound structural selector and add a generic tree resolver; verify selectors round-trip through nested `column` and `row` nodes and reject non-input paths.

## 2. Server-side dispatch

- [ ] 2.1 Add document revisions to Home state and render input selectors with the current revision; verify every state transition produces selectors for its new revision.
- [ ] 2.2 Resolve input selectors against an atomic state snapshot before running `Home.update`; verify stale, malformed, non-input, and null-value requests return `Bad_request` without state changes or commands.
- [ ] 2.3 Remove `replace_value`, convert worktree creation and Claude command inputs to message builders, and verify submitted strings reach their existing page updates unchanged.

## 3. Contracts and verification

- [ ] 3.1 Update the README input-event protocol description and Android event-envelope test to use an opaque input selector; verify no Android production source change is needed.
- [ ] 3.2 Run `dune fmt` and `dune test`; verify branch creation, Claude streaming, nested selector dispatch, and invalid-selector rejection tests pass.
- [ ] 3.3 Run the Android unit test suite and verify parsing and forwarding of selector event arrays still pass.
