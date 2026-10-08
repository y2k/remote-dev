# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
