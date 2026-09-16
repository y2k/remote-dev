## MODIFIED Requirements

### Requirement: In-memory UI state
The system SHALL maintain one confirmed UI state in server memory for its single local client. Before accepting HTTP requests, it SHALL initialize that state to the directory-list screen in both Claude and OpenCode modes, with either loaded entries or a directory-load error, and it SHALL discard the state when the server stops. Initial screen loading SHALL NOT request Git worktrees or OpenCode sessions. A `Refresh` event SHALL reload directories on the directory screen or the existing dynamic data for a provider-specific list or detail screen when that screen is active.

#### Scenario: Initial directory screen
- **WHEN** the backend starts in either supported agent mode
- **THEN** it loads the directory-list screen before accepting requests, without loading worktrees or OpenCode sessions

#### Scenario: Select a worktree
- **WHEN** the backend runs in Claude mode, the current UI session displays the worktree list, and the client sends an advertised worktree-selection event
- **THEN** the system changes its current UI state to that worktree's UI and returns it

#### Scenario: Select an OpenCode session
- **WHEN** the backend runs in OpenCode mode, the current UI session displays the session list, and the client sends an advertised session-selection event
- **THEN** the system changes its current UI state to that session's UI and returns it

#### Scenario: Refresh the current screen
- **WHEN** the client sends `Refresh`
- **THEN** the system reloads directories if the directory screen is active, or the existing dynamic data for the active provider-specific list or detail screen, and returns the resulting UI document

#### Scenario: Server restarts
- **WHEN** the server starts after a previous process has stopped
- **THEN** it loads a fresh directory-list screen from the new process's startup working directory before accepting requests and does not retain the previous UI state
