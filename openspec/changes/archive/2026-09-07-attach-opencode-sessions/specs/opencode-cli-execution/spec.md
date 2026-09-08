## MODIFIED Requirements

### Requirement: Execute an OpenCode prompt non-interactively
The system SHALL submit an ordinary OpenCode prompt to the exact existing session selected in the UI through the local server's asynchronous prompt operation. It SHALL use the selected session's server-supplied directory and the normal model and agent already associated with the session. The event response SHALL NOT wait for completed text or stream response text to Android.

#### Scenario: OpenCode produces completed text
- **WHEN** OpenCode produces completed text after the local server accepts a prompt for the selected session
- **THEN** the UI event does not stream that text and a later refresh obtains it from the transcript

#### Scenario: OpenCode emits no partial text events
- **WHEN** OpenCode produces only one completed textual part at the end of the background run
- **THEN** a refresh after completion returns that complete text without requiring token-level updates

### Requirement: Preserve the OpenCode input boundary
The system MUST encode the session ID, directory, prompt, command name, and command arguments as HTTP path, query, or JSON values without shell interpretation.

#### Scenario: Prompt contains shell syntax
- **WHEN** an ordinary prompt contains whitespace, quotes, shell metacharacters, or starts with a hyphen
- **THEN** OpenCode receives the complete value as prompt text without executing any part through a shell

### Requirement: Execute OpenCode slash commands
When the submitted value after trimming starts with `/` followed by a non-whitespace command name, the system SHALL invoke that name through the selected session's OpenCode command operation and SHALL pass the remaining trimmed text as command arguments. A lone `/` SHALL remain an ordinary asynchronous prompt. The system SHALL NOT retry a failed command as a prompt, and the Android event SHALL complete without waiting for the command's agent work to finish.

#### Scenario: Submit a slash command
- **WHEN** the user submits ` /review main ` in a selected OpenCode session
- **THEN** the system invokes the OpenCode command `review` with `main` as its arguments for that session

#### Scenario: Submit a lone slash
- **WHEN** the user submits `/`
- **THEN** the system sends `/` as an ordinary asynchronous prompt

#### Scenario: Submit an unknown command
- **WHEN** OpenCode reports that the submitted slash command is unknown
- **THEN** the system reports that failure without running a second prompt

## ADDED Requirements

### Requirement: Report OpenCode server operation failure
Failure to connect to the OpenCode server or an unsuccessful session operation SHALL produce an ordinary UI error without terminating the backend.

#### Scenario: Prompt submission fails
- **WHEN** the server rejects a prompt or command submitted for the selected session
- **THEN** the selected-session screen exposes the failure and the backend remains available

## REMOVED Requirements

### Requirement: Auto-approve OpenCode permission requests
**Reason**: The backend no longer starts `opencode run --auto`; existing server sessions retain their own configured permission behavior.

**Migration**: Configure permissions in OpenCode or answer pending requests from an attached OpenCode TUI.

### Requirement: Report OpenCode process failure
**Reason**: OpenCode work is no longer owned by a per-prompt child process.

**Migration**: Treat local server connection and session-operation failures according to `Report OpenCode server operation failure`.
