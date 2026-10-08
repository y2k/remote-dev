# Spec Delta

## MODIFIED Requirements

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
When active, the existing global session-list screen SHALL list at most the 20 most recently updated sessions across projects, newest first, using a single V2 session page. It SHALL use the service's active execution map and request retry details only for displayed active sessions. Each row SHALL display title, directory, and status and select that exact session. Older sessions SHALL remain in OpenCode history. This screen SHALL NOT list Git worktrees or provide session creation. Startup SHALL remain the empty tab UI; tab controls and project-list clicks SHALL NOT navigate to this screen in this change.

#### Scenario: Server has sessions from multiple directories
- **WHEN** the global session-list screen loads sessions belonging to different directories
- **THEN** it displays up to 20 returned sessions with their own directories

#### Scenario: Server has more than 20 sessions
- **WHEN** OpenCode returns 20 sessions ordered by most recent update
- **THEN** the screen displays them in that order without requesting another session page
- **AND** additional retry detail reads address only displayed active sessions

#### Scenario: Server has no sessions
- **WHEN** the global session query succeeds with an empty list
- **THEN** the screen states that there are no sessions and offers no creation control

#### Scenario: Backend starts in OpenCode mode
- **WHEN** the backend initializes in OpenCode mode
- **THEN** it displays zero tabs and the tab creation control rather than loading sessions

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

## ADDED Requirements

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
