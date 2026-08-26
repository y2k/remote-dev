## MODIFIED Requirements

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
The system SHALL maintain one confirmed UI state in server memory for its single local client. It SHALL initialize that state to the loaded worktree list before accepting HTTP requests and SHALL discard it when the server stops. A `load` event SHALL return the current state, including refreshed dynamic worktree data when that state displays the worktree list.

#### Scenario: Select a worktree
- **WHEN** the current UI session displays the worktree list and the client sends an advertised worktree-selection event
- **THEN** the system changes its current UI state to that worktree's UI and returns it

#### Scenario: Server restarts
- **WHEN** the server starts after a previous process has stopped
- **THEN** it loads the worktree list before accepting requests and does not retain the previous UI state
