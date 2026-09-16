## MODIFIED Requirements

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
When active, the OpenCode session-list screen SHALL list at most the 20 most recently updated sessions across projects returned by the connected server, newest first. The backend SHALL request a single page with a limit of 20 and SHALL load statuses only for the returned sessions' contexts. Older sessions SHALL remain in OpenCode history. Each row SHALL display the session title, directory, and current status, and SHALL select that exact session when activated. The screen SHALL NOT list Git worktrees or provide a control for creating an OpenCode session. This screen SHALL NOT be the startup root screen; startup SHALL show the common directory-list screen instead.

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
- **THEN** it displays the directory-list screen instead of loading the session-list screen

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
