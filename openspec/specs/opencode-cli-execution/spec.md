# opencode-cli-execution Specification

## Purpose

Defines the OpenCode server-operation contract for prompts and slash commands submitted to an existing selected session.

## Requirements

### Requirement: Execute an OpenCode prompt non-interactively
The system SHALL send ordinary prompt text to the exact selected session through V2 `POST /api/session/{id}/prompt`. It SHALL retain the session's server-owned location, model, and agent by not overriding them from a stale UI snapshot. The Android event SHALL complete after HTTP 200 admits the input, without waiting for generated text or streaming it to Android.

#### Scenario: OpenCode produces completed text
- **WHEN** OpenCode produces text after accepting the prompt
- **THEN** the event does not stream it and a later refresh obtains it from the transcript

#### Scenario: OpenCode emits no partial text events
- **WHEN** OpenCode produces only completed text at the end of a run
- **THEN** refresh after completion returns that text without requiring token-level updates

#### Scenario: Another client changes session configuration
- **WHEN** another OpenCode client changes the selected session's location, agent, or model before submission
- **THEN** the prompt uses the current server-owned configuration, not old values from Android's session snapshot

### Requirement: Preserve the OpenCode input boundary
The system MUST encode the session ID, directory, prompt, command name, and command arguments as HTTP path, query, or JSON values without shell interpretation.

#### Scenario: Prompt contains shell syntax
- **WHEN** an ordinary prompt contains whitespace, quotes, shell metacharacters, or starts with a hyphen
- **THEN** OpenCode receives the complete value as prompt text without executing any part through a shell

### Requirement: Execute OpenCode slash commands
After trimming, input starting with `/` and a non-whitespace name SHALL call V2 `POST /api/session/{id}/command` with that name and the remaining trimmed text. A lone `/` SHALL remain an ordinary prompt. HTTP 204 SHALL count as success without a response body. The Android event SHALL return without waiting for the command callback or agent work. A failed command SHALL NOT be retried as a prompt.

#### Scenario: Submit a slash command
- **WHEN** the user submits ` /review main `
- **THEN** the command operation receives `name=review` and `text=main` for the selected session

#### Scenario: Submit a lone slash
- **WHEN** the user submits `/`
- **THEN** it is submitted as an ordinary asynchronous prompt

#### Scenario: Submit an unknown command
- **WHEN** OpenCode reports `CommandNotFoundError`
- **THEN** the selected screen reports the command failure without a fallback prompt or treating the session as deleted

#### Scenario: Command callback has not returned
- **WHEN** OpenCode is still executing the command callback
- **THEN** Android can submit another UI event and command completion is handled asynchronously

### Requirement: Report OpenCode server operation failure
Connection, discovery, protocol, or operation failures SHALL produce ordinary UI errors without terminating the backend. The backend SHALL distinguish `SessionNotFoundError` from command and location errors even when they share HTTP 404. A session SHALL NOT be treated as deleted merely because an operation returns HTTP 404. Ambiguously failed writes SHALL NOT be automatically replayed.

#### Scenario: Prompt submission fails
- **WHEN** OpenCode rejects a prompt or command
- **THEN** the selected-session screen exposes the failure and the backend remains available

#### Scenario: Location is unavailable
- **WHEN** an operation returns `LocationNotFoundError`
- **THEN** the backend reports a location failure without treating the session as deleted

#### Scenario: Response does not match V2
- **WHEN** an operation returns malformed JSON or a missing required response field
- **THEN** the backend reports a protocol failure rather than silently accepting success

#### Scenario: Write outcome is unknown
- **WHEN** a connection fails after a prompt or command might have been accepted
- **THEN** the error is reported without automatically resubmitting the operation
