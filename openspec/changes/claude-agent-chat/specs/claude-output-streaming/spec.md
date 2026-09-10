## MODIFIED Requirements

### Requirement: Stream Claude UI documents
The system SHALL expose updated complete backend-defined UI documents as enrolled Claude agents produce observable assistant text, without tying observation to a newly launched prompt process or requiring the turn to complete. Finite JSON snapshots or finite NDJSON update responses SHALL preserve the conversation already displayed.

#### Scenario: Claude produces text in multiple deltas
- **WHEN** a selected enrolled agent produces observable assistant text during a long response
- **THEN** the client can display intermediate text before completion without clearing earlier conversation

#### Scenario: Claude completes without an error
- **WHEN** the observed response completes
- **THEN** the UI reconciles the completed text with history once and remains available for further input

### Requirement: Render streamed UI documents incrementally
When a response uses NDJSON, the Android client SHALL parse complete nonempty lines as UI documents and display valid updates before the response closes. A JSON snapshot SHALL be rendered as one complete document. Background observation SHALL preserve newer navigation and unsent input.

#### Scenario: Client receives a streamed document
- **WHEN** the client receives a complete nonempty NDJSON line for the current screen
- **THEN** it parses and renders the document without waiting for response closure

#### Scenario: Stream finishes
- **WHEN** a command response closes
- **THEN** the client releases the event request without waiting for the external agent turn

### Requirement: Preserve non-streaming UI events
The system SHALL return one complete `application/json` UI document for valid UI events that do not start an ordinary UI command. Channel submission SHALL NOT require a response that remains open for the lifetime of Claude's answer.

#### Scenario: Client loads or navigates
- **WHEN** a valid event updates UI state without starting an ordinary command
- **THEN** the server returns one complete JSON UI document

### Requirement: Surface streaming execution failure
When a finite UI update command fails after its NDJSON response starts, the system SHALL send a final complete document reporting the error and close the response. External agent or channel failure SHALL preserve displayed conversation and be exposed in subsequent UI updates rather than treated as a fatal child-process protocol violation.

#### Scenario: Claude exits unsuccessfully during a stream
- **WHEN** a selected agent exits unsuccessfully and its integration becomes unavailable during a UI update command
- **THEN** the resulting document preserves the chat, reports the connection state, disables sending, and the finite response ends
