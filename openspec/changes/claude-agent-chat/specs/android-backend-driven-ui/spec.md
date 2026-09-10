## ADDED Requirements

### Requirement: Observe Claude chat without holding a command open
While a Claude chat is visible, the Android client SHALL obtain updated backend-defined documents automatically, including before a long assistant response completes. Observation SHALL NOT hold the event-request lock for the lifetime of the agent turn. Observation results SHALL NOT replace a newer navigation result or discard unsent composer text. OpenCode manual-refresh behavior SHALL remain unchanged.

#### Scenario: Agent produces output while the user acts
- **WHEN** an enrolled Claude agent is responding and the user submits a message, answers a request, or invokes Back
- **THEN** the action can complete without waiting for the response to end

#### Scenario: Old observation arrives after navigation
- **WHEN** an observation for a previous chat completes after a successful navigation
- **THEN** it does not restore the previous chat or overwrite the current input

### Requirement: Use system Back for provider conversations
The Android client SHALL NOT render a separate Android `Back` button for returning from a selected provider conversation.

#### Scenario: Selected conversation is displayed
- **WHEN** the backend returns a conversation document without a `back` button
- **THEN** the client exposes system Back navigation without adding a visible return control

## REMOVED Requirements

### Requirement: Do not render a separate return control
**Reason**: The worktree-specific screen and scenario are retired.
**Migration**: Use the replacement requirement `Use system Back for provider conversations` for Claude and OpenCode conversation screens.
