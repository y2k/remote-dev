# eio-http-server Specification

## Purpose

Provide a runnable local HTTP endpoint that demonstrates the project's Eio server integration.

## Requirements

### Requirement: Single UI event endpoint
The system SHALL accept UI events only through `POST /` on port `8080`. Each request SHALL contain a JSON object with an `event` object and a `value` that is either a string or `null`. For a valid event, the system SHALL return a complete supported UI document with `200 OK` and the `application/json` media type.

#### Scenario: Initial load
- **WHEN** the client sends `{"event":{"type":"load"},"value":null}` to `POST /`
- **THEN** the system returns the current complete UI document

#### Scenario: Backend-defined event
- **WHEN** the client sends an event advertised by the current UI document to `POST /`
- **THEN** the system processes the event and returns the resulting complete UI document

#### Scenario: Unsupported route or method
- **WHEN** a client requests any path other than `/` or uses a method other than `POST`
- **THEN** the system returns `404 Not Found`

### Requirement: In-memory UI state
The system SHALL maintain one confirmed UI state in server memory for its single local client. It SHALL initialize that state to the worktree list when the server starts and SHALL discard it when the server stops. A `load` event SHALL return the current state, including refreshed dynamic worktree data when that state displays the worktree list.

#### Scenario: Select a worktree
- **WHEN** the client sends an advertised worktree-selection event
- **THEN** the system changes its current UI state to that worktree's UI and returns it

#### Scenario: Server restarts
- **WHEN** the server starts after a previous process has stopped
- **THEN** its initial UI state is the worktree list and does not retain the previous UI state

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
