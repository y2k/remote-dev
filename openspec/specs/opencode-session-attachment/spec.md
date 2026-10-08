# opencode-session-attachment Specification

## Purpose

Lets the Android client inspect and continue existing OpenCode conversations while OpenCode keeps ownership of their directories, transcripts, and execution state.

## Requirements

### Requirement: Authenticate requests to the local OpenCode server
In OpenCode mode, the backend SHALL use the discovered service registration's optional password for HTTP Basic authentication with username `opencode` on every OpenCode request, including health checks. It SHALL omit Authorization when the registration has no password. Backend password and username environment variables SHALL NOT override registration credentials. Credentials and Authorization headers SHALL NOT appear in UI documents or logs.

#### Scenario: Password with constant username
- **WHEN** registration contains a password
- **THEN** every request includes standard padded Base64 of `opencode:<password>` using the password verbatim, including an empty password

#### Scenario: Username environment is ignored
- **WHEN** backend username or password environment variables differ from registration credentials
- **THEN** authentication uses the registration password and constant username `opencode`

#### Scenario: Coverage of reads and writes
- **WHEN** the backend checks health, reads sessions or pending input, creates a session, submits input, or interrupts execution
- **THEN** each request uses the discovered authentication context

#### Scenario: Password is unavailable to the backend
- **WHEN** registration has no password field
- **THEN** the backend omits Authorization regardless of its password environment variable

#### Scenario: Credentials are rejected
- **WHEN** OpenCode returns HTTP 401
- **THEN** the UI reports an authentication failure while the backend remains available
- **AND** response text, credentials, and Authorization headers are not exposed as diagnostics

### Requirement: Connect to the local OpenCode server
The backend SHALL discover the already-running V2 service from `$XDG_STATE_HOME/opencode/service.json`, defaulting to `~/.local/state/opencode/service.json`. Before session operations it SHALL verify `/api/info`, matching the registered PID and version when present. It SHALL NOT start, stop, or expose OpenCode on its LAN listener. Startup and directory-only loading SHALL NOT contact OpenCode.

#### Scenario: Local server is available
- **WHEN** a valid registration identifies a healthy V2 service on a dynamic local port
- **THEN** session operations use that service rather than fixed port 4096

#### Scenario: Local server is unavailable
- **WHEN** registration is missing or invalid, the service cannot be reached, authentication fails, or health information does not match registration
- **THEN** the affected operation reports an error without starting a service or terminating the backend

#### Scenario: Directory screen without OpenCode
- **WHEN** startup or directory loading runs without an available OpenCode service
- **THEN** it proceeds without discovery or OpenCode HTTP requests

#### Scenario: Service registration changes
- **WHEN** OpenCode restarts with a new registration before a later user operation
- **THEN** that operation discovers the new connection without requiring a backend restart
- **AND** an ambiguously failed write is not automatically replayed

### Requirement: List existing OpenCode sessions
The OpenCode session-list screen SHALL list at most the 20 most recently updated sessions whose directory exactly matches the selected folder, newest first, using a single V2 page. Directory filtering SHALL precede the limit, excluding subdirectories and other worktrees. The backend SHALL use the global active execution map and read retry details only for displayed active sessions. Older sessions SHALL remain in OpenCode history. Each row SHALL display title, directory, and status and select that exact session. The screen SHALL show the selected folder and a creation control above the list, not Git worktrees. Startup SHALL remain the empty tab UI; selecting a folder SHALL open this list inside the current tab.

#### Scenario: Server has sessions from multiple directories
- **WHEN** the user opens `/projects/example` and the server has sessions in that folder, its subdirectories, and another worktree
- **THEN** only sessions whose directory equals `/projects/example` appear

#### Scenario: Server has more than 20 sessions
- **WHEN** the selected folder contains more than 20 sessions
- **THEN** its 20 most recently updated sessions appear in descending update order
- **AND** newer sessions elsewhere do not displace them and additional retry detail reads address only displayed active sessions

#### Scenario: Server has no sessions
- **WHEN** the selected folder has no sessions
- **THEN** the screen displays an explicit empty state, the folder path, and the creation control

#### Scenario: Backend starts in OpenCode mode
- **WHEN** the backend initializes in OpenCode mode
- **THEN** it displays zero tabs and the tab creation control instead of loading sessions

### Requirement: Render the selected session transcript
Selecting a session SHALL load its V2 messages by server-supplied session ID and display title, directory, status, and all user and assistant text in conversation order across all pages. User `text` and assistant textual `content` SHALL be rendered; other message types and non-text content SHALL NOT be rendered. A missing title SHALL display as `Без названия` without renaming the OpenCode session.

