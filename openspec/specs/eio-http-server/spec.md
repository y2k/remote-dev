# eio-http-server Specification

## Purpose

Provide a runnable local HTTP endpoint that demonstrates the project's Eio server integration.

## Requirements

### Requirement: Single UI event endpoint
The system SHALL serve the current initial UI through `GET /` on port `8080` without an event envelope as one complete supported UI document with `200 OK` and the `application/json` media type. The system SHALL accept UI events through `POST /`; each POST request SHALL contain a JSON object with an `event` object and a `value` that is either a string or `null`. For a valid POST request, the system SHALL return either one complete supported UI document with `200 OK` and the `application/json` media type, or a sequence of complete supported UI documents with `200 OK` and the `application/x-ndjson` media type when processing starts an ordinary UI command.

#### Scenario: Initial load
- **WHEN** the client sends `GET /`
- **THEN** the system returns the current initial UI document with `application/json`

#### Scenario: Backend-defined event
- **WHEN** the client sends an event advertised by the current UI document to `POST /`
- **THEN** the system processes the event and returns the resulting complete UI document or UI-document stream

#### Scenario: Unsupported route or method
- **WHEN** a client requests any path other than `/` or uses a method other than `GET` or `POST`
- **THEN** the system returns `404 Not Found`

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

### Requirement: Advertise backend-defined events
The system SHALL advertise an event object on each interactive UI node that performs an action. A worktree button's event object SHALL identify the worktree path to select. An input node's event object SHALL identify the command submission action. The system SHALL interpret an input event's string `value` as the submitted text.

#### Scenario: Advertise a worktree event
- **WHEN** the current UI displays an available worktree
- **THEN** its button includes an event object that identifies selection of that worktree path

#### Scenario: Submit an input event
- **WHEN** the client sends an advertised input event with a string `value`
- **THEN** the system uses that value as the input submission

### Requirement: Return processing failures as UI state
When processing a syntactically valid advertised event fails, the system SHALL return `200 OK` with a complete supported UI document that exposes the failure while preserving the confirmed UI state.

#### Scenario: Command processing fails
- **WHEN** a command input event cannot be completed
- **THEN** the system returns the current UI document with an error message
