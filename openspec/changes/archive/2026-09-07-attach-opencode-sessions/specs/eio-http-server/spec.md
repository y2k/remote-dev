## MODIFIED Requirements

### Requirement: In-memory UI state
The system SHALL maintain one confirmed UI state in server memory for its single local client. Before accepting HTTP requests, it SHALL initialize that state to the loaded worktree list in Claude mode or the loaded OpenCode session list in OpenCode mode, and it SHALL discard the state when the server stops. A `Refresh` event SHALL reload dynamic data for the current provider-specific root or detail screen.

#### Scenario: Select a worktree
- **WHEN** the backend runs in Claude mode, the current UI session displays the worktree list, and the client sends an advertised worktree-selection event
- **THEN** the system changes its current UI state to that worktree's UI and returns it

#### Scenario: Select an OpenCode session
- **WHEN** the backend runs in OpenCode mode, the current UI session displays the session list, and the client sends an advertised session-selection event
- **THEN** the system changes its current UI state to that session's UI and returns it

#### Scenario: Refresh the current screen
- **WHEN** the client sends `Refresh`
- **THEN** the system reloads dynamic data for the current provider-specific root or detail screen and returns the resulting UI document

#### Scenario: Server restarts
- **WHEN** the server starts after a previous process has stopped
- **THEN** it loads the selected provider's root screen before accepting requests and does not retain the previous UI state
