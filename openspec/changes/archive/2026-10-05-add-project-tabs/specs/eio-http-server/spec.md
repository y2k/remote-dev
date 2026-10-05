## MODIFIED Requirements

### Requirement: In-memory UI state
The system SHALL maintain one confirmed UI state in server memory for its single local client and discard it when the server stops. Before accepting HTTP requests, it SHALL initialize Claude mode to the directory-list screen with loaded entries or a directory-load error, and OpenCode mode to an empty tab UI with zero tabs and no directory load. Initial screen loading SHALL NOT request Git worktrees or OpenCode sessions. A `Refresh` event SHALL reload the common directory list when the OpenCode tab UI has tabs, leave the empty tab UI intact when it has none, reload directories on the standalone directory screen, or reload the existing dynamic data for an active provider-specific list or detail screen. Every response SHALL remain a complete UI document or sequence of complete UI documents; Refresh and GET SHALL NOT reset tab state.

#### Scenario: Initial directory screen
- **WHEN** the backend starts in Claude mode
- **THEN** it loads the directory-list screen before accepting requests, without loading worktrees or OpenCode sessions

#### Scenario: Initial OpenCode tab UI
- **WHEN** the backend starts in OpenCode mode
- **THEN** it initializes zero tabs before accepting requests without loading directories, worktrees, or OpenCode sessions

#### Scenario: Select a worktree
- **WHEN** the backend runs in Claude mode, the current UI session displays the worktree list, and the client sends an advertised worktree-selection event
- **THEN** the system changes its current UI state to that worktree's UI and returns it

#### Scenario: Select an OpenCode session
- **WHEN** the backend runs in OpenCode mode, the current UI session displays the session list, and the client sends an advertised session-selection event
- **THEN** the system changes its current UI state to that session's UI and returns it

#### Scenario: Refresh the current screen
- **WHEN** the client sends `Refresh`
- **THEN** the system reloads the common directory list if tabs exist, no directories if the tab UI is empty, directories if the standalone directory screen is active, or the existing dynamic data for the active provider-specific list or detail screen
- **AND** it returns the resulting complete UI without resetting tabs or selection

#### Scenario: Server restarts
- **WHEN** the server starts after a previous process has stopped
- **THEN** OpenCode starts with zero tabs and Claude loads a fresh directory-list screen using its captured startup root, without retaining the previous UI state
