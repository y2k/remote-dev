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
Selecting a session SHALL load its V2 messages by server-supplied session ID and display title, status, and all user and assistant text in conversation order across all pages, with the full directory available through session details. User `text` and assistant textual `content` SHALL be rendered; other message types and non-text content SHALL NOT be rendered. A missing title SHALL display as `Без названия` without renaming the OpenCode session.

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
The session-list screen SHALL show a button labelled «Создать новую сессию» above its rows, inside the same vertical scrolling area as the rows rather than pinned outside it. During creation, its replacement progress label SHALL occupy the same position in that scrolling area. Activating it SHALL create one OpenCode session in that folder and open its empty chat in the same tab, without an intermediate form or automatic prompt. Creation SHALL use discovered V2 service authentication and preserve the returned identity. Missing title SHALL display as «Без названия»; missing agent and model SHALL remain unset.

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

#### Scenario: Scroll past the creation button and return
- **WHEN** the session list overflows its viewport and the user scrolls down far enough to pass the creation button
- **THEN** the button moves with the session rows and leaves the viewport rather than remaining pinned
- **AND** scrolling back to the top reveals the button before the first session row

#### Scenario: Creation is in progress
- **WHEN** session creation is pending
- **THEN** the button is replaced by the progress label within the shared scrolling area above the rows

#### Scenario: Empty or failed session load
- **WHEN** the folder has no sessions or its initial session load fails
- **THEN** the creation button remains available at the start of the scrolling area above any empty-state content
- **AND** a failed load is still displayed as an error rather than a successful empty list

### Requirement: Preserve folder context on session load failure
A session-list load failure SHALL retain the selected folder and last successful rows and display an error. Initial failure SHALL NOT be presented as a successful empty list. Refresh SHALL retry that folder; success SHALL replace rows and clear the error. The creation control and Back navigation SHALL remain available.

#### Scenario: OpenCode is unavailable
- **WHEN** clicking a folder cannot load its sessions
- **THEN** that tab shows the folder and load error while other tabs and the emulator remain usable

#### Scenario: Failed refresh followed by recovery
- **WHEN** list refresh fails after a successful load and a later refresh succeeds
- **THEN** old rows remain visible during failure and are replaced on success with the error cleared

### Requirement: Session list cards
Each session row SHALL use the shared interactive card appearance, fill the list width, and have 8 dp separation from adjacent cards. It SHALL display the existing title as `sessionTitle`, and the directory and status as `cardMeta`, including complete retry details. It SHALL NOT add icons, badges, timestamps, a nested title button, or a separate Continue action.

#### Scenario: Display session states
- **WHEN** idle, busy, and retry sessions are listed
- **THEN** each card displays its title, directory, and existing status text, including the retry message
- **AND** status uses the same muted text treatment for all states

#### Scenario: Long session data
- **WHEN** a title, directory, or retry message exceeds the available width, including at 125% system font scale
- **THEN** every field wraps without truncation or horizontal scrolling and the card grows vertically

### Requirement: Preserve session selection and list controls with cards
Activating a session card SHALL select that exact session through its existing event. The list SHALL retain exact-folder filtering, newest-first ordering, the 20-session limit, Back and Refresh behavior, and failure retention. The creation control or its progress replacement SHALL remain before the cards in their shared vertical scrolling region.

#### Scenario: Tap secondary text or padding
- **WHEN** no event request is in progress and the user taps a session's directory, status, or card padding
- **THEN** the same session opens as when its title is activated, in the current tab

#### Scenario: Scroll the session list
- **WHEN** the user scrolls a list taller than its allocation
- **THEN** cards and the creation control or progress replacement scroll together
- **AND** the gesture does not select a session

#### Scenario: Refresh fails with loaded cards
- **WHEN** session refresh fails after a successful load
- **THEN** previous cards and folder context remain visible with the error and the existing retry and Back actions remain available

