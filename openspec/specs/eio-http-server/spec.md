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
