# opencode-session-attachment Specification

## Purpose

Lets the Android client inspect and continue existing OpenCode conversations while OpenCode keeps ownership of their directories, transcripts, and execution state.

## Requirements

### Requirement: Authenticate requests to the local OpenCode server
In OpenCode mode, the backend SHALL send HTTP Basic authentication on every request to `127.0.0.1:4096` when its own process environment contains a non-empty `OPENCODE_SERVER_PASSWORD`. The credentials SHALL use that password verbatim and the constant username `opencode`, regardless of any username environment variable. The backend SHALL omit the Authorization header when the password is unset or empty. The backend SHALL NOT expose credentials or the generated Authorization header in its UI documents or logs.

#### Scenario: Password with constant username
- **WHEN** the backend has a non-empty `OPENCODE_SERVER_PASSWORD`
- **THEN** every OpenCode request includes `Authorization: Basic <credentials>` using standard padded Base64 of `opencode:<password>` without line wrapping

#### Scenario: Username environment is ignored
- **WHEN** the backend has a non-empty password and a username environment variable is set
- **THEN** every OpenCode request still uses `opencode` as the username

#### Scenario: Coverage of reads and writes
- **WHEN** the backend lists sessions, loads session details or status, checks pending input, submits a prompt or command, or aborts a session with a configured password
- **THEN** each request includes the configured Basic authentication credentials

#### Scenario: Password is unavailable to the backend
- **WHEN** `OPENCODE_SERVER_PASSWORD` is unset or empty in the backend environment, regardless of the server environment
- **THEN** the backend sends no Authorization header

#### Scenario: Credentials are rejected
- **WHEN** the OpenCode server returns HTTP 401
- **THEN** the existing error-reporting path displays the failure and the backend remains available
- **AND** the backend does not include its credentials or generated Authorization header in UI documents or logs

### Requirement: Connect to the local OpenCode server
In OpenCode mode the backend SHALL obtain OpenCode session data from an independently started OpenCode server at `127.0.0.1:4096` when a session-list or selected-session screen loads it. The backend SHALL NOT start, stop, or expose that server on its LAN listener. Loading or refreshing the startup directory screen SHALL NOT contact the OpenCode server.

#### Scenario: Local server is available
- **WHEN** the backend loads OpenCode sessions while the local server is listening at `127.0.0.1:4096`
- **THEN** it obtains session data from that server

#### Scenario: Local server is unavailable
- **WHEN** a load or manual refresh of an OpenCode session-list or selected-session screen cannot reach the local OpenCode server
- **THEN** that UI document displays the failure and the remote_dev backend remains available

#### Scenario: Directory screen without OpenCode
- **WHEN** the directory screen is loaded or refreshed while the local OpenCode server is unavailable
- **THEN** directory loading proceeds independently without an OpenCode request

### Requirement: List existing OpenCode sessions
When active, the OpenCode session-list screen SHALL list at most the 20 most recently updated sessions across projects returned by the connected server, newest first. The backend SHALL request a single page with a limit of 20 and SHALL load statuses only for the returned sessions' contexts. Older sessions SHALL remain in OpenCode history. Each row SHALL display the session title, directory, and current status, and SHALL select that exact session when activated. The screen SHALL NOT list Git worktrees or provide a control for creating an OpenCode session. This screen SHALL NOT be the startup root screen; OpenCode startup SHALL show the empty tab UI instead. Tab controls and project-list clicks SHALL NOT navigate to this session-list screen.

#### Scenario: Server has sessions from multiple directories
- **WHEN** the active session-list screen loads sessions belonging to different directories from the connected server
- **THEN** it displays the returned page of up to 20 sessions with their own directories

#### Scenario: Server has more than 20 sessions
- **WHEN** the server returns a full page of 20 sessions ordered by most recent update for the active session-list screen
- **THEN** the screen displays those sessions in that order
- **AND** the backend does not request another page or statuses for contexts outside that page

#### Scenario: Server has no sessions
- **WHEN** the connected server returns an empty session list for the active session-list screen
- **THEN** the screen states that there are no OpenCode sessions and does not offer session creation

#### Scenario: Backend starts in OpenCode mode
- **WHEN** the backend initializes in OpenCode mode
- **THEN** it displays zero tabs and the tab creation control instead of loading the session-list screen

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
The backend SHALL process Back from a selected-session screen by returning the loaded session-list document. Back on the session-list screen SHALL leave that screen unchanged without reporting an error. Back on the common startup directory screen SHALL leave that directory screen unchanged without reporting an error.

#### Scenario: Return from a selected session
- **WHEN** an OpenCode session screen is active and the backend receives Back
- **THEN** it returns the loaded session-list document

#### Scenario: Back on the session list
- **WHEN** the OpenCode session-list screen is active and the backend receives Back
- **THEN** it returns the same session-list document without an error

#### Scenario: Back on the startup directory screen
- **WHEN** the startup directory screen is active in OpenCode mode and the backend receives Back
- **THEN** it returns the same directory-list document without an error

### Requirement: Submit an asynchronous follow-up
Submitting an ordinary prompt from the selected-session screen SHALL send the complete text to that exact session through the OpenCode asynchronous prompt operation, using the directory returned for the session. The Android event response SHALL complete after the server accepts the prompt and SHALL NOT wait for or stream the agent response.

#### Scenario: Submit a follow-up
- **WHEN** the user submits prompt text while an existing OpenCode session is selected
- **THEN** the prompt is addressed to that session and the Android client can send another UI event before the agent run completes

#### Scenario: Prompt contains shell syntax
- **WHEN** the submitted prompt contains whitespace, quotes, shell metacharacters, or starts with a hyphen
- **THEN** the complete value is encoded as prompt text without shell interpretation

### Requirement: Refresh OpenCode session state
Manual root refresh SHALL reload directories when the common startup directory screen is active, SHALL reload the session list when the OpenCode session-list screen is active, and SHALL reload transcript, status, and pending-input state when a session screen is active. The connected OpenCode server SHALL remain the source of truth for OpenCode session data; the backend SHALL NOT persist a session transcript or execution status. Directory-screen refresh SHALL NOT request OpenCode session data.

#### Scenario: Refresh a running session
- **WHEN** the user refreshes a selected session after OpenCode has produced more text
- **THEN** the returned document includes the latest transcript and status from the server

#### Scenario: Refresh the session list
- **WHEN** the user refreshes the active OpenCode session-list screen after another client created or updated a session
- **THEN** the returned list reflects the server's current sessions

#### Scenario: Refresh the directory screen
- **WHEN** the user refreshes the startup directory screen in OpenCode mode
- **THEN** the returned list reflects the startup root's current subdirectories without requesting OpenCode sessions

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