### Requirement: Selected session header presentation
The selected OpenCode chat SHALL show a compact horizontal header with its title, current status, and a session-details control outside transcript scrolling. It SHALL omit the `OpenCode session` caption and hide the directory by default. It SHALL use existing system-font typography, preserve full title and retry text by wrapping when necessary, and leave the existing tab strip unchanged.

#### Scenario: Display session context
- **WHEN** an OpenCode chat is displayed
- **THEN** its compact header shows the selected session's title, status, and details control in one horizontal row
- **AND** retry status retains its full existing detail and an untitled session retains `Без названия`
- **AND** no standalone `OpenCode session` caption or directory row occupies height by default
- **AND** the title, status, and details control are vertically centered within the row

#### Scenario: Long context at increased font scale
- **WHEN** the title or retry text exceeds the available width at 125% system font scale
- **THEN** the full value wraps within its allocated header region without horizontal scrolling or truncation
- **AND** the details control remains operable

#### Scenario: Existing tabs remain intact
- **WHEN** a selected session uses the compact header
- **THEN** tab labels, dimensions, spacing, placement, selection, close and add controls remain unchanged
- **AND** the session title stays below the tab strip rather than replacing a tab label

### Requirement: Role-separated chat messages
Each user and assistant text message SHALL appear in its own rounded, padded block with a separate role label, respectively `Вы` and `OpenCode`. User blocks SHALL be offset to the right with an accent background; assistant blocks SHALL be offset to the left with a neutral background. The complete original text and conversation order SHALL be preserved using the existing system font in both themes.

#### Scenario: Mixed conversation
- **WHEN** a conversation contains user and assistant messages, including consecutive messages of the same role
- **THEN** every message retains its own role label and block in the original order
- **AND** role names are not prepended to the message body

#### Scenario: Long and multiline messages
- **WHEN** a message contains Cyrillic, line breaks, or a path longer than the available width
- **THEN** the text wraps within its block, preserves its content and line breaks, and remains accessible through vertical scrolling

#### Scenario: Theme change
- **WHEN** the client renders the chat in light or dark mode
- **THEN** the blocks use themed accent and neutral backgrounds with readable text and distinguishable roles

### Requirement: Styled chat preserves controls and scrolling
The styled transcript SHALL occupy the remaining chat height and scroll independently of the header and existing prompt and voice-input controls. Styling SHALL preserve session action events, pending-input notices, errors, and busy-only Stop behavior. Message blocks SHALL NOT introduce actions or fabricated metadata; the header SHALL add only the session-details toggle.

#### Scenario: Overflowing conversation
- **WHEN** the transcript exceeds the available chat height
- **THEN** scrolling reveals its messages while the header and prompt controls remain stationary
- **AND** the prompt submission and voice-input actions retain their existing behavior

#### Scenario: Empty conversation
- **WHEN** the selected session has no messages
- **THEN** the header and prompt controls remain available without fabricated messages or timestamps

#### Scenario: Session needs attention
- **WHEN** the selected chat has an error, pending input, or busy status
- **THEN** existing errors and pending-input notices remain visible and Stop is offered only for busy status
- **AND** the styled message blocks do not expose permission or question-answer controls

### Requirement: Toggle selected session details
The chat SHALL provide a `Сведения` control that reveals the complete selected-session directory below the compact header and can hide it again. Details SHALL start collapsed when opening a session, survive refresh and tab switching for that open chat, and belong only to that chat. Toggling details SHALL preserve server-held prompt and transcript state without sending an OpenCode request.

#### Scenario: Reveal and hide directory
- **WHEN** the user activates `Сведения` in a newly opened chat
- **THEN** the full directory appears below the compact row, wrapping as needed
- **AND** activating the control again hides it and returns the height to the transcript

#### Scenario: Refresh or switch tabs
- **WHEN** the user refreshes a chat with details expanded or switches away and back
- **THEN** that chat retains its expanded state and reflects current session data
- **AND** other chats retain their own details state

#### Scenario: Toggle without reloading the session
- **WHEN** the user toggles session details
- **THEN** server-held prompt and transcript state remain intact and no OpenCode request is made
