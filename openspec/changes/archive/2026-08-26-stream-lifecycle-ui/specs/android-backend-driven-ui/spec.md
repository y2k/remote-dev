## MODIFIED Requirements

### Requirement: Load backend-driven UI
The Android client SHALL request the initial UI document with `GET /` to the configured backend origin when the screen first appears. The client SHALL render the valid supported UI document from the `application/json` response and SHALL expose loading and transport or parse failure states.

#### Scenario: Initial load succeeds
- **WHEN** the screen first appears and the endpoint returns a valid supported UI document
- **THEN** the client renders that document

#### Scenario: Load fails
- **WHEN** the endpoint cannot be reached or its response cannot be parsed as supported UI documents
- **THEN** the client displays an error while keeping pull-to-refresh and the `Refresh` menu item available

## ADDED Requirements

### Requirement: Render streamed UI documents for commands
The Android client SHALL read an `application/x-ndjson` UI-event response line by line and replace the displayed UI document for every valid complete document until the response closes.

#### Scenario: Navigation command streams UI documents
- **WHEN** a UI-event request returns `application/x-ndjson` with more than one complete document
- **THEN** the client renders each document in response order and permits the next UI event after the response closes
