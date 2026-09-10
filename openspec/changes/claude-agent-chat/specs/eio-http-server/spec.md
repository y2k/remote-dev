## ADDED Requirements

### Requirement: Maintain provider conversation UI state
The system SHALL maintain one confirmed UI state in server memory for its single local client. Before accepting UI HTTP requests, it SHALL initialize that state to the loaded Claude agent list or the loaded OpenCode session list, including a recoverable load error when needed. It SHALL discard UI state when the server stops without deleting Claude-owned conversation history. A `Refresh` event SHALL reload dynamic data for the current provider-specific root or detail screen.

#### Scenario: Select a Claude agent
- **WHEN** Claude mode displays the agent list and receives an advertised enrolled-agent selection event
- **THEN** the system changes its UI state to that agent's chat and returns it

#### Scenario: Select an OpenCode session
- **WHEN** OpenCode mode displays the session list and receives an advertised session-selection event
- **THEN** the system changes its UI state to that session's UI and returns it

#### Scenario: Refresh the current screen
- **WHEN** the client sends `Refresh`
- **THEN** the system reloads dynamic data for the current provider-specific root or detail screen and returns the resulting document

#### Scenario: Server restarts
- **WHEN** the server starts after a previous process has stopped
- **THEN** it loads the selected provider's root screen and does not retain previous UI state or resume Claude processes

### Requirement: Advertise session-targeted UI events
The system SHALL advertise an event object on each interactive UI node that performs an action. A selectable agent or session event SHALL identify its exact target. An input node's event object SHALL identify the input submission action. The system SHALL interpret an input event's string `value` as submitted text. Unavailable agent chats SHALL NOT advertise selection or submission events.

#### Scenario: Advertise an enrolled agent event
- **WHEN** the UI displays an enrolled Claude agent available for chat
- **THEN** its button includes an event identifying selection of that agent

#### Scenario: Submit an input event
- **WHEN** the client sends an advertised input event with a string `value`
- **THEN** the system uses that value as the input submission

## REMOVED Requirements

### Requirement: In-memory UI state
**Reason**: The initialization and selection contract explicitly used worktrees; that screen is retired.
**Migration**: Use `Maintain provider conversation UI state`, preserving single-client in-memory state and OpenCode behavior while loading Claude agents.

### Requirement: Advertise backend-defined events
**Reason**: Worktree-path selection events are retired rather than reinterpreted as agent identifiers.
**Migration**: Use `Advertise session-targeted UI events` with exact session identity and the existing input envelope.
