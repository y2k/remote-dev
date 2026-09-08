## Purpose

Lets the Android client inspect and continue existing OpenCode conversations while OpenCode keeps ownership of their directories, transcripts, and execution state.

## ADDED Requirements

### Requirement: Connect to the local OpenCode server
In OpenCode mode the backend SHALL connect to an independently started OpenCode server at `127.0.0.1:4096`. The backend SHALL NOT start, stop, or expose that server on its LAN listener.

#### Scenario: Local server is available
- **WHEN** the backend loads OpenCode sessions while the local server is listening at `127.0.0.1:4096`
- **THEN** it obtains session data from that server

#### Scenario: Local server is unavailable
- **WHEN** an initial load or manual refresh cannot reach the local OpenCode server
- **THEN** the current UI document displays the failure and the remote_dev backend remains available

### Requirement: List existing OpenCode sessions
The OpenCode root screen SHALL list every existing session returned by the connected server. Each row SHALL display the session title, directory, and current status, and SHALL select that exact session when activated. The screen SHALL NOT list Git worktrees or provide a control for creating an OpenCode session.

#### Scenario: Server has sessions from multiple directories
- **WHEN** the connected server returns sessions belonging to different directories
- **THEN** the root screen displays every returned session with its own directory

#### Scenario: Server has no sessions
- **WHEN** the connected server returns an empty session list
- **THEN** the root screen states that there are no OpenCode sessions and does not offer session creation

### Requirement: Render the selected session transcript
Selecting an OpenCode session SHALL load its messages using the session ID and directory supplied by the server. The selected-session screen SHALL display the session title, directory, current status, and all user and assistant text parts in conversation order. Non-text parts SHALL NOT be rendered.

#### Scenario: Session has a conversation
- **WHEN** the selected session contains user and assistant messages with text parts
- **THEN** the screen displays each text part under its message role in conversation order

#### Scenario: Session contains tool parts
- **WHEN** the selected session transcript contains both text and non-text parts
- **THEN** the screen displays the text parts without exposing the non-text parts

#### Scenario: Selected session is no longer available
- **WHEN** the server reports that the selected session no longer exists during a refresh
- **THEN** the backend returns to the session list and displays an error without selecting a replacement

### Requirement: Navigate OpenCode session screens
The backend SHALL process Back from a selected-session screen by returning the loaded session-list document. Back on the OpenCode root screen SHALL leave that screen unchanged without reporting an error.

#### Scenario: Return from a selected session
- **WHEN** an OpenCode session screen is active and the backend receives Back
- **THEN** it returns the loaded session-list document

#### Scenario: Back on the session list
- **WHEN** the OpenCode root screen is active and the backend receives Back
- **THEN** it returns the same session-list document without an error

### Requirement: Submit an asynchronous follow-up
Submitting an ordinary prompt from the selected-session screen SHALL send the complete text to that exact session through the OpenCode asynchronous prompt operation, using the directory returned for the session. The Android event response SHALL complete after the server accepts the prompt and SHALL NOT wait for or stream the agent response.

#### Scenario: Submit a follow-up
- **WHEN** the user submits prompt text while an existing OpenCode session is selected
- **THEN** the prompt is addressed to that session and the Android client can send another UI event before the agent run completes

#### Scenario: Prompt contains shell syntax
- **WHEN** the submitted prompt contains whitespace, quotes, shell metacharacters, or starts with a hyphen
- **THEN** the complete value is encoded as prompt text without shell interpretation

### Requirement: Refresh OpenCode session state
Manual refresh SHALL reload the session list when the OpenCode root screen is active and SHALL reload transcript, status, and pending-input state when a session screen is active. The connected OpenCode server SHALL remain the source of truth; the backend SHALL NOT persist a session transcript or execution status.

#### Scenario: Refresh a running session
- **WHEN** the user refreshes a selected session after OpenCode has produced more text
- **THEN** the returned document includes the latest transcript and status from the server

#### Scenario: Refresh the session list
- **WHEN** the user refreshes the OpenCode root screen after another client created or updated a session
- **THEN** the returned list reflects the server's current sessions

### Requirement: Stop a busy OpenCode session
The selected-session screen SHALL provide a stop control only while the session is busy. Activating it SHALL request abortion of that exact session and then reload the selected session state.

#### Scenario: Stop active work
- **WHEN** the user activates Stop for a busy selected session
- **THEN** the backend requests abortion for that session and returns its refreshed transcript and status

#### Scenario: Session is not busy
- **WHEN** the selected session is idle or retrying
- **THEN** the screen does not display a Stop control

### Requirement: Report pending OpenCode input without answering it
If the connected server reports a pending permission or question for the selected session, the selected-session screen SHALL state that the session needs input in OpenCode. It SHALL NOT expose controls for answering that permission or question.

#### Scenario: Session waits for permission
- **WHEN** the selected session has a pending permission request
- **THEN** the screen displays that OpenCode needs input and provides no approval or rejection controls

#### Scenario: Session waits for an answer
- **WHEN** the selected session has a pending question
- **THEN** the screen displays that OpenCode needs input and provides no answer controls
