## ADDED Requirements

### Requirement: Place emulator beside worktree content
The selected worktree view SHALL display its non-emulator content in a left pane occupying two thirds of the available width and SHALL display the complete emulator block in a right pane occupying one third of the available width. The emulator block SHALL remain in the right pane while it shows a selected emulator, loading state, no-running-emulators state, or emulator-specific error.

#### Scenario: Selected emulator is available
- **WHEN** the selected worktree view displays a running emulator
- **THEN** the path, Claude output, prompt shortcuts, and command input occupy the left two thirds while the emulator selector and image occupy the right third

#### Scenario: No emulator is available
- **WHEN** the selected worktree view has no running emulator
- **THEN** the worktree content remains in the left two thirds and the no-running-emulators state remains in the right third

#### Scenario: Emulator loading fails
- **WHEN** loading the emulator list produces an error
- **THEN** the worktree content remains in the left two thirds and the emulator error remains in the right third
