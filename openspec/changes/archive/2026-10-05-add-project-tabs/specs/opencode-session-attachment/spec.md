## MODIFIED Requirements

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