#### Scenario: Session has a conversation
- **WHEN** the selected session contains user and assistant text
- **THEN** the screen displays all such text under its role in conversation order

#### Scenario: Session contains tool parts
- **WHEN** the transcript also contains tools, reasoning, or system records
- **THEN** these records are not rendered as conversation text

#### Scenario: Selected session is no longer available
- **WHEN** refresh returns `SessionNotFoundError`
- **THEN** the backend returns to the session list with an error and does not select a replacement

#### Scenario: Transcript spans multiple pages
- **WHEN** more messages exist than fit in one response
- **THEN** refresh includes all pages in ascending conversation order without duplicated boundary messages
- **AND** an empty terminal page is accepted even if the preceding page supplied a next cursor

#### Scenario: Session has no title or defaults yet
- **WHEN** a session omits title, agent, and model
- **THEN** it remains selectable and readable with title `Без названия` and no fabricated agent or model

### Requirement: Navigate OpenCode session screens
Back from a selected-session screen SHALL return its folder's loaded session list within the same tab. Back on a session-list screen SHALL return that tab to the common directory list. Back on a directory screen or with zero tabs SHALL leave the UI unchanged without error. Navigation SHALL preserve tab identities, order, selection, other tabs' screens, and the common emulator panel.

#### Scenario: Return from a selected session
- **WHEN** a chat is active and the backend receives Back
- **THEN** that tab displays its loaded session list for the same folder

#### Scenario: Back on the session list
- **WHEN** a folder's session list is active and the backend receives Back
- **THEN** the same tab displays the common directory list without reloading it

#### Scenario: Back on the startup directory screen
- **WHEN** a directory screen is active in OpenCode mode and the backend receives Back
- **THEN** the screen remains unchanged without error

### Requirement: Submit an asynchronous follow-up
Submitting an ordinary prompt from the selected-session screen SHALL send the complete text to that exact session through the OpenCode asynchronous prompt operation, using the directory returned for the session. The Android event response SHALL complete after the server accepts the prompt and SHALL NOT wait for or stream the agent response.

#### Scenario: Submit a follow-up
- **WHEN** the user submits prompt text while an existing OpenCode session is selected
- **THEN** the prompt is addressed to that session and the Android client can send another UI event before the agent run completes

#### Scenario: Prompt contains shell syntax
- **WHEN** the submitted prompt contains whitespace, quotes, shell metacharacters, or starts with a hyphen
- **THEN** the complete value is encoded as prompt text without shell interpretation

### Requirement: Refresh OpenCode session state
Manual root Refresh SHALL reload directories on a directory screen, the selected folder's sessions on a session-list screen, and transcript, status, and pending-input state on a chat screen. It SHALL target the active tab without replacing other tabs' loaded state. OpenCode SHALL remain the source of truth; the backend SHALL NOT persist transcripts or execution status. Directory-screen refresh SHALL NOT request OpenCode session data.

#### Scenario: Refresh a running session
- **WHEN** the user refreshes a selected session after OpenCode has produced more text
- **THEN** the returned document includes its latest transcript and status

#### Scenario: Refresh the session list
- **WHEN** the user refreshes after another client created or updated a session
- **THEN** the active folder's list reflects current matching sessions in the specified order and limit

#### Scenario: Refresh the directory screen
- **WHEN** the user refreshes a directory screen in OpenCode mode
- **THEN** it reflects the startup root's current subdirectories without requesting sessions

### Requirement: Stop a busy OpenCode session
The selected-session screen SHALL provide Stop only while busy. Stop SHALL request interruption of that exact session through V2 and reload its state. A successful response acknowledges the interruption request rather than guaranteeing immediate idleness; `interrupted=false` SHALL be accepted as an idle no-op. The backend SHALL display refreshed server state rather than force an idle status.

#### Scenario: Stop active work
- **WHEN** the user activates Stop for a busy session
- **THEN** the backend requests interruption and returns refreshed transcript and status

#### Scenario: Session is not busy
- **WHEN** the session is idle or retrying
- **THEN** the screen does not display Stop

#### Scenario: Interruption cleanup is still running
- **WHEN** interruption is accepted but the refreshed session is still active
- **THEN** its status remains busy until a later refresh observes completion

#### Scenario: Session became idle before interruption
- **WHEN** the server returns `interrupted=false`
- **THEN** the backend refreshes normally without reporting a protocol error

