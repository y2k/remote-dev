## 1. Root emulator ownership

- [x] 1.1 Add the emulator model and messages to `Home`, render any current screen and the mapped emulator view in the existing fixed `[2, 1]` weighted row, and verify Worktrees, New worktree, and Worktree documents retain the right root child for selected, empty, and error states with direct root events.
- [x] 1.2 Initialize the emulator once at backend startup and chain the existing worktree load after either emulator success or failure; verify server initialization finishes both loads, a restart creates a fresh selection, and no `Cmd` or Android changes are required.

## 2. Page decoupling and navigation

- [x] 2.1 Remove emulator state, messages, view composition, and load routing from `Worktree`; verify its standalone model and view contain only worktree-specific content and entering it returns no emulator command.
- [x] 2.2 Preserve the root emulator model while selecting a worktree, opening or finishing worktree creation, navigating Back, processing page messages, and streaming Claude output; verify a selected or subsequently unavailable emulator and its image source survive each transition without another emulator load.

## 3. Documentation and verification

- [x] 3.1 Update `README.md` to describe one-time startup loading, in-memory global selection, stopped-device behavior, and the permanent fixed-ratio root panel on every screen; verify the documented event and weighted-row shape match the emitted UI document.
- [x] 3.2 Run `dune fmt` and `dune test`; verify root startup and restart, selected/empty/error layouts, navigation persistence without reload, unavailable-emulator behavior, and existing screenshot and Claude behavior pass.