### Requirement: Report pending OpenCode input without answering it
The backend SHALL determine pending input from the selected session's pending permissions and forms in V2. If either list is nonempty, the screen SHALL state that input is needed in OpenCode. Android SHALL NOT provide controls to answer, approve, reject, or cancel these requests.

#### Scenario: Session waits for permission
- **WHEN** a selected session has a pending permission request
- **THEN** the screen displays that OpenCode needs input without approval or rejection controls

#### Scenario: Session waits for an answer
- **WHEN** a selected session has a pending form
- **THEN** the screen displays that OpenCode needs input without answer controls

#### Scenario: Input belongs to another session
- **WHEN** another session has pending input but the selected session has none
- **THEN** the selected session is not marked as needing input

### Requirement: Normalize V2 execution status
The backend SHALL derive idle and busy state from V2 active execution and retry state from the latest assistant message of an active session. An active session with retry metadata SHALL be retrying; other active sessions SHALL be busy; inactive sessions SHALL be idle. Status detail reads for a list SHALL be restricted to displayed sessions.

#### Scenario: Active execution is retrying
- **WHEN** a displayed active session's latest assistant message contains retry metadata
- **THEN** its status is retry with the reported error message

#### Scenario: Retry has ended
- **WHEN** retry metadata is cleared or the session is no longer active
- **THEN** refresh displays busy or idle respectively instead of retaining an old retry status

### Requirement: Read sessions for an exact folder
The backend's OpenCode integration SHALL provide a folder-scoped list of at most 20 sessions, ordered by last update descending. Exact directory filtering SHALL precede the limit and exclude subdirectories and other worktrees. This operation SHALL be available to the dependent folder navigation change without changing current navigation or the existing global list operation.

#### Scenario: Newer sessions exist elsewhere
- **WHEN** other directories have more than 20 newer sessions
- **THEN** a folder-scoped read still returns the selected folder's newest matching sessions

#### Scenario: Folder has no sessions
- **WHEN** the folder query succeeds with no matches
- **THEN** the integration returns an empty list rather than an error or global sessions

### Requirement: Create an empty OpenCode session through the integration
The backend's OpenCode integration SHALL create one session at a supplied absolute folder path without submitting a prompt. It SHALL preserve the returned identity and location, accept absent title, agent, and model, and use discovered authentication. It SHALL NOT automatically retry creation after an ambiguous failure. Exposing a creation control belongs to the dependent UI change.

#### Scenario: Empty session creation succeeds
- **WHEN** OpenCode accepts creation with the selected location
- **THEN** the integration returns the server-created session without sending a prompt or selecting agent/model defaults itself

#### Scenario: Creation response is lost
- **WHEN** the creation request fails after it may have reached OpenCode
- **THEN** the caller receives an error and the integration does not issue another creation request automatically

### Requirement: Create a session in the selected folder
The session-list screen SHALL show a button labelled «Создать новую сессию» above its rows. Activating it SHALL create one OpenCode session in that folder and open its empty chat in the same tab, without an intermediate form or automatic prompt. Creation SHALL use discovered V2 service authentication and preserve the returned identity. Missing title SHALL display as «Без названия»; missing agent and model SHALL remain unset.

#### Scenario: Create from a populated or empty list
- **WHEN** the user activates the creation button and the server accepts creation
- **THEN** the tab opens the returned session's empty chat with a prompt input
- **AND** the server receives the selected folder as the creation context and no prompt is submitted

#### Scenario: Return after creation
- **WHEN** the user presses Back after successful creation
- **THEN** the new session is present in that folder's loaded list, retaining the 20-session limit

#### Scenario: Creation fails
- **WHEN** the server rejects creation or cannot be reached
- **THEN** the tab stays on the folder's session list with an error, retains loaded rows, and allows explicit retry
- **AND** no fabricated session or chat is opened and no automatic creation retry occurs

### Requirement: Preserve folder context on session load failure
A session-list load failure SHALL retain the selected folder and last successful rows and display an error. Initial failure SHALL NOT be presented as a successful empty list. Refresh SHALL retry that folder; success SHALL replace rows and clear the error. The creation control and Back navigation SHALL remain available.

#### Scenario: OpenCode is unavailable
- **WHEN** clicking a folder cannot load its sessions
- **THEN** that tab shows the folder and load error while other tabs and the emulator remain usable

#### Scenario: Failed refresh followed by recovery
- **WHEN** list refresh fails after a successful load and a later refresh succeeds
- **THEN** old rows remain visible during failure and are replaced on success with the error cleared
